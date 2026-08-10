import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/analytics_service.dart';
import 'package:paper_whisper_flutter/features/auth/data/auth_service.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/app/shell/data/hitokoto_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/premium/data/payment_service.dart';
import 'package:paper_whisper_flutter/features/premium/data/trial_service.dart';

import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  ThemeRegistry.init();

  final analytics = AnalyticsService();
  analytics.init().then((_) {
    analytics.trackEvent('app_launch');
  });

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
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
    return true;
  };

  // The composition root owns the only manifest-writing service instances.
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
  final initialEntries = results[1] as List<DiaryEntry>?;
  final showIntro = !(prefs.getBool('intro_shown') ?? false);

  AuthService().init(prefs);
  await TrialService().init(prefs);
  await PaymentService().init(prefs);

  final settingsBootstrapData = SettingsBootstrapData.fromPreferences(prefs);

  AuthService().lockApp();
  final isLocked = AuthService().isLocked;

  HitokotoService().fetchHitokoto();

  runApp(
    MultiProvider(
      providers: [
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
        ChangeNotifierProvider.value(value: PaymentService()),
      ],
      child: PaperWhisperApp(
        showIntro: showIntro,
        startupPage: settingsBootstrapData.startupPage,
        isLocked: isLocked,
      ),
    ),
  );
}
