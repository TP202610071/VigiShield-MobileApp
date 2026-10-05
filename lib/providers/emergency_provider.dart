import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models/camera_config_model.dart';
import '../data/models/emergency_settings.dart';
import '../data/services/emergency_effects.dart';
import 'session_scoped.dart';

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

  /// Duración de la cuenta atrás de una prueba.
  static const testSeconds = 10;

  /// Sin muestras frescas durante este tiempo, la racha de riesgo de una
  /// cámara se da por perdida (solo antes de que empiece la cuenta atrás).
  static const staleSeconds = 10.0;

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

  // Racha de riesgo por cámara: desde cuándo y última muestra fresca.
  final _since = <String, double>{};
  final _lastFresh = <String, double>{};
  // Cámaras que ya alertaron (o se desactivaron): no repiten hasta volver a la calma.
  final _latched = <String>{};

  Timer? _poll, _alarmTicker;
  double? _deadline;
  int _alarmSeconds = 30;
  bool _foreground = true, _polling = false, _disposed = false;
  int _generation = 0;

  final double Function() _clock;
  double get _now => _clock();

  /// La cuenta atrás NO depende de que sigan llegando datos de la cámara: una
  /// vez que empieza, solo termina si el usuario la desactiva o llega a cero.
  /// Antes se anulaba por dentro al faltar unos segundos de datos, la pantalla
  /// no se enteraba y quedaba congelada en un número sin llegar a llamar.
  bool get counting => _deadline != null;

  int get remaining => _deadline == null
      ? 0
      : (_deadline! - _now).ceil().clamp(0, _alarmSeconds);

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> load() async {
    settings = EmergencySettings.decode(await readSettings());
    reconcile();
    _notify();
  }

  Future<void> update(EmergencySettings next) async {
    settings = next;
    if (counting) unawaited(effects.setVolume(next.volume));
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
      unawaited(_pollAll(g));
    } else if (!run && _poll != null) {
      _stopMonitoring();
    }
  }

  void _stopMonitoring() {
    ++_generation;
    _poll?.cancel();
    _poll = null;
    _since.clear();
    _lastFresh.clear();
    _notify();
  }

  Future<void> _pollAll(int g) async {
    if (_polling || g != _generation) return;
    _polling = true;
    try {
      final cams = (await loadCameras()).where((c) => c.isConfigured && c.isActive &&
          c.notificationsEnabled && (c.hlsViewUrl?.isNotEmpty ?? false)).toList();
      if (g != _generation) return;
      final ids = cams.map((c) => c.id).toSet();
      _since.removeWhere((id, _) => !ids.contains(id));
      _latched.removeWhere((id) => !ids.contains(id));
      await Future.wait(cams.map((c) => _pollCamera(c, g)));
    } catch (_) {
      // Sin datos no se inicia ninguna alerta; la que esté en curso sigue.
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollCamera(CameraConfigModel cam, int g) async {
    Map<String, dynamic>? s;
    try {
      s = await loadStatus(cam);
    } catch (_) {}
    if (g != _generation) return;
    final now = _now;
    final ts = s?['ts'];
    final intent = s?['intent'];
    final fresh = s != null && s['state'] == 'ok' && ts is num && ts.isFinite &&
        now - ts <= 10 && ts <= now + 2;
    if (!fresh) {
      if (now - (_lastFresh[cam.id] ?? now) > staleSeconds) _since.remove(cam.id);
      return;
    }
    _lastFresh[cam.id] = now;
    final state = intent is Map ? intent['state'] : null;
    // Estados del motor: «suspect» y «high_risk» son riesgo de intrusión.
    final risky = s['persons'] is num && (s['persons'] as num) > 0 &&
        (state == 'suspect' || state == 'high_risk');
    if (!risky) {
      _since.remove(cam.id);
      _latched.remove(cam.id);
      return;
    }
    if (_latched.contains(cam.id)) return;
    final since = _since.putIfAbsent(cam.id, () => ts.toDouble());
    if (!counting && ts - since >= settings.sustainSeconds) {
      _start(cam.name, test: false);
    }
  }

  void _start(String? camara, {required bool test}) {
    testing = test;
    cameraName = camara;
    lastCallPlaced = null;
    _alarmSeconds = test ? testSeconds : settings.countdownSeconds;
    _deadline = _now + _alarmSeconds;
    _alarmTicker?.cancel();
    _alarmTicker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    unawaited(effects.start(settings.volume));
    _notify();
  }

  void _tick() {
    if (_deadline == null) return;
    if (_now >= _deadline!) {
      _end(latch: true);
      unawaited(_placeCall());
    }
    _notify(); // refresca el número cada cuarto de segundo
  }

  void _end({required bool latch}) {
    if (latch) _latched.addAll(_since.keys);
    _since.clear();
    _deadline = null;
    testing = false;
    cameraName = null;
    _alarmTicker?.cancel();
    _alarmTicker = null;
    unawaited(effects.stop());
    _notify();
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

  /// El usuario la desactiva. La misma cámara no vuelve a saltar hasta que
  /// recupere un estado normal.
  void dismiss() {
    if (counting) _end(latch: true);
  }

  /// Recorrido completo durante [testSeconds] segundos: pantalla, sonido,
  /// vibración y, si está activada, la llamada al terminar.
  Future<void> test() async {
    if (counting) return;
    if (settings.willCall) await effects.requestCallPermission();
    _start(null, test: true);
  }

  Future<bool> requestCallPermission() => effects.requestCallPermission();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive no cuenta como salir: lo provocan bajar la cortina de
    // notificaciones o el aviso de iOS para confirmar la llamada.
    _foreground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_foreground && counting) _end(latch: true);
    reconcile();
  }

  @override
  void clearSession() {
    if (counting) _end(latch: false);
    _stopMonitoring();
    _latched.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _alarmTicker?.cancel();
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
