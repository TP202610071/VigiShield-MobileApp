import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/core/theme/app_theme.dart';
import 'package:vigishield_mobile_app/core/theme/tema_provider.dart';
import 'package:vigishield_mobile_app/data/models/camera_config_model.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/widgets/animaciones.dart';
import 'package:vigishield_mobile_app/widgets/selector_tema.dart';
import 'package:vigishield_mobile_app/widgets/tutorial/demo_zonas.dart';
import 'package:vigishield_mobile_app/widgets/tutorial/tutorial_camara.dart';
import 'package:vigishield_mobile_app/widgets/vs_cargando.dart';

class _Auth extends AuthProvider {
  _Auth() : super(AuthService(ApiClient(AuthStorage())), AuthStorage());
  @override
  UserModel get user =>
      UserModel(id: 'u1', email: 'x', name: 'Ana', role: 'Primary', householdId: 'h', createdAt: DateTime(2026));
}

class _Camaras extends CameraProvider {
  _Camaras(this.lista) : super(CameraDataService(ApiClient(AuthStorage())));
  final List<CameraConfigModel> lista;
  @override
  Future<void> fetchCameras() async {}
  @override
  List<CameraConfigModel> get cameras => lista;
}

Widget _app(Widget hijo, {List<CameraConfigModel> camaras = const [], TemaProvider? tema}) {
  final storage = AuthStorage();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.es)),
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider<CameraProvider>(create: (_) => _Camaras(camaras)),
      if (tema != null) ChangeNotifierProvider.value(value: tema),
    ],
    child: MaterialApp(home: Scaffold(body: hijo)),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });
  // La paleta es global: cada prueba la deja en el oscuro de siempre.
  tearDown(() => AppColors.usarModoClaro(false));

  group('modo claro', () {
    test('la paleta cambia de modo y el oscuro es el de siempre', () {
      expect(AppColors.esClaro, isFalse);
      expect(AppColors.background, const Color(0xFF0A0F1E));
      expect(AppColors.onAccent, Colors.black);
      AppColors.usarModoClaro(true);
      expect(AppColors.esClaro, isTrue);
      expect(AppColors.background, const Color(0xFFF2F4F7));
      expect(AppColors.textPrimary, isNot(Colors.white));
      expect(AppColors.onAccent, Colors.white);
      expect(AppTheme.barraDeEstado.statusBarIconBrightness, Brightness.dark);
      // La pestaña Cámara usa la paleta fija, que no cambia con el modo.
      expect(AppColorsOscuros.background, const Color(0xFF0A0F1E));
    });

    testWidgets('elegir «Claro» en Ajustes cambia la paleta y se guarda', (tester) async {
      final tema = TemaProvider(AuthStorage(), ModoTema.oscuro);
      await tester.pumpWidget(_app(const SelectorTema(), tema: tema));
      expect(find.text('Oscuro'), findsOneWidget);
      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(tema.modo, ModoTema.claro);
      expect(AppColors.esClaro, isTrue);
      expect(await TemaProvider.cargar(AuthStorage()), ModoTema.claro);
      tema.dispose();
    });

    test('sin nada guardado, arranca en oscuro', () async {
      expect(await TemaProvider.cargar(AuthStorage()), ModoTema.oscuro);
    });
  });

  testWidgets('el indicador de carga se adapta a su tamaño', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [
      SizedBox(width: 16, height: 16, child: VsCargando()),
      VsCargando(),
    ])));
    await tester.pump(const Duration(milliseconds: 500));
    final tamanos = tester.widgetList<SizedBox>(find.descendant(
        of: find.byType(VsCargando), matching: find.byType(SizedBox))).map((s) => s.width).toList();
    expect(tamanos, containsAll([16.0, VsCargando.tamanoPorDefecto]));
  });

  testWidgets('las listas entran escalonadas y terminan visibles', (tester) async {
    await tester.pumpWidget(_app(Column(children: [
      for (var i = 0; i < 3; i++) Aparecer(orden: i, child: Text('fila $i')),
    ])));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.text('fila $i'), findsOneWidget);
    }
    expect(find.byType(Opacity), findsNothing, reason: 'al terminar no queda ninguna capa de opacidad');
  });

  testWidgets('el ejemplo de zonas avanza por sus pasos', (tester) async {
    await tester.pumpWidget(_app(const DemoZonas()));
    expect(find.text('1. Toca las esquinas'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 5000));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('3. Elige su tipo'), findsOneWidget);
  });

  group('tutorial de la primera cámara', () {
    Widget pantalla() => Builder(
          builder: (context) => Column(children: [
            TextField(key: TutorialCamaraClaves.nombreIp),
            SizedBox(key: TutorialCamaraClaves.escanear, height: 40, width: 200),
            TextField(key: TutorialCamaraClaves.ip),
            ElevatedButton(
              onPressed: () => TutorialPrimeraCamara.camaraIp(context),
              child: const Text('abrir'),
            ),
          ]),
        );

    testWidgets('sale con la primera cámara y una sola vez', (tester) async {
      await tester.pumpWidget(_app(pantalla()));
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsOneWidget);
      await tester.tap(find.text('Saltar tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saltar tutorial').last);
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsNothing);

      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsNothing, reason: 'ya se vio');
    });

    testWidgets('no sale si ya hay cámaras, salvo que se pida desde Ajustes', (tester) async {
      final cam = CameraConfigModel.fromJson({'id': 'c1', 'name': 'Puerta', 'streamMode': 'DirectRtsp'});
      await tester.pumpWidget(_app(pantalla(), camaras: [cam]));
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsNothing);

      await TutorialPrimeraCamara.olvidar('u1');
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Ponle un nombre'), findsOneWidget);
    });
  });
}
