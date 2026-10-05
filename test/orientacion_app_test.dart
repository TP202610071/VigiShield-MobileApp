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

  test('transmitiendo, la interfaz sigue en vertical aunque el teléfono esté acostado', () async {
    final inicio = o.iniciarTransmision();
    o.muestra(9.6, 0.4, 0.5); // acostado, girado a la izquierda
    await inicio;
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
    expect(aplicadas.every((a) => a.length == 1 && a.first == 'DeviceOrientation.portraitUp'), isTrue);
    // La posición física solo fija la rotación del video.
    expect(o.gradosFisicos, 90);
    // La pestaña Cámara sí va en horizontal, y al salir vuelve la vertical.
    o.setPestanaCamara(true);
    expect(aplicadas.last, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
    o.setPestanaCamara(false);
    expect(aplicadas.last, ['DeviceOrientation.portraitUp']);
    o.finTransmision();
  });

  test('un giro físico sostenido pide reiniciar la sesión sin girar la pantalla', () async {
    DeviceOrientation? reiniciada;
    o.alCambiarFisicaTransmitiendo = (n) => reiniciada = n;
    final inicio = o.iniciarTransmision();
    o.muestra(0.2, 9.8, 0.3);
    await inicio;
    expect(o.gradosFisicos, 0);
    final t0 = DateTime(2026, 10, 5, 12);
    // Un movimiento breve no cuenta.
    o.muestra(-9.6, 0.4, 0.5, ahora: t0);
    o.muestra(0.2, 9.8, 0.3, ahora: t0.add(const Duration(milliseconds: 300)));
    expect(reiniciada, isNull);
    // Girado y quieto un rato corto: todavía no (se está manipulando).
    o.muestra(-9.6, 0.4, 0.5, ahora: t0.add(const Duration(seconds: 1)));
    o.muestra(-9.6, 0.4, 0.5, ahora: t0.add(const Duration(milliseconds: 2000)));
    expect(reiniciada, isNull);
    // Quieto 2.5 s: se adopta y se pide reiniciar.
    o.muestra(-9.6, 0.4, 0.5, ahora: t0.add(const Duration(milliseconds: 3600)));
    expect(reiniciada, DeviceOrientation.landscapeRight);
    expect(o.gradosFisicos, 270);
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
  });

  test('sobre la mesa no se cambia nada', () async {
    final inicio = o.iniciarTransmision();
    o.muestra(0.1, 9.8, 0.2);
    await inicio;
    o.muestra(0.2, 0.3, 9.8, ahora: DateTime(2026));
    o.muestra(0.2, 0.3, 9.8, ahora: DateTime(2026, 1, 1, 0, 0, 5));
    expect(o.gradosFisicos, 0);
    expect(o.deseada(), [DeviceOrientation.portraitUp]);
  });

  test('el clip a pantalla completa va en horizontal y al cerrarlo vuelve la vertical', () {
    o.setVideoCompleto(true);
    expect(o.deseada(), [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    o.setVideoCompleto(false);
    expect(aplicadas.last, ['DeviceOrientation.portraitUp']);
  });
}
