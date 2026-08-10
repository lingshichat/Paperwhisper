import 'package:flutter/widgets.dart';

final class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({
    required this.onPaused,
    required this.onResumed,
    required this.onPlatformBrightnessChanged,
  });

  final VoidCallback onPaused;
  final VoidCallback onResumed;
  final VoidCallback onPlatformBrightnessChanged;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      onPaused();
    }
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }

  @override
  void didChangePlatformBrightness() {
    onPlatformBrightnessChanged();
  }
}
