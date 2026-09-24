import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/data/services/camera_lan_control.dart';

/// Interceptor que responde como el CGI de una hi3510, sin red real.
class _FakeCamera extends Interceptor {
  final Map<String, String> respuestas;
  final bool caida;
  final int estado;
  final List<String> pedidos = [];
  String? autorizacion;

  _FakeCamera(this.respuestas, {this.caida = false, this.estado = 200});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    pedidos.add(options.uri.query);
    autorizacion = options.headers['Authorization'] as String?;
    if (caida) {
      handler.reject(DioException.connectionTimeout(
          timeout: const Duration(seconds: 4), requestOptions: options));
      return;
    }
    final cmd = options.uri.queryParameters['cmd'] ?? '';
    final clave = cmd.split('&').first;
    handler.resolve(Response<String>(
      requestOptions: options,
      statusCode: estado,
      data: respuestas[clave] ?? '',
    ));
  }
}

CameraLanControl _control(_FakeCamera camara, {String? user, String? pass}) {
  final dio = Dio()..interceptors.add(camara);
  return CameraLanControl(
    CameraLanAccess(ip: '192.168.1.82', httpPort: 80, username: user, password: pass),
    dio: dio,
  );
}

void main() {
  test('lee y parsea las variables que devuelve el CGI', () async {
    final camara = _FakeCamera({
      'getimageattr': 'var brightness="55";\nvar contrast="50";\nvar wdr="on";',
      'getvencattr': 'var bps="2048";\nvar fps="25";\nvar gop="50";',
      'getinfrared': 'var infraredstat="auto";',
    });

    final valores = await _control(camara).read();

    expect(valores['brightness'], '55');
    expect(valores['wdr'], 'on');
    expect(valores['bps'], '2048');
    expect(valores['infraredstat'], 'auto');
  });

  test('manda cada ajuste al comando CGI que le corresponde', () async {
    final camara = _FakeCamera({});

    await _control(camara).apply({
      'brightness': '60',
      'wdr': 'on',
      'fps': '20',
      'infraredstat': 'close',
    });

    final consultas = camara.pedidos.join(' ');
    // Imagen y video van en comandos distintos; el infrarrojo en el suyo.
    expect(consultas, contains('cmd=setimageattr'));
    expect(consultas, contains('-brightness=60'));
    expect(consultas, contains('-wdr=on'));
    expect(consultas, contains('cmd=setvencattr'));
    expect(consultas, contains('-fps=20'));
    expect(consultas, contains('cmd=setinfrared'));
    expect(consultas, contains('-infraredstat=close'));
    // El bitrate no se tocó, así que no debe viajar.
    expect(consultas, isNot(contains('-bps=')));
  });

  test('autentica con Basic cuando la cámara tiene usuario', () async {
    final camara = _FakeCamera({'getimageattr': 'var brightness="50";'});

    await _control(camara, user: 'admin', pass: 's3creto').read();

    expect(camara.autorizacion,
        'Basic ${base64Encode(utf8.encode('admin:s3creto'))}');
  });

  test('si la cámara no responde, avisa en vez de devolver valores vacíos', () async {
    final camara = _FakeCamera({}, caida: true);

    expect(_control(camara).read(), throwsA(isA<CameraLanUnreachable>()));
  });

  test('un 401 de la cámara se reporta como credenciales, no como red caída', () async {
    // La cámara real contesta 'WWW-Authenticate: Basic' con 401 si el usuario
    // o la contraseña guardados no valen. Ese caso se arregla corrigiendo las
    // credenciales, no cambiando de wifi, así que debe distinguirse.
    final camara = _FakeCamera({}, estado: 401);

    expect(_control(camara, user: 'admin', pass: 'mala').read(),
        throwsA(isA<CameraLanAuthFailed>()));
  });

  test('un 401 al aplicar también se reporta como credenciales', () async {
    final camara = _FakeCamera({}, estado: 401);

    expect(_control(camara, user: 'admin', pass: 'mala').apply({'brightness': '60'}),
        throwsA(isA<CameraLanAuthFailed>()));
  });

  test('una lectura sin ninguna variable también se trata como inalcanzable', () async {
    // La cámara contesta 200 pero con un cuerpo que no trae `var x="y";`.
    final camara = _FakeCamera({'getimageattr': '<html>404</html>'});

    expect(_control(camara).read(), throwsA(isA<CameraLanUnreachable>()));
  });
}
