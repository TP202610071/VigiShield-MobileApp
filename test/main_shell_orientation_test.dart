import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/orientation/orientacion_app.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/providers/ui_provider.dart';
import 'package:vigishield_mobile_app/screens/main_shell.dart';

/// Reproduce el caso de la grabación cortada: una pantalla abierta ENCIMA de la
/// pestaña Cámara (Mis cámaras, editor de zonas) giraba la app a horizontal
/// cada vez que las pestañas se redibujaban, por ejemplo al guardar.
void main() {
  final o = OrientacionApp.instance;

  setUp(() {
    o.reiniciarParaPruebas();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  testWidgets('la pestaña Cámara es horizontal solo cuando se ve', (tester) async {
    final ui = UiProvider();
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      GoRoute(path: '/encima', builder: (_, __) => const Scaffold(body: Text('encima'))),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          for (final r in ['/dashboard', '/camera', '/history', '/settings'])
            StatefulShellBranch(routes: [GoRoute(path: r, builder: (_, __) => Text(r))]),
        ],
      ),
    ]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: ui),
      ChangeNotifierProvider(create: (_) => LocaleProvider(AuthStorage(), AppLocale.es)),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(o.deseada(), [DeviceOrientation.portraitUp]);

    router.go('/camera');
    await tester.pumpAndSettle();
    expect(o.deseada(), [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    // Se abre una pantalla encima de la pestaña Cámara: vertical.
    router.push('/encima');
    await tester.pumpAndSettle();
    expect(o.deseada(), [DeviceOrientation.portraitUp]);

    // Las pestañas se redibujan (como al guardar zonas): sigue vertical.
    ui.setCameraFullscreen(true);
    await tester.pumpAndSettle();
    ui.setCameraFullscreen(false);
    await tester.pumpAndSettle();
    expect(o.deseada(), [DeviceOrientation.portraitUp]);

    // Al volver a la pestaña Cámara, horizontal otra vez.
    router.pop();
    await tester.pumpAndSettle();
    expect(o.deseada(), [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  });
}
