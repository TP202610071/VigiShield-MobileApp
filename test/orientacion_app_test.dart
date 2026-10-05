import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/orientation/orientacion_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final o = OrientacionApp.instance;
  final aplicadas = <List<dynamic>>[];

  setUp(() {
    // El plugin del acelerómetro no existe en las pruebas: se simula vacío y
    // las lecturas se inyectan con muestra().
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/sensors/method'), (_) async => null);
    m.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/sensors/accelerometer'), (_) async => null);
    o.reiniciarParaPruebas();
    aplicadas.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        aplicadas.add(call.arguments as List<dynamic>);
      }
      return null;
    });
  });

  test('sin transmitir: vertical, y horizontal solo con la pestaña Cámara visible', () {
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
    o.setPestanaCamara(true);
    expect(o.deseada(), [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    // Una pantalla abierta encima de la pestaña Cámara vuelve a vertical.
    o.setPestanaCamara(false);
    expect(aplicadas.last, ['DeviceOrientation.portraitUp']);
  });

  test('transmitiendo manda la posición física, aunque sea la pestaña Cámara', () async {
    o.setPestanaCamara(true);
    final inicio = o.iniciarTransmision(esperaGiro: Duration.zero);
    o.muestra(0.3, 9.7, 0.5); // teléfono de pie
    await inicio;
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
    expect(aplicadas.last, ['DeviceOrientation.portraitUp']);
    o.finTransmision();
    expect(aplicadas.last, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
  });

  test('un giro físico sostenido cambia la pantalla y pide reiniciar la sesión', () async {
    DeviceOrientation? reiniciada;
    o.alCambiarFisicaTransmitiendo = (n) => reiniciada = n;
    final inicio = o.iniciarTransmision(esperaGiro: Duration.zero);
    o.muestra(0.2, 9.8, 0.3);
    await inicio;
    final t0 = DateTime(2026, 10, 5, 12);
    // Un movimiento breve no cuenta.
    o.muestra(9.6, 0.4, 0.5, ahora: t0);
    o.muestra(0.2, 9.8, 0.3, ahora: t0.add(const Duration(milliseconds: 300)));
    expect(reiniciada, isNull);
    // Girado y quieto: a los 0.8 s se adopta.
    o.muestra(9.6, 0.4, 0.5, ahora: t0.add(const Duration(seconds: 1)));
    o.muestra(9.6, 0.4, 0.5, ahora: t0.add(const Duration(milliseconds: 1900)));
    expect(o.deseada(), [DeviceOrientation.landscapeLeft]);
    expect(reiniciada, DeviceOrientation.landscapeLeft);
  });

  test('sobre la mesa no se cambia nada', () async {
    final inicio = o.iniciarTransmision(esperaGiro: Duration.zero);
    o.muestra(0.1, 9.8, 0.2);
    await inicio;
    o.muestra(0.2, 0.3, 9.8, ahora: DateTime(2026));
    o.muestra(0.2, 0.3, 9.8, ahora: DateTime(2026, 1, 1, 0, 0, 5));
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
  });
}
