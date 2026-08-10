import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/diary_provider.dart';
import 'services/diary_service.dart';
import 'services/moment_service.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'services/storage_service.dart';
import 'services/hitokoto_service.dart';
import 'features/auth/presentation/splash_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/trial_service.dart';
import 'services/payment_service.dart';
import 'features/auth/presentation/widgets/lock_screen.dart';
import 'models/diary_entry.dart';
import 'services/analytics_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. 初始化主题注册中心
  ThemeRegistry.init();

  // 1. 初始化统计服务 (最优先)
  final analytics = AnalyticsService();
  // 不 await，让它后台初始化，反正 trackEvent 会自己处理未初始化的情况
  analytics.init().then((_) {
    analytics.trackEvent('app_launch');
  });

  // 2. 配置全局错误捕获 (Crash Reporting)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // 依旧打印到控制台
    AnalyticsService().trackEvent(
      'app_crash',
      metadata: {
        'error': details.exceptionAsString(),
        'stack': details.stack.toString(),
        'fatal': true,
      },
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AnalyticsService().trackEvent(
      'app_crash',
      metadata: {
        'error': error.toString(),
        'stack': stack.toString(),
        'fatal': false,
      },
    );
    return true; // 标记为已处理，防止 App 崩溃退出 (视情况而定)
  };

  // 并行初始化：极限压缩启动时间
  // composition root 只创建一份写 Diary manifest 的 DiaryService 与
  // 一份写 Moment manifest 的 MomentService；MomentService 注入共享
  // DiaryService 供聚合导出使用（不再局部 new）。
  final diaryService = DiaryService();
  final momentService = MomentService(diaryService: diaryService);
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    diaryService.init().then(
      (_) => diaryService.loadCache().timeout(
        const Duration(milliseconds: 150),
        onTimeout: () => null,
      ),
    ),
  ]);

  final prefs = results[0] as SharedPreferences;
  final List<DiaryEntry>? initialEntries = results[1] as List<DiaryEntry>?;

  final bool showIntro = !(prefs.getBool('intro_shown') ?? false);
  AuthService().init(prefs);
  await TrialService().init(prefs);
  await PaymentService().init(prefs); // Init Payment Service

  // 启动前同步读取设置，避免首帧先按默认配置构建再整树重建
  final settingsBootstrapData = SettingsBootstrapData.fromPreferences(prefs);

  // 检查锁状态
  AuthService().lockApp();
  final bool isLocked = AuthService().isLocked;

  // 预热一言 (Fire and forget, 不阻塞)
  HitokotoService().fetchHitokoto();

  runApp(
    MultiProvider(
      providers: [
        // 共享服务实例：DiaryProvider/SyncProvider/Statistics/Storage/
        // 页面均通过 Provider 或构造获取同一实例，避免各自维护会写
        // Manifest 的独立缓存实例造成状态分歧。
        Provider<DiaryService>.value(value: diaryService),
        Provider<MomentService>.value(value: momentService),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(bootstrapData: settingsBootstrapData),
        ),
        ChangeNotifierProvider(
          create: (_) => DiaryProvider(
            service: diaryService,
            initialEntries: initialEntries,
          ),
        ),
        ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
          create: (_) => SyncProvider(momentService: momentService),
          update: (_, diary, syncProvider) =>
              syncProvider!..updateDiaryProvider(diary),
        ),
        ChangeNotifierProvider.value(
          value: PaymentService(),
        ), // Validate Payment Provider
      ],
      child: MyApp(
        showIntro: showIntro,
        startupPage: settingsBootstrapData.startupPage,
        isLocked: isLocked,
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool showIntro;
  final String startupPage;
  final bool isLocked;

  const MyApp({
    super.key,
    required this.showIntro,
    required this.startupPage,
    required this.isLocked,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageService(
        momentService: context.read<MomentService>(),
      ).cleanTemporaryCache();

      // 冷启动锁屏由 SplashPage 处理，此处不再重复触发
      // 仅由 didChangeAppLifecycleState 中的 _checkLock() 处理 resume 时的锁屏

      if (mounted) {
        context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
      }
    });
  }

  void _showLockScreen() {
    if (AuthService().isLockScreenVisible) return;
    navigatorKey.currentState?.push(
      AppRoutes.transparent(
        LockScreen(
          enableBack: false,
          onUnlocked: () => navigatorKey.currentState?.pop(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AuthService().lockApp();
    }

    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
      }
      _checkLock();
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      final brightness = View.of(context).platformDispatcher.platformBrightness;
      context.read<SettingsProvider>().updateThemeFromSystem(brightness);
    }
  }

  void _checkLock() {
    if (AuthService().isLocked) {
      _showLockScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: '纸语 PaperWhisper',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getThemeData(settings.currentTheme),
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.getSystemUiOverlayStyle(settings.currentTheme),
              child: child!,
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          home: SplashPage(
            showIntro: widget.showIntro,
            startupPage: widget.startupPage,
          ),
          scrollBehavior: AppScrollBehavior(),
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
