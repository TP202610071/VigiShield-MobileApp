import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/models/camera_config_model.dart';
import '../data/models/security_event_model.dart';
import '../data/services/validation_platform.dart';
import 'session_scoped.dart';
import 'validation_alarm.dart';

class ValidationEventCache {
  ValidationEventCache({this.capacity = 512});
  final int capacity;
  final _ids = <String>{};
  int get length => _ids.length;
  bool accept(String id, double created, double started) {
    if (created < started || !_ids.add(id)) return false;
    while (_ids.length > capacity) { _ids.remove(_ids.first); }
    return true;
  }
  void clear() => _ids.clear();
}

/// Independent foreground monitor. Never reads/writes the history provider.
class ValidationProvider extends ChangeNotifier with WidgetsBindingObserver implements SessionScoped {
  ValidationProvider({required this.platform, required this.canMonitor,
    required this.loadPaused, required this.loadCameras, required this.loadEvents,
    required this.loadStatus, this.eventEnabled}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final ValidationPlatform platform;
  final bool Function() canMonitor;
  final Future<bool> Function() loadPaused;
  final Future<List<CameraConfigModel>> Function() loadCameras;
  final Future<List<SecurityEventModel>> Function(DateTime) loadEvents;
  final Future<Map<String, dynamic>> Function(CameraConfigModel) loadStatus;
  final bool Function(SecurityEventModel)? eventEnabled;
  bool active = false, recording = false, busy = false, alarmOptIn = false, callOptIn = false;
  /// Grabación continua en curso (del botón de grabar al de detener).
  bool grabandoSesion = false;
  bool _foreground = true, _disposed = false, _polling = false, _effects = false;
  int _generation = 0;
  int sustainSeconds = 30, countdownSeconds = 30;
  DateTime? _started;
  String? error, banner;
  DateTime? bannerArrival;
  List<Map<String, dynamic>> clips = [];
  List<CameraConfigModel> _cameras = [];
  final _alarms = <String, ValidationAlarm>{};
  final _events = ValidationEventCache();
  Timer? _pollTimer, _clock;
  Future<void> _hardwareQueue = Future.value();
  double get _now => DateTime.now().millisecondsSinceEpoch / 1000;
  bool _valid(int g) => !_disposed && g == _generation && _foreground && canMonitor();
  bool get counting => active && _alarms.values.any((a) => a.counting);
  int get remaining => _alarms.values.where((a) => a.counting).map((a) => a.remaining(_now)).fold(countdownSeconds, (a,b) => a < b ? a : b);
  void _notify() { if (!_disposed) notifyListeners(); }

  // Serialize hardware transitions so an old arm/start can never land after stop.
  Future<void> _hardware(Future<void> Function() action) {
    _hardwareQueue = _hardwareQueue.then((_) => action()).catchError((Object e) {
      error = e.toString(); _notify();
    });
    return _hardwareQueue;
  }
  Future<void> start() async {
    if (busy || active || !_foreground || !canMonitor()) return;
    final g = ++_generation;
    busy = true; error = null; _notify();
    try {
      if (await loadPaused()) throw StateError('Monitoreo del servidor pausado.');
      if (!_valid(g)) return;
      final cams = await loadCameras();
      if (!_valid(g)) return;
      _cameras = cams;
      _started = DateTime.now().toUtc();
      active = true;
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => poll());
      _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      unawaited(poll());
    } catch (e) { if (_valid(g)) error = e.toString(); }
    finally { if (g == _generation) { busy = false; _notify(); } }
  }

  Future<void> poll() async {
    if (!active || _polling) return;
    _polling = true;
    final g = _generation;
    try {
      if (await loadPaused()) { if (_valid(g)) stop(); return; }
      if (!_valid(g) || !active) return;
      final cams = await loadCameras();
      if (!_valid(g) || !active) return;
      updateCameras(cams);
      await Future.wait([
        for (final cam in cams.where((c) => c.isConfigured && c.notificationsEnabled && c.hlsViewUrl != null))
          _pollCamera(cam, g),
        _pollEvents(g),
      ]);
    } catch (e) {
      if (_valid(g)) { error = 'Monitoreo no disponible: $e'; cancelAlarm(); }
    } finally { _polling = false; _notify(); }
  }
  Future<void> _pollCamera(CameraConfigModel cam, int g) async {
    try {
      final s = await loadStatus(cam);
      if (!_valid(g) || !active || !alarmOptIn || !_permitted(cam.id)) return;
      final a = _alarms.putIfAbsent(cam.id, () => ValidationAlarm(sustainSeconds: sustainSeconds, countdownSeconds: countdownSeconds));
      final ts = s['ts'];
      final state = (s['intent'] is Map) ? (s['intent'] as Map)['state'] : null;
      if (s['state'] != 'ok' || ts is! num || !ts.isFinite || _now - ts > 5 || ts > _now + 2 || !['calm','watch','suspect','high_risk'].contains(state)) { a.missing(); _disarmCall(); return; }
      // caiee.py S_SUSPECT / S_HIGH; activity/event history is not persistence.
      final risky = s['persons'] is num && (s['persons'] as num) > 0 && (state == 'suspect' || state == 'high_risk');
      a.sample(now: _now, timestamp: ts.toDouble(), risky: risky);
      if (!risky) _disarmCall();
    } catch (_) { if (_valid(g)) { _alarms[cam.id]?.missing(); _disarmCall(); } }
    finally { if (_valid(g)) _tick(); }
  }
  bool _permitted(String? id) => id != null && _cameras.any((c) => c.id == id && c.isConfigured && c.notificationsEnabled);
  void updateCameras(List<CameraConfigModel> cameras) {
    _cameras = cameras;
    var muted = false;
    for (final entry in _alarms.entries) {
      if (!_permitted(entry.key)) { entry.value.cancel(); muted = true; }
    }
    if (muted) { cancelAlarm(); banner = null; }
  }
  Future<void> _pollEvents(int g) async {
    final events = await loadEvents(_started!);
    if (!_valid(g) || !active) return;
    for (final event in events.reversed) {
      if (!_events.accept(event.id, event.createdAt.millisecondsSinceEpoch / 1000, _started!.millisecondsSinceEpoch / 1000)) continue;
      if (!event.notificationsEnabled || !_permitted(event.cameraId) || !(eventEnabled?.call(event) ?? true)) continue;
      final arrival = DateTime.now().toUtc();
      bannerArrival = arrival;
      banner = '${event.cameraName ?? 'Cámara'}: ${event.eventType} — recibido ${arrival.toLocal()}';
      if (recording) {
        await _hardware(() async {
          if (_valid(g) && active && recording) await platform.invoke('markScreenEvent', {'eventId': 'arrival:${event.id}:${arrival.toIso8601String()}'});
        });
      }
    }
    _notify();
  }
  void _tick() {
    if (!active || !_foreground || !canMonitor()) { if (active) stop(); return; }
    var call = false;
    for (final a in _alarms.values) { if (a.tick(_now, armed: callOptIn && alarmOptIn)) call = true; }
    if (call) {
      final g = _generation;
      callOptIn = false; // consume BEFORE any asynchronous operation
      unawaited(_hardware(() async {
        if (!_valid(g) || !active || !alarmOptIn) return;
        await platform.invoke('placeTestCall');
        await platform.invoke('setTestCallArmed', {'enabled': false});
      }));
    }
    final effects = counting && alarmOptIn;
    if (effects != _effects) {
      _effects = effects;
      final g = _generation;
      unawaited(_hardware(() async {
        if (effects && (!_valid(g) || !counting)) return;
        if (platform.supported) await platform.invoke(effects ? 'startTestAlarm' : 'stopTestAlarm');
        if (!effects && platform.supported) await platform.invoke('setTestCallArmed', {'enabled': false});
      }));
      if (!effects) callOptIn = false;
    }
    if (bannerArrival != null && DateTime.now().difference(bannerArrival!) > const Duration(seconds: 8)) banner = null;
    _notify();
  }
  void configure({required int sustain, required int countdown}) {
    if (active) return;
    sustainSeconds = sustain.clamp(30, 300); countdownSeconds = 30; _notify();
  }
  void setAlarm(bool value) { cancelAlarm(); alarmOptIn = value && active; _notify(); }
  /// Sube en cada [cancelAlarm]. Armar la llamada de prueba espera al permiso
  /// del sistema, y durante esa espera el usuario puede cancelar: sin este
  /// contador, el permiso concedido después la armaba igualmente. `_generation`
  /// no sirve aquí porque es de la sesión entera y cancelar la alarma no la
  /// termina.
  int _armado = 0;

  Future<void> setCallOptIn(bool value) async {
    cancelAlarm();
    if (!value || !active || !alarmOptIn || !platform.supported) return;
    final g = _generation;
    final a = _armado;
    bool vigente() => _valid(g) && a == _armado && active && alarmOptIn;
    await _hardware(() async {
      final allowed = await platform.invoke('requestTestCallPermission');
      if (allowed != true || !vigente()) return;
      await platform.invoke('setTestCallArmed', {'enabled': true});
      if (vigente()) callOptIn = true;
    });
    _notify();
  }
  void _disarmCall() {
    if (!callOptIn) return;
    callOptIn = false;
    unawaited(_hardware(() async { if (platform.supported) await platform.invoke('setTestCallArmed', {'enabled': false}); }));
  }
  void cancelAlarm() {
    for (final a in _alarms.values) { a.cancel(); }
    // Invalida un armado en vuelo: si el permiso llega después de cancelar,
    // no debe encender nada.
    _armado++;
    callOptIn = false; _effects = false;
    unawaited(_hardware(() async {
      if (!platform.supported) return;
      await platform.invoke('setTestCallArmed', {'enabled': false});
      await platform.invoke('stopTestAlarm');
    }));
    _notify();
  }
  /// Empieza o termina la grabación continua de la pantalla.
  ///
  /// A diferencia de los clips por evento —que guardan 10 s antes y 10 s
  /// después de cada alerta— esta graba todo seguido, que es lo que sirve como
  /// evidencia de una sesión de validación completa.
  ///
  /// Requiere que el búfer de pantalla ya esté activo: ahí es donde el sistema
  /// pidió el consentimiento de captura.
  Future<void> grabarSesion(bool value) async {
    if (!platform.supported) {
      error = 'La grabación dentro de la app solo funciona en Android. '
          'En iPhone usa la grabación de pantalla del sistema.';
      _notify();
      return;
    }
    if (!recording) {
      error = 'Activa primero "Grabar pantalla con consentimiento".';
      _notify();
      return;
    }
    if (busy) return;
    final g = _generation;
    busy = true; _notify();
    await _hardware(() async {
      if (!_valid(g) || !active) return;
      if (value) {
        final r = await platform.invoke('startScreenRecording',
            {'eventId': 'sesion:${DateTime.now().toUtc().toIso8601String()}'});
        grabandoSesion = r is Map;
        if (!grabandoSesion) error = 'No se pudo iniciar la grabación.';
      } else {
        await platform.invoke('stopScreenRecording');
        grabandoSesion = false;
        await refreshClips();
      }
    });
    busy = false; _notify();
  }

  Future<void> setRecording(bool value) async {
    if (!platform.supported) { error = 'Grabación y llamadas no compatibles: requiere Android.'; _notify(); return; }
    if (value && (!active || busy)) return;
    final g = _generation;
    busy = true; _notify();
    await _hardware(() async {
      if (value && (!_valid(g) || !active)) return;
      final result = await platform.invoke(value ? 'startScreenBuffer' : 'stopScreenBuffer');
      if (value && (!_valid(g) || !active)) { await platform.invoke('stopScreenBuffer'); return; }
      recording = value && (result == true || result is Map && result['running'] == true);
      // Sin bufer no hay grabacion posible: el estado no puede quedarse en si.
      if (!recording) grabandoSesion = false;
      if (value && !recording) error = 'No se inició la grabación; permiso denegado o servicio no disponible.';
    });
    busy = false; _notify();
  }
  Future<void> manualMarker() async {
    if (!recording || !active) return;
    final g = _generation;
    await _hardware(() async { if (_valid(g) && recording) await platform.invoke('markScreenEvent', {'eventId': 'test-manual-arrival:${DateTime.now().toUtc().toIso8601String()}'}); });
  }
  Future<void> refreshClips() async {
    if (!platform.supported) return;
    await _hardware(() async {
      final result = await platform.invoke('listScreenClips');
      if (result is List) clips = result.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
    }); _notify();
  }
  Future<void> deleteClip(String path) async {
    await _hardware(() async { await platform.invoke('deleteScreenClip', {'path': path}); });
    await refreshClips();
  }
  void stop() {
    ++_generation; active = false; busy = false; alarmOptIn = false;
    _pollTimer?.cancel(); _clock?.cancel(); cancelAlarm();
    recording = false; banner = null; _alarms.clear(); _events.clear();
    unawaited(_hardware(() async { if (platform.supported) await platform.invoke('stopScreenBuffer'); }));
    _notify();
  }
  @override void clearSession() { stop(); clips = []; error = null; }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Android consent temporarily inactivates the app. It is safe to cancel
    // monitoring; the user must explicitly restart after returning.
    if (state == AppLifecycleState.inactive && busy) { cancelAlarm(); return; }
    if (!_foreground) stop();
  }
  @override void dispose() {
    stop(); _disposed = true;
    WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
}
