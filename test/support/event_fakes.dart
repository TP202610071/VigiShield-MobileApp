import 'dart:async';
import 'dart:collection';

import 'package:vigishield_mobile_app/data/models/security_event_model.dart';
import 'package:vigishield_mobile_app/data/services/event_service.dart';

class EventRequest {
  final String? type;
  final String? cameraId;
  final int page;

  EventRequest(this.type, this.cameraId, this.page);
}

class FakeEventService implements EventService {
  final requests = <EventRequest>[];
  final replies = Queue<FutureOr<EventListResult> Function()>();

  @override
  Future<EventListResult> getEvents({
    String? type,
    String? cameraId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    requests.add(EventRequest(type, cameraId, page));
    return replies.removeFirst()();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SecurityEventModel event(String id) => SecurityEventModel(
  id: id,
  householdId: 'household',
  cameraId: 'camera-a',
  eventType: 'UnknownFace',
  riskLevel: 'Low',
  isNighttime: false,
  createdAt: DateTime.utc(2026, 9, 21),
);

EventListResult page(List<String> ids, {int number = 1, int pages = 3}) =>
    EventListResult(
      items: ids.map(event).toList(),
      total: pages * 20,
      page: number,
      pageSize: 20,
      totalPages: pages,
    );
