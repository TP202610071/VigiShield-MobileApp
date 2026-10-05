import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/models/emergency_settings.dart';
import 'package:vigishield_mobile_app/data/services/emergency_effects.dart';
import 'package:vigishield_mobile_app/providers/emergency_provider.dart';

class _FakeEffects implements EmergencyEffects {
  final log = <String>[];
  final calls = <String>[];
  @override Future<void> start(double volume) async => log.add('start $volume');
  @override Future<void> setVolume(double volume) async => log.add('volume $volume');
  @override Future<void> stop() async => log.add('stop');
  @override Future<bool> requestCallPermission() async => true;
  @override Future<bool> call(String number) async { calls.add(number); return true; }
}

const _cam = CameraConfigModel(id: 'c1', name: 'Entrada', isDefault: true,
    streamMode: 'RtmpRelay', cameraPort: 554, hasPassword: false,
    hlsViewUrl: 'https://ai.invalid/k/index.m3u8', isConfigured: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late double now;
  late String state;
  late _FakeEffects fx;
  late EmergencyProvider p;

  Future<void> step(double seconds) async {
    now += seconds;
    await p.pollNow();
    p.tickNow();
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    now = 1000;
    state = 'calm';
    fx = _FakeEffects();
    p = EmergencyProvider(
      readSettings: () async => const EmergencySettings(
          phone: '+51 999 888 777', sustainSeconds: 5, countdownSeconds: 15).encode(),
      writeSettings: (_) async {},
      effects: fx,
      canMonitor: () => true,
      loadCameras: () async => [_cam],
      loadStatus: (_) async => {'state': 'ok', 'ts': now, 'persons': 1, 'intent': {'state': state}},
      clock: () => now,
    );
  });
  tearDown(() => p.dispose());

  test('riesgo sostenido: alerta, cuenta atrás y una sola llamada', () async {
    await p.load();
    await step(0);
    state = 'high_risk';
    for (var i = 0; i < 6; i++) { await step(1); }
    expect(p.counting, isTrue);
    expect(p.cameraName, 'Entrada');
    expect(fx.log, contains('start ${EmergencySettings.minVolume}'));
    for (var i = 0; i < 16; i++) { await step(1); }
    expect(fx.calls, ['+51999888777']);
    expect(p.counting, isFalse);
    // Sigue en riesgo pero ya llamó: no repite hasta volver a la calma.
    for (var i = 0; i < 30; i++) { await step(1); }
    expect(fx.calls, hasLength(1));
  });

  test('desactivarla a tiempo evita la llamada', () async {
    await p.load();
    state = 'suspect';
    for (var i = 0; i < 7; i++) { await step(1); }
    expect(p.counting, isTrue);
    p.dismiss();
    for (var i = 0; i < 30; i++) { await step(1); }
    expect(fx.calls, isEmpty);
    expect(fx.log.last, 'stop');
  });

  test('una prueba suena pero nunca llama', () async {
    await p.load();
    p.test();
    expect(p.counting, isTrue);
    for (var i = 0; i < 12; i++) { await step(1); }
    expect(p.counting, isFalse);
    expect(fx.calls, isEmpty);
  });

  test('sin persona en cuadro no hay alerta', () async {
    p.dispose();
    p = EmergencyProvider(
      readSettings: () async => const EmergencySettings(sustainSeconds: 5).encode(),
      writeSettings: (_) async {},
      effects: fx,
      canMonitor: () => true,
      loadCameras: () async => [_cam],
      loadStatus: (_) async => {'state': 'ok', 'ts': now, 'persons': 0, 'intent': {'state': 'high_risk'}},
      clock: () => now,
    );
    await p.load();
    for (var i = 0; i < 20; i++) { await step(1); }
    expect(p.counting, isFalse);
  });

  test('números cortos de emergencia no se aceptan', () {
    expect(normalizePhone('105'), isNull);
    expect(normalizePhone('911'), isNull);
    expect(normalizePhone('+51 900-000-001'), '+51900000001');
    expect(normalizePhone('900000001'), '900000001');
  });
}
