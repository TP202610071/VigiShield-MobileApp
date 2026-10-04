import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hardware is deliberately unavailable outside Android; no simulated success.
class ValidationPlatform {
  static const channel = MethodChannel('vigishield/validation');
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<dynamic> invoke(String method, [Map<String, dynamic>? args]) {
    if (!supported) throw UnsupportedError('Grabación y llamadas de prueba solo disponibles en Android.');
    return channel.invokeMethod<dynamic>(method, args);
  }
}
