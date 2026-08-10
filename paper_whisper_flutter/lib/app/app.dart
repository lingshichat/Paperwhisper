import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/features/auth/presentation/splash_page.dart';
import 'package:paper_whisper_flutter/features/auth/presentation/widgets/lock_screen.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/auth/data/auth_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/services/storage_service.dart';

import 'app_lifecycle_observer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PaperWhisperApp extends StatefulWidget {
  const PaperWhisperApp({
    super.key,
    required this.showIntro,
    required this.startupPage,
    required this.isLocked,
  });

  final bool showIntro;
  final String startupPage;
  final bool isLocked;

  @override
  State<PaperWhisperApp> createState() => _PaperWhisperAppState();
}

class _PaperWhisperAppState extends State<PaperWhisperApp> {
  late final AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(
      onPaused: () => AuthService().lockApp(),
      onResumed: _handleResumed,
      onPlatformBrightnessChanged: _handlePlatformBrightnessChanged,
    )..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageService(
        momentService: context.read<MomentService>(),
      ).cleanTemporaryCache();

      // SplashPage owns cold-start locking. The app observer handles resumes.
      if (mounted) {
        context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
      }
    });
  }

  @override
  void dispose() {
    _lifecycleObserver.dispose();
    super.dispose();
  }

  void _handleResumed() {
    if (mounted) {
      context.read<SyncProvider>().requestAutoSync(fromLifecycle: true);
    }
    _checkLock();
  }

  void _handlePlatformBrightnessChanged() {
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

  void _showLockScreen() {
    if (AuthService().isLockScreenVisible) {
      return;
    }
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
