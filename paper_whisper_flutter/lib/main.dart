import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/diary_provider.dart';
import 'services/diary_service.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'pages/diary_list_page.dart';
import 'config/app_theme.dart'; // Added missing import
import 'pages/intro_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool showIntro = !(prefs.getBool('intro_shown') ?? false);
  
  final diaryService = DiaryService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DiaryProvider(diaryService)),
        ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
        ),
      ],
      child: MyApp(showIntro: showIntro),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showIntro;
  const MyApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: '纸语 PaperWhisper',
          debugShowCheckedModeBanner: false,
          // 使用 AppTheme 生成的动态 Theme，包含背景色修复和自定义转场
          theme: AppTheme.getThemeData(settings.currentTheme),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
             Locale('zh', 'CN'),
             Locale('en', 'US'),
          ],
            home: showIntro ? const IntroPage() : const DiaryListPage(),
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
