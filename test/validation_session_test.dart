import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/providers/validation_provider.dart';
import 'package:vigishield_mobile_app/data/services/validation_platform.dart';

class Hardware extends ValidationPlatform {
  @override bool get supported => true;
  final calls = <String>[];
  @override Future<dynamic> invoke(String method, [Map<String, dynamic>? args]) async { calls.add(method); return true; }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('old async response after logout cannot start session', () async {
    final pending = Completer<bool>();
    final h = Hardware();
    final p = ValidationProvider(platform: h, canMonitor: () => true,
      loadPaused: () => pending.future, loadCameras: () async => [],
      loadEvents: (_) async => [], loadStatus: (_) async => {});
    final start = p.start();
    p.clearSession();
    pending.complete(false);
    await start;
    expect(p.active, false);
    expect(p.callOptIn, false);
    expect(h.calls.contains('placeTestCall'), false);
    p.dispose();
  });
  test('event dedupe is bounded and rejects history', () {
    final cache = ValidationEventCache(capacity: 2);
    expect(cache.accept('a', 10, 10), true);
    expect(cache.accept('a', 10, 10), false);
    expect(cache.accept('old', 9, 10), false);
    cache.accept('b', 11, 10); cache.accept('c', 12, 10);
    expect(cache.length, 2);
  });
}
