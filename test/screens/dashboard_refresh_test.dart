import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/models/system_status_model.dart';
import 'package:vigishield_mobile_app/data/services/auth_service.dart';
import 'package:vigishield_mobile_app/data/services/system_service.dart';
import 'package:vigishield_mobile_app/providers/auth_provider.dart';
import 'package:vigishield_mobile_app/providers/dev_settings_provider.dart';
import 'package:vigishield_mobile_app/providers/event_provider.dart';
import 'package:vigishield_mobile_app/providers/system_provider.dart';
import 'package:vigishield_mobile_app/providers/server_config_provider.dart';
import 'package:vigishield_mobile_app/screens/dashboard/dashboard_screen.dart';

import '../support/event_fakes.dart';

class _SystemService implements SystemService {
  int calls = 0;

  @override
  Future<SystemStatusModel> getStatus() async => SystemStatusModel(
    isMonitoringActive: true,
    eventsTodayCount: ++calls,
    streamUrl: '',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting());
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('returning to dashboard refreshes data without clearing filters',
      (tester) async {
    final service = FakeEventService();
    service.replies.addAll(List.generate(10, (_) => () => page([])));
    final events = EventProvider(service);
    final statusService = _SystemService();
    final storage = AuthStorage();
    final client = ApiClient(storage);
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
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
        ChangeNotifierProvider(create: (_) => SystemProvider(statusService)),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService(client), storage)),
        ChangeNotifierProvider(create: (_) => DevSettingsProvider(storage, null)),
        ChangeNotifierProvider(create: (_) => ServerConfigProvider(storage, client, 'http://localhost')),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.en)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final initialCalls = statusService.calls;
    router.go('/history');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await events.fetchEvents(refresh: true, type: 'UnknownFace', cameraId: 'camera-a');
    final historyCalls = service.requests.length;
    router.go('/dashboard');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(statusService.calls, initialCalls + 1);
    expect(service.requests.length, historyCalls + 1);
    expect(events.activeFilter, 'UnknownFace');
    expect(events.activeCameraId, 'camera-a');
    expect(service.requests.last.type, 'UnknownFace');
    expect(service.requests.last.cameraId, 'camera-a');
    await tester.pumpWidget(const SizedBox());
  });
}
