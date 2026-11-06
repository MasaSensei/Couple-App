import 'package:flutter/services.dart';

/// Hides a screen from screenshots, screen recording and the app switcher
/// while it shows recovery secrets. Android only (FLAG_SECURE); on other
/// platforms the calls are no-ops.
class SecureScreen {
  static const _channel = MethodChannel('couple_app/secure_screen');

  static Future<void> enable() => _invoke('enable');

  static Future<void> disable() => _invoke('disable');

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // iOS, desktop and widget tests have no handler.
    } on PlatformException {
      // Best effort: never block the recovery flow on this.
    }
  }
}
