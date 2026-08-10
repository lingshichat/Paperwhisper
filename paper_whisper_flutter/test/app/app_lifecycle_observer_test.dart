import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:paper_whisper_flutter/app/app.dart';
import 'package:paper_whisper_flutter/app/app_lifecycle_observer.dart';

void main() {
  test('AppLifecycleObserver forwards only paused and resumed states', () {
    var paused = 0;
    var resumed = 0;
    var brightnessChanged = 0;
    final observer = AppLifecycleObserver(
      onPaused: () => paused += 1,
      onResumed: () => resumed += 1,
      onPlatformBrightnessChanged: () => brightnessChanged += 1,
    );

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    observer.didChangePlatformBrightness();

    expect(paused, 1);
    expect(resumed, 1);
    expect(brightnessChanged, 1);
  });

  test('AppScrollBehavior preserves touch, mouse, and trackpad dragging', () {
    expect(
      AppScrollBehavior().dragDevices,
      equals({
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      }),
    );
  });
}
