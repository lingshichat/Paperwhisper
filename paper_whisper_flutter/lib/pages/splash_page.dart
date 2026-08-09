import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'diary_list_page.dart';
import 'intro_page.dart';
import 'moments_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../widgets/privacy_agreement_dialog.dart';
import '../services/auth_service.dart';
import '../widgets/lock_screen.dart';

/// 启动屏：等待必要检查后再导航到目标页
/// 尽量保持首屏轻量，减少冷启动额外抖动
class SplashPage extends StatefulWidget {
  final bool showIntro;
  final String startupPage;

  const SplashPage({
    super.key,
    required this.showIntro,
    required this.startupPage,
  });

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

    // 1. 导航到目标页面
    Widget targetPage;

    if (widget.showIntro) {
      targetPage = const IntroPage();
    } else {
      switch (widget.startupPage) {
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
          pageBuilder: (ctx, _, _) => _buildLockScreenWrapper(ctx, targetPage),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300), // 加快转场
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => targetPage,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
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
            pageBuilder: (_, _, _) => targetPage,
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
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
    final theme = context.select<SettingsProvider, String>(
      (provider) => provider.currentTheme,
    );

    // 仅显示背景色，根据主题适配，避免颜色跳变
    return Scaffold(
      backgroundColor: AppTheme.getThemeData(theme).scaffoldBackgroundColor,
      body: const SizedBox.shrink(), // 不显示任何 Logo 或加载圈
    );
  }
}
