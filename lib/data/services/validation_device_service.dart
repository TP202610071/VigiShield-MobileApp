import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only, user-consented validation operations. No audio is captured.
/// Clip maps: eventId/path/status/createdAtMs/preMs/postMs/durationMs,
/// startsWithKeyframe/keyframeCount/width/height/audio/reason.
/// Poll listScreenClips after markScreenEvent: only finalized clips are listed.
class ValidationDeviceService {
  const ValidationDeviceService();

  static const MethodChannel _channel = MethodChannel('vigishield/validation');
  static const String testCallNumber = '+51986913791';
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _requireAndroid() {
    if (!isSupported) {
      throw UnsupportedError('Validation device features are Android-only; iOS is unsupported.');
    }
  }

  Future<Map<String, dynamic>> _map(String method, [Map<String, dynamic>? args]) async {
    _requireAndroid();
    final result = await _channel.invokeMapMethod<String, dynamic>(method, args);
    if (result == null) throw StateError('$method returned no result');
    return result;
  }

  Future<bool> _bool(String method, [Map<String, dynamic>? args]) async {
    _requireAndroid();
    final result = await _channel.invokeMethod<bool>(method, args);
    if (result == null) throw StateError('$method returned no result');
    return result;
  }

  Future<Map<String, dynamic>> deviceCapabilities() async {
    if (!isSupported) {
      return <String, dynamic>{
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'screenCapture': false, 'testAlarm': false, 'testCall': false,
        'screenBufferRunning': false, 'testCallArmed': false,
        'callPermissionGranted': false, 'audioCapture': false,
        'unsupportedReason': 'Validation device features are Android-only',
      };
    }
    return _map('deviceCapabilities');
  }

  Future<Map<String, dynamic>> startScreenBuffer() => _map('startScreenBuffer');
  Future<Map<String, dynamic>> stopScreenBuffer() => _map('stopScreenBuffer');
  Future<Map<String, dynamic>> markScreenEvent({required String eventId}) =>
      _map('markScreenEvent', <String, dynamic>{'eventId': eventId});
  Future<List<Map<String, dynamic>>> listScreenClips() async {
    _requireAndroid();
    final result = await _channel.invokeListMethod<dynamic>('listScreenClips');
    if (result == null) throw StateError('listScreenClips returned no result');
    return result.map((dynamic entry) => Map<String, dynamic>.from(entry as Map)).toList();
  }
  Future<bool> deleteScreenClip({required String path}) =>
      _bool('deleteScreenClip', <String, dynamic>{'path': path});
  /// Low-volume (15%) tone, vibration and window brightness; auto-stop at 30s.
  Future<bool> startTestAlarm() => _bool('startTestAlarm');
  Future<bool> stopTestAlarm() => _bool('stopTestAlarm');
  Future<bool> requestTestCallPermission() => _bool('requestTestCallPermission');
  Future<bool> setTestCallArmed({required bool enabled}) =>
      _bool('setTestCallArmed', <String, dynamic>{'enabled': enabled});
  /// Dispatches one call to testCallNumber only. True does not mean connected.
  /// Requires permission and fresh one-shot arming. Never invoke in tests.
  Future<bool> placeTestCall() => _bool('placeTestCall');
}
