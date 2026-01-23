import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/diary_provider.dart';
import 'services/diary_service.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'pages/diary_list_page.dart';
import 'config/app_theme.dart';
import 'pages/intro_page.dart';
import 'pages/splash_page.dart';
import 'services/storage_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'widgets/lock_screen.dart';
import 'models/diary_entry.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool showIntro = !(prefs.getBool('intro_shown') ?? false);
  AuthService().init(prefs);
  
  final diaryService = DiaryService();
  
  // 预加载：尝试快速读取缓存，实现“秒开”体验
  // 设置 500ms 超时，避免特殊情况下阻塞启动过久
  List<DiaryEntry>? initialEntries;
  try {
     // 必须先 init 才能读取缓存
     await diaryService.init();
     initialEntries = await diaryService.loadCache().timeout(
       const Duration(milliseconds: 500), 
       onTimeout: () => null
     );
  } catch (e) {
    debugPrint("Pre-loading failed or timed out: $e");
    // Fallback: initialEntries remains null, Provider will load normally
  }

  // 冷启动检查锁状态
  AuthService().lockApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        // 注入预加载的数据，实现所见即所得
        ChangeNotifierProvider(create: (_) => DiaryProvider(diaryService, initialEntries)),
        ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
        ),
      ],
      child: MyApp(showIntro: showIntro),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool showIntro;
  const MyApp({super.key, required this.showIntro});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 冷启动自动同步 & 锁屏检查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 启动时清理临时缓存
      StorageService().cleanTemporaryCache();
      
      // 检查是否需要锁屏
      // if (AuthService().isLocked) {
      //   _checkLock();
      // }
      
      if (mounted) {
         context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      //切后台，若开启了锁则标记为锁定
      AuthService().lockApp();
    }
    
    if (state == AppLifecycleState.resumed) {
       // 切回前台自动同步
       if (mounted) {
         context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
       }
       _checkLock();
    }
  }

  void _checkLock() {
    if (AuthService().isLocked) {
      // Prevent multiple lock screens
      if (AuthService().isLockScreenVisible) {
        return;
      }
      
      navigatorKey.currentState?.push(
        PageRouteBuilder(
          opaque: false, // Transparent enabling blur effect (or not, since we use opaque now)
          pageBuilder: (_, __, ___) => LockScreen(
            enableBack: false,
            onUnlocked: () {
               navigatorKey.currentState?.pop();
            },
          ),
        ),
      );
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
          // 使用 AppTheme 生成的动态 Theme，包含背景色修复和自定义转场
          theme: AppTheme.getThemeData(settings.currentTheme),
          builder: (context, child) {
            // 注意：全局效果会导致页面切换时叠加问题
            // 所以改为让各页面自己负责渲染背景和特效
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
          supportedLocales: const [
             Locale('zh', 'CN'),
             Locale('en', 'US'),
          ],
            home: SplashPage(showIntro: widget.showIntro),
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
