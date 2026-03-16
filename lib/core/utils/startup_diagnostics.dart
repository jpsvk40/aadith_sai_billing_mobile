import 'dart:async';

import 'package:flutter/services.dart';

class StartupDiagnostics {
  static const MethodChannel _channel = MethodChannel(
    'aadith_sai_billing_mobile/startup_diagnostics',
  );

  static Future<void> report(String message) async {
    try {
      await _channel.invokeMethod('startupState', {'message': message});
    } catch (_) {
      // Ignore diagnostics failures in production startup.
    }
  }

  static void reportAsync(String message) {
    unawaited(report(message));
  }
}
