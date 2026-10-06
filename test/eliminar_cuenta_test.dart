import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/user_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/providers/server_config_provider.dart';
import 'package:vigishield_mobile_app/providers/session_scoped.dart';
import 'package:vigishield_mobile_app/screens/settings/profile_screen.dart';

class _Servicio extends AuthService {
  _Servicio() : super(ApiClient(AuthStorage()));
  final borradas = <String>[];

  @override
  Future<({String token, UserModel user})> login(String email, String password) async => (
        token: 't',
        user: UserModel(id: 'u', email: email, name: 'Ana', role: 'Primary', householdId: 'h', createdAt: DateTime(2026)),
      );

  @override
  Future<bool> deleteAccount(String password) async {
    if (password != 'Clave.2026') throw const ApiException('La contraseña no es correcta.', 400);
    borradas.add(password);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('con la contraseña correcta se borra la cuenta y se cierra la sesión', () async {
    final servicio = _Servicio();
    final auth = AuthProvider(servicio, AuthStorage());
    var limpiado = false;
    auth.registerSessionScoped([_Limpieza(() => limpiado = true)]);
    await auth.login('ana@x.com', 'Clave.2026');
    expect(auth.isAuthenticated, isTrue);

    expect(await auth.deleteAccount('Clave.2026'), isTrue);

    expect(servicio.borradas, ['Clave.2026']);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.user, isNull);
    expect(limpiado, isTrue);
  });

  testWidgets('Perfil: explica qué se borra, pide la contraseña y elimina', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final servicio = _Servicio();
    final storage = AuthStorage();
    final auth = AuthProvider(servicio, storage);
    await auth.login('ana@x.com', 'Clave.2026');
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => ServerConfigProvider(storage, ApiClient(storage), 'http://localhost')),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.es)),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('eliminar-cuenta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eliminar-cuenta')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se borrará para siempre tu hogar'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('clave-eliminar')), 'otra');
    await tester.tap(find.byKey(const Key('confirmar-eliminar')));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña no es correcta.'), findsOneWidget);
    expect(auth.isAuthenticated, isTrue);

    await tester.enterText(find.byKey(const Key('clave-eliminar')), 'Clave.2026');
    await tester.tap(find.byKey(const Key('confirmar-eliminar')));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Tu cuenta fue eliminada.'), findsOneWidget);
  });

  test('con la contraseña equivocada no cambia nada y explica el motivo', () async {
    final auth = AuthProvider(_Servicio(), AuthStorage());
    await auth.login('ana@x.com', 'Clave.2026');

    expect(await auth.deleteAccount('otra'), isFalse);

    expect(auth.isAuthenticated, isTrue);
    expect(auth.errorMessage, 'La contraseña no es correcta.');
  });
}

class _Limpieza extends ChangeNotifier implements SessionScoped {
  _Limpieza(this.alLimpiar);
  final void Function() alLimpiar;
  @override
  void clearSession() => alLimpiar();
}
