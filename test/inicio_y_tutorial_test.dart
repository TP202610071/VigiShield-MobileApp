import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/models/system_status_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/data/services/system_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/providers/dev_settings_provider.dart';
import 'package:vigishield_mobile_app/providers/system_provider.dart';
import 'package:vigishield_mobile_app/widgets/inicio_camaras.dart';
import 'package:vigishield_mobile_app/widgets/servidor_video_caido.dart';
import 'package:vigishield_mobile_app/widgets/tutorial/tutorial_guiado.dart';

class _Camaras extends CameraDataService {
  _Camaras(super.api, this.lista);
  final List<CameraConfigModel> lista;

  @override
  Future<List<CameraConfigModel>> getCameras() async => lista;
}

class _Sistema implements SystemService {
  @override
  Future<SystemStatusModel> getStatus() async =>
      SystemStatusModel(isMonitoringActive: true, eventsTodayCount: 0, streamUrl: '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget hijo, {List<CameraConfigModel> camaras = const []}) {
  final storage = AuthStorage();
  final api = ApiClient(storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.es)),
      ChangeNotifierProvider(create: (_) => CameraProvider(_Camaras(api, camaras))),
      ChangeNotifierProvider(create: (_) => SystemProvider(_Sistema())),
      ChangeNotifierProvider(create: (_) => AuthProvider(AuthService(api), storage)),
      ChangeNotifierProvider(create: (_) => DevSettingsProvider(storage, null)),
    ],
    child: MaterialApp(home: Scaffold(body: hijo)),
  );
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('sin cámaras, el inicio pide agregar una antes que el video de ejemplo', (tester) async {
    await tester.pumpWidget(_app(const TarjetaInicioCamaras()));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes cámaras'), findsOneWidget);
    expect(find.text(const AppStrings(false).sampleCardTitle), findsNothing);
  });

  testWidgets('con una cámara propia, aparece el video de ejemplo', (tester) async {
    final cam = CameraConfigModel.fromJson({'id': 'c1', 'name': 'Puerta', 'streamMode': 'DirectRtsp'});
    await tester.pumpWidget(_app(const TarjetaInicioCamaras(), camaras: [cam]));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes cámaras'), findsNothing);
    expect(find.text(const AppStrings(false).sampleCardTitle), findsOneWidget);
  });

  test('el servidor de video se deduce de la URL de la cámara', () {
    final cam = CameraConfigModel.fromJson({
      'id': 'c1', 'streamMode': 'DirectRtsp',
      'hlsViewUrl': 'https://api-ai.vigishield.app/abc123/index.m3u8',
    });
    expect(ServidorVideoCaido.hostDe(cam), 'api-ai.vigishield.app');
    expect(ServidorVideoCaido.hostDe(null), isNull);
  });

  group('tutorial guiado', () {
    late GlobalKey objetivo;
    late int tocado;
    late List<bool> terminado;

    Widget pantalla() => Builder(builder: (context) {
          return Column(children: [
            const SizedBox(height: 120),
            Center(
              child: ElevatedButton(
                key: objetivo,
                onPressed: () => tocado++,
                child: const Text('Agregar cámara'),
              ),
            ),
            const SizedBox(height: 40),
            TextButton(onPressed: () => tocado += 100, child: const Text('Otra cosa')),
            const Spacer(),
            ElevatedButton(
              onPressed: () => TutorialGuiado.mostrar(context, [
                PasoTutorial(objetivo: () => TutorialGuiado.rectDe(objetivo), titulo: 'Paso uno', texto: 'Mira'),
                PasoTutorial(objetivo: () => null, titulo: 'Invisible', texto: 'Se salta'),
                PasoTutorial(
                    objetivo: () => TutorialGuiado.rectDe(objetivo),
                    titulo: 'Paso final',
                    texto: 'Toca',
                    tocarParaSeguir: true),
              ], alTerminar: terminado.add),
              child: const Text('Empezar'),
            ),
          ]);
        });

    setUp(() {
      objetivo = GlobalKey();
      tocado = 0;
      terminado = [];
    });

    testWidgets('bloquea lo de fuera, avanza y el último paso deja tocar de verdad', (tester) async {
      await tester.pumpWidget(_app(pantalla()));
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.text('Paso uno'), findsOneWidget);
      expect(find.text('2/2'), findsNothing);   // el paso invisible no cuenta
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.text('Otra cosa'), warnIfMissed: false);
      await tester.pump();
      expect(tocado, 0, reason: 'fuera del resaltado no se puede tocar');

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Paso final'), findsOneWidget);

      await tester.tap(find.text('Agregar cámara'));
      await tester.pumpAndSettle();
      expect(tocado, 1, reason: 'el toque llega al botón resaltado');
      expect(terminado, [true]);
      expect(find.text('Paso final'), findsNothing);
    });

    testWidgets('saltar pide confirmación y recomienda seguirlo', (tester) async {
      await tester.pumpWidget(_app(pantalla()));
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saltar tutorial'));
      await tester.pumpAndSettle();
      expect(find.text('¿Saltar el tutorial?'), findsOneWidget);
      await tester.tap(find.text('Seguir el tutorial'));
      await tester.pumpAndSettle();
      expect(find.text('Paso uno'), findsOneWidget);
      expect(terminado, isEmpty);

      await tester.tap(find.text('Saltar tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saltar tutorial').last);
      await tester.pumpAndSettle();
      expect(terminado, [false]);
      expect(find.text('Paso uno'), findsNothing);
    });
  });
}
