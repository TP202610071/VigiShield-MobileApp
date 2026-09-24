import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/providers/event_provider.dart';
import 'package:vigishield_mobile_app/providers/ui_provider.dart';
import 'package:vigishield_mobile_app/screens/camera/camera_screen.dart';

import '../support/event_fakes.dart';

class _Cameras extends CameraProvider {
  _Cameras(super.service);

  @override
  Future<void> fetchCameras() async {}
}

void main() {
  testWidgets('camera polling stops on hidden branch and resumes on return', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final token = Completer<String?>();
    final messenger = tester.binding.defaultBinaryMessenger;
    // Keep stream authentication pending: this test exercises the real screen's
    // event polling lifecycle, not native media playback or platform storage.
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) => token.future,
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    final service = FakeEventService();
    service.replies.addAll(List.generate(10, (_) => () => page([])));
    final events = EventProvider(service);
    final storage = AuthStorage();
    final router = GoRouter(initialLocation: '/camera', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const SizedBox()),
          ]),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    addTearDown(events.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: events),
        ChangeNotifierProvider<CameraProvider>(create: (_) => _Cameras(CameraDataService(ApiClient(storage)))),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.en)),
        ChangeNotifierProvider(create: (_) => UiProvider()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(seconds: 15));
    expect(service.requests.length, 1);
    router.go('/history');
    await tester.pump();
    await tester.pump(const Duration(seconds: 45));
    final hiddenCalls = service.requests.length;
    router.go('/camera');
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    final returnCalls = service.requests.length;
    await tester.pumpWidget(const SizedBox());
    token.complete(null);
    await tester.pump();
    expect(hiddenCalls, 1, reason: 'a mounted but hidden camera must not poll events');
    expect(returnCalls, 2, reason: 'exactly one polling timer restarts on return');
  });
}
