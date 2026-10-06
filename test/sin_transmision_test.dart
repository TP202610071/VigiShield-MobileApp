import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/data/services/estado_transmision.dart';
import 'package:vigishield_mobile_app/data/services/mobile_camera_publisher.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/screens/camera/aviso_sin_transmision.dart';
import 'package:vigishield_mobile_app/screens/settings/cameras_list_screen.dart';

CameraConfigModel _camara({String modo = 'MobileWebRtc'}) => CameraConfigModel.fromJson({
      'id': 'c1',
      'name': 'Celular de la puerta',
      'streamMode': modo,
      'streamKey': 'abc123',
      'hlsViewUrl': 'https://api-ai.vigishield.app/abc123/index.m3u8',
    });

class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.responder);
  final ResponseBody Function(RequestOptions) responder;
  RequestOptions? ultima;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    ultima = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object cuerpo, [int codigo = 200]) => ResponseBody.fromString(
      jsonEncode(cuerpo),
      codigo,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

class _Captura implements MobileCameraCapture {
  @override
  MediaStream? get stream => null;
  @override
  Future<void> open({required bool front}) async {}
  @override
  Future<bool> hasTorch() async => false;
  @override
  Future<void> setTorch(bool enabled) async {}
  @override
  Future<String> offer(Duration timeout) async => 'offer';
  @override
  Future<void> answer(String sdp) async {}
  @override
  Future<void> close() async {}
}

class _Transporte implements MobilePublishTransport {
  final publicadas = <String>[];
  @override
  Future<MobilePublishAnswer> publish(String id, String sdp) async {
    publicadas.add(id);
    return const MobilePublishAnswer('sesion', 'answer');
  }

  @override
  Future<void> unpublish(String id, String sessionId) async {}
}

MobileCameraPublisher _publicador(_Transporte t) =>
    MobileCameraPublisher(transport: t, capture: _Captura(), observarCicloDeVida: false);

class _Estado extends EstadoTransmision {
  _Estado(this.valor) : super(AuthStorage());
  bool? valor;
  @override
  Future<bool?> enVivo(CameraConfigModel cam) async => valor;
}

class _Auth extends AuthProvider {
  _Auth(this.role) : super(AuthService(ApiClient(AuthStorage())), AuthStorage());
  final String role;
  @override
  UserModel get user =>
      UserModel(id: 'u', email: 'x', name: 'User', role: role, householdId: 'h', createdAt: DateTime(2026));
}

class _Camaras extends CameraProvider {
  _Camaras() : super(CameraDataService(ApiClient(AuthStorage())));
  @override
  Future<void> fetchCameras() async {}
  @override
  List<CameraConfigModel> get cameras => [_camara()];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('consulta al servidor', () {
    test('arma la URL con el servidor de video y la clave de la cámara', () {
      expect(EstadoTransmision.urlEnVivo(_camara()), 'https://api-ai.vigishield.app/ai/en-vivo/abc123');
      expect(EstadoTransmision.urlEnVivo(CameraConfigModel.fromJson({'id': 'x', 'streamMode': 'MobileWebRtc'})), isNull);
    });

    test('lee sí, no y, si no se puede saber, null', () async {
      for (final (respuesta, esperado) in [
        (_json({'enVivo': true}), true),
        (_json({'enVivo': false}), false),
        (_json({'error': 'x'}, 503), null),
      ]) {
        final adaptador = _Adaptador((_) => respuesta);
        final estado = EstadoTransmision(AuthStorage(), dio: Dio()..httpClientAdapter = adaptador);
        expect(await estado.enVivo(_camara()), esperado);
        expect(adaptador.ultima!.uri.toString(), 'https://api-ai.vigishield.app/ai/en-vivo/abc123');
      }
    });

    test('una cámara IP no se consulta', () async {
      final adaptador = _Adaptador((_) => _json({'enVivo': false}));
      final estado = EstadoTransmision(AuthStorage(), dio: Dio()..httpClientAdapter = adaptador);
      expect(await estado.enVivo(_camara(modo: 'DirectRtsp')), isNull);
      expect(adaptador.ultima, isNull);
    });
  });

  test('solo falta transmitir si nadie la transmite, tampoco este celular', () async {
    final cam = _camara();
    expect(faltaTransmitir(cam, null, false), isTrue);
    expect(faltaTransmitir(cam, null, true), isFalse);
    // Sin poder saberlo no se bloquea el video.
    expect(faltaTransmitir(cam, null, null), isFalse);
    expect(faltaTransmitir(_camara(modo: 'DirectRtsp'), null, false), isFalse);
    final pub = _publicador(_Transporte());
    await pub.start('c1', front: false);
    expect(transmiteEsteTelefono(cam, pub), isTrue);
    expect(faltaTransmitir(cam, pub, false), isFalse);
  });

  group('aviso en la pestaña Cámara', () {
    Future<void> montar(WidgetTester tester, Widget aviso) => tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LocaleProvider(AuthStorage(), AppLocale.es),
            child: MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: aviso)),
          ),
        );

    testWidgets('explica el corte y el botón transmite', (tester) async {
      var pulsado = 0;
      await montar(tester, AvisoSinTransmision(puedeTransmitir: true, arrancando: false, onTransmitir: () => pulsado++));
      expect(find.text('Esta cámara no está transmitiendo'), findsOneWidget);
      expect(find.textContaining('Al salir de la app'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transmitir-aqui')));
      expect(pulsado, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // solo el de «esperando»
    });

    testWidgets('mientras arranca, el botón queda deshabilitado', (tester) async {
      await montar(tester, AvisoSinTransmision(puedeTransmitir: true, arrancando: true, onTransmitir: () {}));
      expect(find.text('Iniciando transmisión…'), findsOneWidget);
      final boton = tester.widget<ButtonStyleButton>(find.byKey(const Key('transmitir-aqui')));
      expect(boton.onPressed, isNull);
    });

    testWidgets('un invitado no puede transmitir: se le dice a quién pedírselo', (tester) async {
      await montar(tester, const AvisoSinTransmision(puedeTransmitir: false, arrancando: false));
      expect(find.byKey(const Key('transmitir-aqui')), findsNothing);
      expect(find.textContaining('Pide a quien administra el hogar'), findsOneWidget);
    });

    testWidgets('cabe en horizontal sin desbordar', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await montar(tester, AvisoSinTransmision(puedeTransmitir: true, arrancando: false, error: 'Error', onTransmitir: () {}));
      expect(tester.takeException(), isNull);
    });
  });

  group('Mis cámaras', () {
    Future<_Transporte> montar(WidgetTester tester, _Estado estado, String rol) async {
      final transporte = _Transporte();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth(rol)),
          ChangeNotifierProvider<CameraProvider>(create: (_) => _Camaras()),
          ChangeNotifierProvider<MobileCameraPublisher>(create: (_) => _publicador(transporte)),
          Provider<EstadoTransmision>.value(value: estado),
          ChangeNotifierProvider(create: (_) => LocaleProvider(AuthStorage(), AppLocale.es)),
        ],
        child: const MaterialApp(home: CamerasListScreen()),
      ));
      await tester.pump();
      await tester.pump();
      return transporte;
    }

    testWidgets('sin transmitir: se ve y se puede transmitir desde aquí', (tester) async {
      // Permiso de cámara concedido (el plugin no existe en las pruebas).
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (llamada) async => llamada.method == 'checkPermissionStatus' ? 1 : null,
      );
      final estado = _Estado(false);
      final transporte = await montar(tester, estado, 'Primary');
      expect(find.text('Sin transmitir'), findsOneWidget);

      estado.valor = true; // el servidor ya lo ve en cuanto empieza
      await tester.tap(find.byKey(const ValueKey('transmitir-c1')));
      await tester.pump();
      await tester.pump();
      expect(transporte.publicadas, ['c1']);
      expect(find.text('Transmitiendo'), findsOneWidget);
      expect(find.byKey(const ValueKey('transmitir-c1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('transmitiendo desde otro celular', (tester) async {
      await montar(tester, _Estado(true), 'Primary');
      expect(find.text('Transmitiendo'), findsOneWidget);
      expect(find.byKey(const ValueKey('transmitir-c1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un invitado ve el estado pero no el botón', (tester) async {
      await montar(tester, _Estado(false), 'Secondary');
      expect(find.text('Sin transmitir'), findsOneWidget);
      expect(find.byKey(const ValueKey('transmitir-c1')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
