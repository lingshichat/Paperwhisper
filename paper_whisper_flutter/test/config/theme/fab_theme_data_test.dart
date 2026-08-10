import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paper_whisper_flutter/core/theme/components/fab_theme_data.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';

void main() {
  setUpAll(ThemeRegistry.init);

  group('ThemeRegistry 注册基线', () {
    test('allThemes 的 ID 与注册顺序保持不变', () {
      expect(ThemeRegistry.allThemes.map((t) => t.id).toList(), [
        'default', // vintage 复古纸张
        'midnight',
        'amber_lens',
        'after_rain',
        'twilight',
        'garden_of_words',
        'sea_flower',
      ]);
    });
  });

  group('七主题 Fab Color/Gradient 分支', () {
    test('default(vintage) 使用纯色 backgroundColor 0xFFC0392B', () {
      final fab = ThemeRegistry.get('default').fab;
      expect(fab.backgroundColor, const Color(0xFFC0392B));
      expect(fab.backgroundGradient, isNull);
    });

    const gradientByTheme = <String, Type>{
      'midnight': LinearGradient,
      'amber_lens': LinearGradient,
      'after_rain': LinearGradient,
      'twilight': RadialGradient,
      'garden_of_words': LinearGradient,
      'sea_flower': LinearGradient,
    };

    for (final entry in gradientByTheme.entries) {
      test('${entry.key} 使用 backgroundGradient (${entry.value})', () {
        final fab = ThemeRegistry.get(entry.key).fab;
        expect(fab.backgroundColor, isNull);
        expect(fab.backgroundGradient.runtimeType, entry.value);
        expect(fab.backgroundGradient, isA<Gradient>());
      });
    }
  });

  group('构造断言', () {
    const shadow = BoxShadow(color: Colors.black);
    const gradient = LinearGradient(colors: [Colors.red, Colors.blue]);

    test('backgroundColor 与 backgroundGradient 同时提供时抛 AssertionError', () {
      expect(
        () => FabThemeData(
          backgroundColor: Colors.red,
          backgroundGradient: gradient,
          shadow: shadow,
          iconColor: Colors.white,
        ),
        throwsAssertionError,
      );
    });

    test('两者都缺省时抛 AssertionError', () {
      expect(
        () => FabThemeData(shadow: shadow, iconColor: Colors.white),
        throwsAssertionError,
      );
    });

    test('恰好一个非空时可正常构造并保留对应 typed 字段', () {
      final solid = FabThemeData(
        backgroundColor: Colors.red,
        shadow: shadow,
        iconColor: Colors.white,
      );
      expect(solid.backgroundColor, Colors.red);
      expect(solid.backgroundGradient, isNull);
      final faded = FabThemeData(
        backgroundGradient: gradient,
        shadow: shadow,
        iconColor: Colors.white,
      );
      expect(faded.backgroundColor, isNull);
      expect(faded.backgroundGradient, same(gradient));
    });
  });
}
