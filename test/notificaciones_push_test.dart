import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/notificaciones_push.dart';

/// Guarda lo que la app le manda al backend.
class _Api extends ApiClient {
  _Api() : super(AuthStorage());
  final List<(String, dynamic)> enviados = [];

  @override
  Future<T> post<T>(String path, {dynamic body}) async {
    enviados.add((path, body));
    return (path.endsWith('/prueba')
        ? {'dispositivos': 1, 'enviados': 1, 'invalidos': 0, 'fallidos': 0, 'configurado': true}
        : null) as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('vigishield/push-prueba');
  late _Api api;
  String? tokenNativo;

  setUp(() {
    api = _Api();
    tokenNativo = 'a1b2c3';
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, (llamada) async {
      return switch (llamada.method) {
        'pedirPermisoYToken' => tokenNativo,
        'entorno' => 'sandbox',
        'eventoInicial' => null,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
  });

  test('en iPhone registra el token de APNs con su entorno', () async {
    final push = NotificacionesPush(api, canal: canal);
    await push.activar();
    expect(push.estado, EstadoPush.activas);
    expect(api.enviados.single.$1, '/api/push/dispositivos');
    expect(api.enviados.single.$2, {'token': 'a1b2c3', 'plataforma': 'ios', 'entorno': 'sandbox'});

    // Llamarlo otra vez (cada cambio de sesión lo hace) no vuelve a registrar.
    await push.activar();
    expect(api.enviados, hasLength(1));
  });

  test('sin permiso no registra nada ni vuelve a preguntar solo', () async {
    tokenNativo = null;
    final push = NotificacionesPush(api, canal: canal);
    await push.activar();
    expect(push.estado, EstadoPush.sinPermiso);
    expect(api.enviados, isEmpty);

    tokenNativo = 'a1b2c3';
    await push.activar();
    expect(push.estado, EstadoPush.sinPermiso, reason: 'solo desde Ajustes');
    await push.activar(forzar: true);
    expect(push.estado, EstadoPush.activas);
  });

  test('al cerrar sesión da de baja el teléfono', () async {
    final push = NotificacionesPush(api, canal: canal);
    await push.activar();
    push.clearSession();
    await Future<void>.delayed(Duration.zero);
    expect(push.estado, EstadoPush.desconocido);
    expect(api.enviados.last.$1, '/api/push/dispositivos/baja');
    expect(api.enviados.last.$2, {'token': 'a1b2c3'});
  });

  test('un mismo toque no abre el evento dos veces', () {
    final abiertos = <String>[];
    final push = NotificacionesPush(api, canal: canal)..alAbrirEvento = abiertos.add;
    push.abrir('e1');
    push.abrir('e1');
    push.abrir('e2');
    expect(abiertos, ['e1', 'e2']);
  });

  test('la prueba informa cuántas se enviaron', () async {
    final push = NotificacionesPush(api, canal: canal);
    final r = await push.enviarPrueba();
    expect(r.enviados, 1);
    expect(r.configurado, isTrue);
  });
}
