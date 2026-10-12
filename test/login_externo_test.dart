import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/login_externo_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/widgets/login_externo.dart';

class _Servicio extends LoginExternoService {
  _Servicio({this.android, this.vinculada = false}) : super(ApiClient(AuthStorage()));
  final AppleAndroid? android;
  final bool vinculada;

  @override
  Future<AppleAndroid?> configAndroid() async => android;

  @override
  Future<({bool apple, bool google, bool tieneContrasena})> estado() async =>
      (apple: vinculada, google: false, tieneContrasena: !vinculada);
}

Widget _app(Widget hijo) {
  final storage = AuthStorage();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.es)),
      ChangeNotifierProvider(create: (_) => AuthProvider(AuthService(ApiClient(storage)), storage)),
    ],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final android = AppleAndroid('app.vigishield.signin', Uri.parse('https://api.vigishield.app/api/auth/apple/callback'));

  testWidgets('Google sale desactivado con «Próximamente» y no hace nada al tocarlo', (tester) async {
    await tester.pumpWidget(_app(BotonesLoginExterno(servicio: _Servicio())));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);
    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('en Android, Apple solo aparece si el backend tiene el Services ID', (tester) async {
    await tester.pumpWidget(_app(BotonesLoginExterno(servicio: _Servicio())));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Apple'), findsNothing);

    await tester.pumpWidget(_app(BotonesLoginExterno(key: UniqueKey(), servicio: _Servicio(android: android))));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con Apple'), findsOneWidget);
  });

  testWidgets('el borrado ofrece Apple solo a cuentas vinculadas', (tester) async {
    await tester.pumpWidget(_app(ConfirmarEliminarConApple(servicio: _Servicio(android: android))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar con Apple'), findsNothing);

    await tester.pumpWidget(_app(ConfirmarEliminarConApple(
        key: UniqueKey(), servicio: _Servicio(android: android, vinculada: true))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar con Apple'), findsOneWidget);
  });
}
