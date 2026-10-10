import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/widgets/verificador_actualizacion.dart';

const _json = {
  'ios': {
    'minimo': 32,
    'ultimo': 34,
    'url': 'itms-beta://',
    'notas': {'es': 'Mejoras del tutorial.', 'en': 'Tutorial improvements.'},
  },
};

Widget _app({required int build, Object? datos = _json, bool aplica = true, List<int>? cargas, VoidCallback? alTocar}) {
  return ChangeNotifierProvider(
    create: (_) => LocaleProvider(AuthStorage(), AppLocale.es),
    child: MaterialApp(
      builder: (context, child) => VerificadorActualizacion(
        aplica: aplica,
        cargar: () async {
          cargas?.add(1);
          if (datos is Exception) throw datos;
          return datos;
        },
        buildInstalado: () async => build,
        child: child!,
      ),
      home: Scaffold(
        body: Center(child: ElevatedButton(onPressed: alTocar, child: const Text('Contenido'))),
      ),
    ),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('VersionPublicada', () {
    test('lee el archivo, también si llega como texto', () {
      final v = VersionPublicada.desdeJson('{"ios":{"minimo":"30","ultimo":33,"url":"itms-beta://"}}', 'ios')!;
      expect(v.minimo, 30);
      expect(v.ultimo, 33);
      expect(v.url, 'itms-beta://');
      expect(v.notas(false), '');
    });

    test('sin la plataforma o mal formado no pide nada', () {
      expect(VersionPublicada.desdeJson(_json, 'android'), isNull);
      expect(VersionPublicada.desdeJson('no es json', 'ios'), isNull);
      expect(VersionPublicada.desdeJson(null, 'ios'), isNull);
    });

    test('decide según el build instalado', () {
      final v = VersionPublicada.desdeJson(_json, 'ios')!;
      expect(v.para(31), TipoActualizacion.obligatoria);
      expect(v.para(32), TipoActualizacion.opcional);
      expect(v.para(33), TipoActualizacion.opcional);
      expect(v.para(34), TipoActualizacion.ninguna);
      expect(v.para(40), TipoActualizacion.ninguna);
      expect(v.para(0), TipoActualizacion.ninguna, reason: 'build desconocido: nunca bloquear');
    });

    test('las notas en inglés caen al español si faltan', () {
      final v = VersionPublicada.desdeJson({'ios': {'notas': {'es': 'Hola'}}}, 'ios')!;
      expect(v.notas(true), 'Hola');
    });
  });

  test('solo aplica en iOS', () {
    expect(VerificadorActualizacion.aplicaEnEstaPlataforma, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(VerificadorActualizacion.aplicaEnEstaPlataforma, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('build antiguo: pantalla que no deja usar la app', (tester) async {
    var tocado = 0;
    await tester.pumpWidget(_app(build: 31, alTocar: () => tocado++));
    await tester.pumpAndSettle();
    expect(find.text('Actualización necesaria'), findsOneWidget);
    expect(find.text('Mejoras del tutorial.'), findsOneWidget);
    expect(find.text('Ahora no'), findsNothing, reason: 'no se puede cerrar');
    await tester.tap(find.text('Contenido'), warnIfMissed: false);
    expect(tocado, 0, reason: 'la app queda tapada');
  });

  testWidgets('build compatible pero viejo: aviso que se puede cerrar', (tester) async {
    var tocado = 0;
    await tester.pumpWidget(_app(build: 33, alTocar: () => tocado++));
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva de VigiShield'), findsOneWidget);
    expect(find.text('Actualización necesaria'), findsNothing);
    await tester.tap(find.text('Contenido'));
    expect(tocado, 1, reason: 'el aviso no bloquea');
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva de VigiShield'), findsNothing);

    // Al volver a abrir la app no reaparece por el mismo build.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(build: 33));
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva de VigiShield'), findsNothing);
  });

  testWidgets('un aviso cerrado vuelve si sale otro build', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'actualizacion_descartada_ios': '33'});
    await tester.pumpWidget(_app(build: 33));
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva de VigiShield'), findsOneWidget);
  });

  testWidgets('al día: no muestra nada', (tester) async {
    await tester.pumpWidget(_app(build: 34));
    await tester.pumpAndSettle();
    expect(find.text('Hay una versión nueva de VigiShield'), findsNothing);
    expect(find.text('Actualización necesaria'), findsNothing);
  });

  testWidgets('sin red no bloquea', (tester) async {
    await tester.pumpWidget(_app(build: 20, datos: Exception('sin red')));
    await tester.pumpAndSettle();
    expect(find.text('Actualización necesaria'), findsNothing);
    expect(find.text('Contenido'), findsOneWidget);
  });

  testWidgets('fuera de iOS ni siquiera descarga el archivo', (tester) async {
    final cargas = <int>[];
    await tester.pumpWidget(_app(build: 20, aplica: false, cargas: cargas));
    await tester.pumpAndSettle();
    expect(cargas, isEmpty);
    expect(find.text('Actualización necesaria'), findsNothing);
  });
}
