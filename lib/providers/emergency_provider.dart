import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models/camera_config_model.dart';
import '../data/models/emergency_settings.dart';
import '../data/services/emergency_effects.dart';
import 'session_scoped.dart';
import 'validation_alarm.dart';

/// Alerta de emergencia: si una cámara mantiene riesgo de intrusión, ocupa la
/// pantalla, suena y vibra; si nadie la desactiva a tiempo, llama al número
/// configurado.
///
/// Vigila mientras la app está abierta. Con la app cerrada no hay forma de
/// hacerlo desde el teléfono (iOS no deja ejecutar código en segundo plano
/// para esto): eso requiere notificaciones push desde el servidor.
class EmergencyProvider extends ChangeNotifier
    with WidgetsBindingObserver
    implements SessionScoped {
  EmergencyProvider({
    required this.readSettings,
    required this.writeSettings,
    required this.effects,
    required this.canMonitor,
    required this.loadCameras,
    required this.loadStatus,
    double Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch / 1000) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Future<String?> Function() readSettings;
  final Future<void> Function(String) writeSettings;
  final EmergencyEffects effects;
  final bool Function() canMonitor;
  final Future<List<CameraConfigModel>> Function() loadCameras;
  final Future<Map<String, dynamic>> Function(CameraConfigModel) loadStatus;

  EmergencySettings settings = const EmergencySettings();
  bool get monitoring => _poll != null;

  /// Cámara que disparó la alerta en curso (null en una prueba).
  String? cameraName;
  bool testing = false;

  /// Resultado de la última llamada, para mostrarlo en la pantalla de alerta.
  bool? lastCallPlaced;

  final _alarms = <String, ValidationAlarm>{};
  List<CameraConfigModel> _cameras = [];
  Timer? _poll, _ticker;
  double? _testDeadline;
  bool _foreground = true, _polling = false, _effectsOn = false, _disposed = false;
  int _generation = 0;

  final double Function() _clock;
  double get _now => _clock();

  bool get counting => testing || _alarms.values.any((a) => a.counting);

  int get remaining {
    if (testing) {
      return ((_testDeadline ?? _now) - _now).ceil().clamp(0, settings.countdownSeconds);
    }
    return _alarms.values
        .where((a) => a.counting)
        .map((a) => a.remaining(_now))
        .fold(settings.countdownSeconds, (a, b) => a < b ? a : b);
  }

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> load() async {
    settings = EmergencySettings.decode(await readSettings());
    reconcile();
    _notify();
  }

  Future<void> update(EmergencySettings next) async {
    final rebuild = next.sustainSeconds != settings.sustainSeconds ||
        next.countdownSeconds != settings.countdownSeconds;
    settings = next;
    if (rebuild) _alarms.clear();
    if (_effectsOn) unawaited(effects.setVolume(next.volume));
    reconcile();
    _notify();
    await writeSettings(next.encode());
  }

  /// Arranca o detiene la vigilancia según ajustes, sesión y primer plano.
  void reconcile() {
    final run = settings.enabled && _foreground && canMonitor();
    if (run && _poll == null) {
      final g = ++_generation;
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollAll(g));
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      unawaited(_pollAll(g));
    } else if (!run && _poll != null) {
      _stopMonitoring();
    }
  }

  void _stopMonitoring() {
    ++_generation;
    _poll?.cancel(); _ticker?.cancel();
    _poll = null; _ticker = null;
    _alarms.clear();
    if (!testing) _setEffects(false);
    _notify();
  }

  Future<void> _pollAll(int g) async {
    if (_polling || g != _generation) return;
    _polling = true;
    try {
      final cams = await loadCameras();
      if (g != _generation) return;
      _cameras = cams.where((c) => c.isConfigured && c.isActive &&
          c.notificationsEnabled && (c.hlsViewUrl?.isNotEmpty ?? false)).toList();
      _alarms.removeWhere((id, _) => !_cameras.any((c) => c.id == id));
      await Future.wait(_cameras.map((c) => _pollCamera(c, g)));
    } catch (_) {
      // Sin datos frescos ninguna alarma avanza: ValidationAlarm exige
      // muestras de menos de 5 s.
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollCamera(CameraConfigModel cam, int g) async {
    final alarm = _alarms.putIfAbsent(cam.id, () => ValidationAlarm(
        sustainSeconds: settings.sustainSeconds,
        countdownSeconds: settings.countdownSeconds));
    try {
      final s = await loadStatus(cam);
      if (g != _generation) return;
      final ts = s['ts'];
      final intent = s['intent'];
      final state = intent is Map ? intent['state'] : null;
      if (s['state'] != 'ok' || ts is! num || !ts.isFinite) { alarm.missing(); return; }
      // Estados de caiee.py: suspect y high_risk son riesgo de intrusión.
      final risky = s['persons'] is num && (s['persons'] as num) > 0 &&
          (state == 'suspect' || state == 'high_risk');
      final wasCounting = alarm.counting;
      alarm.sample(now: _now, timestamp: ts.toDouble(), risky: risky);
      if (!wasCounting && alarm.counting) cameraName = cam.name;
    } catch (_) {
      if (g == _generation) alarm.missing();
    }
  }

  void _tick() {
    var expired = false;
    for (final a in _alarms.values) {
      if (a.tick(_now, armed: true)) expired = true;
    }
    if (testing && _now >= (_testDeadline ?? 0)) {
      testing = false; // una prueba nunca llama
    }
    if (expired) unawaited(_placeCall());
    _setEffects(counting);
    if (counting || expired) _notify();
  }

  Future<void> _placeCall() async {
    final number = settings.callableNumber;
    if (!settings.autoCall || number == null) return;
    try {
      lastCallPlaced = await effects.call(number);
    } catch (_) {
      lastCallPlaced = false;
    }
    _notify();
  }

  void _setEffects(bool on) {
    if (on == _effectsOn) return;
    _effectsOn = on;
    unawaited(on ? effects.start(settings.volume) : effects.stop());
    if (!on) cameraName = null;
  }

  /// El usuario la desactiva. La misma cámara no vuelve a saltar hasta que
  /// recupere un estado normal (ValidationAlarm queda enclavada).
  void dismiss() {
    for (final a in _alarms.values) { a.cancel(); }
    testing = false;
    _setEffects(false);
    _notify();
  }

  /// Muestra la alerta unos segundos para comprobar sonido y vibración.
  /// Una prueba nunca llama a nadie.
  void test() {
    testing = true;
    _testDeadline = _now + 10;
    lastCallPlaced = null;
    _setEffects(true);
    _notify();
  }

  Future<bool> requestCallPermission() => effects.requestCallPermission();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive no cuenta como salir: lo provocan bajar la cortina de
    // notificaciones o el aviso de iOS para confirmar la llamada.
    _foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_foreground) dismiss();
    reconcile();
  }

  @override
  void clearSession() {
    dismiss();
    _stopMonitoring();
    _cameras = [];
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel(); _ticker?.cancel();
    unawaited(effects.stop());
    super.dispose();
  }
}

/// Acceso para tests: avanzar la vigilancia sin esperar a los temporizadores.
extension EmergencyProviderTesting on EmergencyProvider {
  @visibleForTesting
  Future<void> pollNow() => _pollAll(_generation);
  @visibleForTesting
  void tickNow() => _tick();
}
