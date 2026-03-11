import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'diary_list_page.dart';
import 'intro_page.dart';
import 'moments_page.dart';
import '../providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/privacy_agreement_dialog.dart';
import '../services/auth_service.dart';
import '../widgets/lock_screen.dart';

/// 启动屏：等待数据预加载完成后再导航到主页/引导页
/// 同时预热字体、shader 和网络请求，避免首次交互卡顿
class SplashPage extends StatefulWidget {
  final bool showIntro;
  const SplashPage({super.key, required this.showIntro});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保在首帧渲染后立即执行跳转逻辑
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndNavigate();
    });
  }

  Future<void> _initAndNavigate() async {
    // 0. 检查是否同意过用户协议
    final prefs = await SharedPreferences.getInstance();
    final bool agreed = prefs.getBool('privacy_agreed') ?? false;

    if (!agreed && mounted) {
      // 显示协议弹窗
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PrivacyAgreementDialog(
          onAgree: () {
            Navigator.of(context).pop(true);
          },
          onDisagree: () {
            Navigator.of(context).pop(false);
          },
        ),
      );

      if (result == true) {
        await prefs.setBool('privacy_agreed', true);
      } else {
        // 退出应用
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        return;
      }
    }

    if (!mounted) return;

    // 1. 触发预热 (不等待)
    _preloadHitokoto();
    
    // 2. 导航到目标页面
    
    // Determine target page based on settings
    final settings = context.read<SettingsProvider>();
    Widget targetPage;
    
    if (widget.showIntro) {
      targetPage = const IntroPage();
    } else {
      switch (settings.startupPage) {
        case 'moments':
          targetPage = const MomentsPage();
          break;
        case 'writer':
          targetPage = const DiaryListPage();
          break;
        case 'last':
        default:
          targetPage = const DiaryListPage();
          break;
      }
    }
    
    final bool isLocked = AuthService().isLocked; 

    // 如果锁定，导航到锁屏页面 (替换 Splash)
    // 解锁后的回调导航到 targetPage
    if (isLocked) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (ctx, _, __) => _buildLockScreenWrapper(ctx, targetPage),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300), // 加快转场
        ),
      );
    } else {
       Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => targetPage,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300), // 加快转场
        ),
      );
      
      // 3. 启动时自动检测更新（仅非引导页时检查）
      if (!widget.showIntro) {
        _checkForUpdateAfterNavigation();
      }
    }
  }

  Widget _buildLockScreenWrapper(BuildContext context, Widget targetPage) {
    // 引入锁屏组件
    return LockScreen(
      enableBack: false,
      onUnlocked: () {
        // 解锁成功，替换为目标页面
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => targetPage,
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        
        // 检测更新
        if (!widget.showIntro) {
          _checkForUpdateAfterNavigation();
        }
      },
    );
  }

  Future<void> _preloadHitokoto() async {
    try {
      // 预热一言请求 (Fire and forget)
      HitokotoService().fetchHitokoto();
    } catch (_) {}
  }

  /// 导航完成后延迟检测更新
  Future<void> _checkForUpdateAfterNavigation() async {
    // 等待页面动画完成
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;

    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate();
      
      if (updateInfo != null && mounted) {
        final currentVersion = await updateService.getCurrentVersion();
        
        // 获取当前 Navigator 的 context
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final navigatorContext = Navigator.of(context).context;
            UpdateDialog.show(
              navigatorContext,
              updateInfo: updateInfo,
              currentVersion: currentVersion,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('启动时检测更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 仅显示背景色，根据主题适配，避免颜色跳变
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SizedBox.shrink(), // 不显示任何 Logo 或加载圈
    );
  }
}
