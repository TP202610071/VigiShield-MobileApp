import 'package:flutter/foundation.dart';
import '../data/models/security_event_model.dart';
import '../data/services/event_service.dart';
import '../core/network/api_client.dart';

class EventProvider extends ChangeNotifier {
  final EventService _service;

  EventProvider(this._service);

  List<SecurityEventModel> _events = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String? _activeFilter;

  List<SecurityEventModel> get events => _events;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _page < _totalPages;
  String? get activeFilter => _activeFilter;

  Future<void> fetchEvents({String? type, bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _events = [];
      _activeFilter = type;
    }

    if (_page == 1) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _service.getEvents(type: type ?? _activeFilter, page: _page);
      if (_page == 1) {
        _events = result.items;
      } else {
        _events = [..._events, ...result.items];
      }
      _totalPages = result.totalPages;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    _page++;
    notifyListeners();
    await fetchEvents();
  }

  Future<SecurityEventModel?> getById(String id) async {
    try {
      return await _service.getEventById(id);
    } on ApiException {
      return null;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _service.deleteEvent(id);
      _events.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Inserts a locally-generated event at the top of the list (demo / simulation).
  void injectSimulatedEvent(SecurityEventModel event) {
    _events = [event, ..._events];
    notifyListeners();
  }
}
