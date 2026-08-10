import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/features/update/application/update_check_coordinator.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/services/auth_service.dart';
import 'package:paper_whisper_flutter/features/update/presentation/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/lock_screen.dart';
import 'widgets/privacy_agreement_dialog.dart';

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

    final bool isLocked = AuthService().isLocked;

    // 如果锁定，导航到锁屏页面 (替换 Splash)；解锁后的回调导航到同一
    // startup route（_startupRoute 工厂按 showIntro / startup_page 字符串
    // 分发，持久化字符串 'moments'/'writer'/'last' 逐字保留）。
    if (isLocked) {
      // 使用惰性 builder：LockScreen 在 route 的 pageBuilder 阶段构造，
      // 拿到的是该 route 自身的有效 context（而非即将被替换销毁的
      // Splash context），解锁回调经 route context 导航到 startup route。
      Navigator.of(context).pushReplacement(
        AppRoutes.pageFadeBuilder(
          (routeContext) =>
              _buildLockScreenWrapper(routeContext, _startupRoute),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(_startupRoute());

      // 3. 启动时自动检测更新（仅非引导页时检查）
      if (!widget.showIntro) {
        _checkForUpdateAfterNavigation();
      }
    }
  }

  /// 启动目标路由工厂：showIntro 优先返回 IntroPage，否则按
  /// startup_page 持久化字符串（'moments'/'writer'/'last'）逐字分发。
  Route<void> _startupRoute() => AppRoutes.startup(
    showIntro: widget.showIntro,
    startupPage: widget.startupPage,
  );

  Widget _buildLockScreenWrapper(
    BuildContext context,
    Route<void> Function() startupRoute,
  ) {
    // 引入锁屏组件
    return LockScreen(
      enableBack: false,
      onUnlocked: () {
        // 解锁成功，替换为同一 startup route
        Navigator.of(context).pushReplacement(startupRoute());

        // 检测更新
        if (!widget.showIntro) {
          _checkForUpdateAfterNavigation();
        }
      },
    );
  }

  /// 导航完成后延迟检测更新。
  ///
  /// 自动检查委托 context-free 的 UpdateCheckCoordinator：保留原 1s
  /// 延迟与静默失败语义，available 才经 Navigator context 弹
  /// UpdateDialog；purpose 级会话去重使同进程内多次导航不再重复检查。
  /// 延迟留在页面，延迟后先检查 mounted 再发起网络请求。
  final UpdateCheckCoordinator _updateCheckCoordinator =
      UpdateCheckCoordinator();

  Future<void> _checkForUpdateAfterNavigation() async {
    // 保留原时序：先延迟 1s 等待页面动画完成，延迟后先检查 mounted
    // 再发起网络请求。
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final outcome = await _updateCheckCoordinator.checkAuto(purpose: 'splash');
    if (!mounted) return;
    if (outcome is UpdateCheckAvailable) {
      // 获取当前 Navigator 的 context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigatorContext = Navigator.of(context).context;
          UpdateDialog.show(
            navigatorContext,
            updateInfo: outcome.info,
            currentVersion: outcome.currentVersion,
          );
        }
      });
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
