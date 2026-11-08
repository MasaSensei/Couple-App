import 'package:flutter/foundation.dart';

/// Single place every uncaught error goes through.
///
/// No crash-reporting service is connected yet (provider choice pending, see
/// docs/operations/release-checklist.md). Until then release builds only keep
/// errors local. When a provider (e.g. Sentry or Crashlytics) is added, send
/// [scrub]bed text from [report] — never request bodies, tokens, keys,
/// recovery keys, photo bytes or user content.
abstract final class CrashReporter {
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }

  static void report(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Uncaught: ${scrub(error.toString())}');
    }
    // Release: hand scrub(error.toString()) + stack to the crash provider here.
  }

  static final _patterns = <RegExp, String>{
    RegExp(r'Bearer\s+[A-Za-z0-9._|~+/=-]+', caseSensitive: false):
        'Bearer [REDACTED]',
    RegExp(r'\b\d+\|[A-Za-z0-9]{40,}\b'): '[REDACTED]',
    RegExp(r'\b[A-Z2-7]{4}(?:-[A-Z2-7]{4}){12}\b'): '[REDACTED]',
    RegExp(r'(password|token|secret|key)=([^&\s]+)', caseSensitive: false):
        r'$1=[REDACTED]',
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'): '[EMAIL]',
  };

  /// Removes tokens, recovery keys and emails from free text.
  static String scrub(String text) {
    var result = text;
    _patterns.forEach((pattern, replacement) {
      result = result.replaceAllMapped(pattern, (match) {
        if (replacement.contains(r'$1')) {
          return replacement.replaceFirst(r'$1', match.group(1) ?? '');
        }
        return replacement;
      });
    });
    return result;
  }
}
