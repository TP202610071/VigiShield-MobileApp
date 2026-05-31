import '../models/security_event_model.dart';
import '../../core/network/api_client.dart';

class EventService {
  final ApiClient _client;

  EventService(this._client);

  Future<EventListResult> getEvents({
    String? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>('/api/events', queryParams: {
      if (type != null) 'type': type,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'page': page,
      'pageSize': pageSize,
    });
    return EventListResult.fromJson(data);
  }

  Future<SecurityEventModel> getEventById(String id) async {
    final data = await _client.get<Map<String, dynamic>>('/api/events/$id');
    return SecurityEventModel.fromJson(data);
  }

  Future<void> deleteEvent(String id) => _client.delete('/api/events/$id');
}
