import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigishield_mobile_app/core/network/api_client.dart';
import 'package:vigishield_mobile_app/data/models/security_event_model.dart';
import 'package:vigishield_mobile_app/providers/event_provider.dart';

import '../support/event_fakes.dart';

void main() {
  late FakeEventService service;
  late EventProvider provider;

  setUp(() {
    service = FakeEventService();
    provider = EventProvider(service);
  });
  tearDown(() => provider.dispose());

  test('silent refresh retains loaded pages and both active filters', () async {
    service.replies.addAll([
      () => page(['a', 'b']),
      () => page(['c', 'd'], number: 2),
      () => page(['new', 'a']),
      () => page(['e', 'f'], number: 3),
    ]);
    await provider.fetchEvents(
      refresh: true, type: 'UnknownFace', cameraId: 'camera-a',
    );
    await provider.loadMore();
    await provider.refreshSilently();
    expect(provider.events.map((e) => e.id), ['new', 'a', 'b', 'c', 'd']);
    expect(provider.isLoading, isFalse);
    await provider.loadMore();
    expect(service.requests.map((r) => r.page), [1, 2, 1, 3]);
    expect(service.requests.every((r) => r.type == 'UnknownFace'), isTrue);
    expect(service.requests.every((r) => r.cameraId == 'camera-a'), isTrue);
    expect(provider.hasMore, isFalse);
  });

  test('failed pagination retries the same page without losing events', () async {
    service.replies.addAll([
      () => page(['a', 'b']),
      () => throw ApiException('offline'),
      () => page(['c', 'd'], number: 2),
    ]);
    await provider.fetchEvents(refresh: true);
    await provider.loadMore();
    expect(provider.events.map((e) => e.id), ['a', 'b']);
    await provider.loadMore();
    expect(service.requests.map((r) => r.page), [1, 2, 2]);
    expect(provider.events.map((e) => e.id), ['a', 'b', 'c', 'd']);
    expect(provider.error, isNull);
  });

  test('old silent response cannot overwrite a newly selected filter', () async {
    final pending = Completer<EventListResult>();
    service.replies.addAll([
      () => page(['old']),
      () => pending.future,
      () => page(['filtered']),
    ]);
    await provider.fetchEvents(refresh: true);
    final oldRefresh = provider.refreshSilently();
    await provider.fetchEvents(
      refresh: true, type: 'UnknownFace', cameraId: 'camera-a',
    );
    pending.complete(page(['stale']));
    await oldRefresh;
    expect(provider.activeFilter, 'UnknownFace');
    expect(provider.activeCameraId, 'camera-a');
    expect(provider.events.map((e) => e.id), ['filtered']);
  });
}
