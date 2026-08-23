import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ThemeRegistry.init);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('setTheme 先发布内存主题，再完成持久化', () async {
    final provider = SettingsProvider(
      bootstrapData: const SettingsBootstrapData(
        storedTheme: AppTheme.themeDefault,
        preferredTheme: AppTheme.themeDefault,
        followSystemTheme: false,
        startupPage: 'last',
        compatibilityMode: false,
      ),
    );
    var notificationCount = 0;
    provider.addListener(() => notificationCount++);

    final persistence = provider.setTheme(AppTheme.themeMidnight);

    expect(provider.currentTheme, AppTheme.themeMidnight);
    expect(provider.followSystemTheme, isFalse);
    expect(notificationCount, 1);

    await persistence;
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme'), AppTheme.themeMidnight);
    expect(preferences.getString('preferred_theme'), AppTheme.themeMidnight);
    expect(preferences.getBool('follow_system_theme'), isFalse);
    expect(notificationCount, 1);
  });
}
