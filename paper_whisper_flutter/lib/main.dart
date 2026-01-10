import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/diary_provider.dart';
import 'providers/settings_provider.dart';
import 'pages/diary_list_page.dart';
import 'config/app_theme.dart'; // Added missing import

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DiaryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          home: const DiaryListPage(),
        );
      },
    );
  }
}
