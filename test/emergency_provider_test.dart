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
  late int persons;
  late bool offline;
  late _FakeEffects fx;
  late EmergencyProvider p;

  EmergencyProvider crear(EmergencySettings s) => EmergencyProvider(
        readSettings: () async => s.encode(),
        writeSettings: (_) async {},
        effects: fx,
        canMonitor: () => true,
        loadCameras: () async => [_cam],
        loadStatus: (_) async {
          if (offline) throw Exception('sin datos');
          return {'state': 'ok', 'ts': now, 'persons': persons, 'intent': {'state': state}};
        },
        clock: () => now,
      );

  Future<void> step(double seconds) async {
    now += seconds;
    await p.pollNow();
    p.tickNow();
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    now = 1000;
    state = 'calm';
    persons = 1;
    offline = false;
    fx = _FakeEffects();
    p = crear(const EmergencySettings(phone: '+51 900 000 001', sustainSeconds: 5, countdownSeconds: 15));
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
    expect(fx.calls, ['+51900000001']);
    expect(p.counting, isFalse);
    // Sigue en riesgo pero ya llamó: no repite hasta volver a la calma.
    for (var i = 0; i < 30; i++) { await step(1); }
    expect(fx.calls, hasLength(1));
  });

  test('si dejan de llegar datos, la cuenta atrás sigue hasta llamar', () async {
    await p.load();
    state = 'suspect';
    for (var i = 0; i < 7; i++) { await step(1); }
    expect(p.counting, isTrue);
    final antes = p.remaining;
    offline = true; // la cámara deja de responder
    await step(3);
    expect(p.counting, isTrue);
    expect(p.remaining, lessThan(antes)); // el número sigue bajando, no se congela
    for (var i = 0; i < 15; i++) { await step(1); }
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

  test('la prueba dura 10 s y llama al terminar si la llamada está activa', () async {
    await p.load();
    await p.test();
    expect(p.counting, isTrue);
    expect(p.remaining, EmergencyProvider.testSeconds);
    for (var i = 0; i < 11; i++) { await step(1); }
    expect(p.counting, isFalse);
    expect(fx.calls, ['+51900000001']);
  });

  test('la prueba no llama si la llamada está desactivada', () async {
    p.dispose();
    p = crear(const EmergencySettings(phone: '+51 900 000 001', autoCall: false));
    await p.load();
    await p.test();
    for (var i = 0; i < 11; i++) { await step(1); }
    expect(fx.calls, isEmpty);
  });

  test('sin persona en cuadro no hay alerta', () async {
    persons = 0;
    state = 'high_risk';
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
