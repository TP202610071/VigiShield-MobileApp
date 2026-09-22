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
  String? _activeCameraId;
  int _requestVersion = 0;

  List<SecurityEventModel> get events => _events;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _page < _totalPages;
  String? get activeFilter => _activeFilter;
  String? get activeCameraId => _activeCameraId;

  /// [refresh] reinicia la paginación y FIJA los filtros a lo recibido: un
  /// `refresh: true` sin filtros los limpia. Para cambiar uno conservando el
  /// otro hay que volver a pasar el que se mantiene (el historial lo hace así).
  /// Sin [refresh] se conservan los filtros vigentes — es el caso de loadMore.
  Future<void> fetchEvents({
    String? type,
    String? cameraId,
    bool refresh = false,
  }) async {
    final requestVersion = ++_requestVersion;
    if (refresh) {
      _page = 1;
      _events = [];
      _activeFilter = type;
      _activeCameraId = cameraId;
    }

    if (_page == 1) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _service.getEvents(
          type: _activeFilter, cameraId: _activeCameraId, page: _page);
      if (requestVersion != _requestVersion) return;
      if (_page == 1) {
        _events = result.items;
      } else {
        _events = [..._events, ...result.items];
      }
      _totalPages = result.totalPages;
      _error = null;
    } on ApiException catch (e) {
      if (requestVersion != _requestVersion) return;
      _error = e.message;
      // Si falló al traer una página siguiente, devolvemos el contador: de lo
      // contrario el reintento saltaría esa página y se perderían eventos.
      if (_page > 1) _page--;
    } finally {
      if (requestVersion == _requestVersion) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Refresco en segundo plano: no limpia la lista ni activa [isLoading], para
  /// que el sondeo periódico de la pantalla de cámara actualice el panel en su
  /// sitio en vez de mostrar el esqueleto de carga cada pocos segundos.
  ///
  /// Si el usuario ya cargó más páginas, NO se reemplaza la lista: antes esto
  /// la recortaba a la primera página y, estando en el historial desplazado, la
  /// lista se encogía de golpe y el scroll saltaba hacia atrás. Ahora solo se
  /// anteponen los eventos que aún no teníamos.
  Future<void> refreshSilently() async {
    if (_isLoadingMore) return; // no pisar una carga de página en curso
    final requestVersion = _requestVersion;
    try {
      final result = await _service.getEvents(
          type: _activeFilter, cameraId: _activeCameraId, page: 1);
      // Una respuesta anterior no pertenece a los filtros/página actuales.
      if (requestVersion != _requestVersion) return;
      if (_page == 1) {
        _events = result.items;
        _totalPages = result.totalPages;
      } else {
        final conocidos = _events.map((e) => e.id).toSet();
        final nuevos =
            result.items.where((e) => !conocidos.contains(e.id)).toList();
        if (nuevos.isEmpty) return;
        _events = [...nuevos, ..._events];
      }
      _error = null;
      notifyListeners();
    } on ApiException {
      // Keep the current list on a transient failure — never blank the UI.
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
