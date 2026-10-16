import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/data/services/notificaciones_push.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/providers/dev_settings_provider.dart';
import 'package:vigishield_mobile_app/screens/settings/elegir_camara_screen.dart';
import 'package:vigishield_mobile_app/widgets/inicio_camaras.dart';
import 'package:vigishield_mobile_app/widgets/login_externo.dart';

class _Auth extends AuthProvider {
  _Auth() : super(AuthService(ApiClient(AuthStorage())), AuthStorage());
  @override
  UserModel get user =>
      UserModel(id: 'u1', email: 'x', name: 'Ana', role: 'Primary', householdId: 'h', createdAt: DateTime(2026));
}

class _SinCamaras extends CameraProvider {
  _SinCamaras() : super(CameraDataService(ApiClient(AuthStorage())));
  @override
  Future<void> fetchCameras() async {}
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('a dónde lleva una notificación', () {
    test('un evento abre su detalle', () {
      expect(NotificacionesPush.rutaDeDestino('3f2a1b6c-1d2e-4f5a-9b8c-7d6e5f4a3b2c'),
          '/history/3f2a1b6c-1d2e-4f5a-9b8c-7d6e5f4a3b2c');
    });
    test('los avisos del panel abren una pestaña permitida', () {
      expect(NotificacionesPush.rutaDeDestino('/history'), '/history');
      expect(NotificacionesPush.rutaDeDestino('/settings'), '/settings');
    });
    test('cualquier otra cosa se ignora', () {
      expect(NotificacionesPush.rutaDeDestino('/settings/developer'), isNull);
      expect(NotificacionesPush.rutaDeDestino('https://otro.sitio'), isNull);
      expect(NotificacionesPush.rutaDeDestino('hola'), isNull);
    });
  });

  testWidgets('«Continuar con Apple» usa la misma letra que «Iniciar sesión»', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LocaleProvider(AuthStorage(), AppLocale.es),
      child: MaterialApp(home: Scaffold(body: BotonApple(texto: 'Continuar con Apple', onPressed: () {}))),
    ));
    final texto = tester.widget<Text>(find.text('Continuar con Apple'));
    expect(texto.style?.fontSize, 15);
    expect(tester.getSize(find.byType(BotonApple)).height, 52);
  });

  testWidgets('«Agregar cámara» del inicio lleva a elegir el tipo de cámara', (tester) async {
    final storage = AuthStorage();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.es)),
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<CameraProvider>(create: (_) => _SinCamaras()),
        ChangeNotifierProvider(create: (_) => DevSettingsProvider(storage, null)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: TarjetaInicioCamaras())),
          GoRoute(path: ElegirCamaraScreen.ruta, builder: (_, __) => const ElegirCamaraScreen()),
          GoRoute(path: '/settings/cameras/add', builder: (_, __) => const Scaffold(body: Text('pantalla IP'))),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar cámara'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué cámara quieres agregar?'), findsOneWidget);
    expect(find.text('Cámara IP'), findsOneWidget);
    expect(find.text('Este celular como cámara'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opcion-camara-ip')));
    await tester.pumpAndSettle();
    expect(find.text('pantalla IP'), findsOneWidget);
  });
}
