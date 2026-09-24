import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:vigishield_mobile_app/core/i18n/app_localizations.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/core/storage/auth_storage.dart';
import 'package:vigishield_mobile_app/data/services/camera_service.dart';
import 'package:vigishield_mobile_app/providers/camera_provider.dart';
import 'package:vigishield_mobile_app/providers/event_provider.dart';
import 'package:vigishield_mobile_app/providers/server_config_provider.dart';
import 'package:vigishield_mobile_app/screens/history/history_screen.dart';

import '../support/event_fakes.dart';

class _Cameras extends CameraProvider {
  _Cameras(super.service);

  @override
  Future<void> fetchCameras() async {}
}

void main() {
  // EventCard formatea fechas con intl: sin los datos de localización cargados
  // lanza LocaleDataException al montarse.
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<EventProvider> mountHistory(
    WidgetTester tester, FakeEventService service,
  ) async {
    final provider = EventProvider(service);
    final storage = AuthStorage();
    final client = ApiClient(storage);
    addTearDown(provider.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider<CameraProvider>(create: (_) => _Cameras(CameraDataService(client))),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage, AppLocale.en)),
        ChangeNotifierProvider(create: (_) => ServerConfigProvider(storage, client, 'http://localhost')),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await tester.pump();
    return provider;
  }

  testWidgets('history pull to refresh preserves type and camera filters', (tester) async {
    final service = FakeEventService();
    service.replies.addAll([
      () => page(['initial']),
      () => page(['filtered']),
      () => page(['updated']),
    ]);
    final provider = await mountHistory(tester, service);
    await provider.fetchEvents(refresh: true, type: 'UnknownFace', cameraId: 'camera-a');
    await tester.pump();
    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    expect(provider.activeFilter, 'UnknownFace');
    expect(provider.activeCameraId, 'camera-a');
    expect(service.requests.last.type, 'UnknownFace');
    expect(service.requests.last.cameraId, 'camera-a');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('retrying a filtered first page preserves both filters', (tester) async {
    final service = FakeEventService();
    service.replies.addAll([
      () => page(['initial']),
      () => throw ApiException('offline'),
      () => page(['filtered']),
    ]);
    final provider = await mountHistory(tester, service);
    await provider.fetchEvents(refresh: true, type: 'UnknownFace', cameraId: 'camera-a');
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.requests.last.type, 'UnknownFace');
    expect(service.requests.last.cameraId, 'camera-a');
    expect(provider.activeFilter, 'UnknownFace');
    expect(provider.activeCameraId, 'camera-a');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pagination failure keeps the scrolled list mounted', (tester) async {
    final service = FakeEventService();
    service.replies.addAll([
      () => page(List.generate(20, (i) => 'event-$i')),
      () => throw ApiException('offline'),
      () => page(['older'], number: 2),
    ]);
    final provider = await mountHistory(tester, service);
    final list = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical);
    final controller = tester.widget<ListView>(list).controller!;
    controller.jumpTo(400);
    await tester.pump();
    final offset = controller.offset;
    await provider.loadMore();
    await tester.pump();
    expect(list, findsOneWidget);
    expect(controller.offset, offset);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(service.requests.map((r) => r.page), [1, 2, 2]);
    expect(controller.offset, offset);
    expect(provider.error, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('silent refresh does not shrink scrolled paginated history', (tester) async {
    final service = FakeEventService();
    final first = List.generate(20, (i) => 'event-$i');
    final second = List.generate(20, (i) => 'older-$i');
    service.replies.addAll([
      () => page(first, pages: 2),
      () => page(second, number: 2, pages: 2),
      () => page(['new', ...first.take(19)], pages: 2),
    ]);
    final provider = await mountHistory(tester, service);
    await provider.loadMore();
    await tester.pump();
    final list = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical);
    final controller = tester.widget<ListView>(list).controller!;
    controller.jumpTo(1800);
    await tester.pump();
    final offset = controller.offset;
    await provider.refreshSilently();
    await tester.pump();
    expect(provider.events.length, 41);
    expect(controller.offset, offset);
    expect(controller.offset, greaterThan(0));
    expect(service.requests.map((r) => r.page), [1, 2, 1]);
    await tester.pumpWidget(const SizedBox());
  });
}
