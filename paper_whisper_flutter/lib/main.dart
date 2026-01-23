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
import 'pages/moments_page.dart';
import 'services/storage_service.dart';
import 'services/hitokoto_service.dart';
import 'widgets/privacy_agreement_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'widgets/lock_screen.dart';
import 'models/diary_entry.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 并行初始化：极限压缩启动时间
  final diaryService = DiaryService();
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    diaryService.init().then((_) => diaryService.loadCache().timeout(
      const Duration(milliseconds: 150), 
      onTimeout: () => null
    )),
  ]);
  
  final prefs = results[0] as SharedPreferences;
  final List<DiaryEntry>? initialEntries = results[1] as List<DiaryEntry>?;
  
  final bool showIntro = !(prefs.getBool('intro_shown') ?? false);
  AuthService().init(prefs);
  
  // 确定启动页
  final String startupPage = prefs.getString('startup_page') ?? 'writer';
  
  // 检查锁状态
  AuthService().lockApp();
  final bool isLocked = AuthService().isLocked;
  
  // 预热一言 (Fire and forget, 不阻塞)
  HitokotoService().fetchHitokoto();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DiaryProvider(diaryService, initialEntries)),
        ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
        ),
      ],
      child: MyApp(
        showIntro: showIntro, 
        startupPage: startupPage,
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
  bool _privacyChecked = false;
  bool _privacyAgreed = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageService().cleanTemporaryCache();
      _checkPrivacy();
      
      // 冷启动时如果锁定，显示锁屏
      if (widget.isLocked) {
        _showLockScreen();
      }
      
      if (mounted) {
         context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
      }
    });
  }
  
  Future<void> _checkPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('privacy_agreed') ?? false;
    if (!agreed && mounted) {
      final result = await showDialog<bool>(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        builder: (ctx) => PrivacyAgreementDialog(
          onAgree: () => Navigator.of(ctx).pop(true),
          onDisagree: () => Navigator.of(ctx).pop(false),
        ),
      );
      if (result == true) {
        await prefs.setBool('privacy_agreed', true);
      } else {
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      }
    }
    if (mounted) setState(() { _privacyChecked = true; });
  }
  
  void _showLockScreen() {
    if (AuthService().isLockScreenVisible) return;
    navigatorKey.currentState?.push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => LockScreen(
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
          supportedLocales: const [
             Locale('zh', 'CN'),
             Locale('en', 'US'),
          ],
          home: _buildHomePage(),
          scrollBehavior: AppScrollBehavior(),
        );
      },
    );
  }
  
  Widget _buildHomePage() {
    if (widget.showIntro) return const IntroPage();
    switch (widget.startupPage) {
      case 'moments': return const MomentsPage();
      case 'writer':
      default: return const DiaryListPage();
    }
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
