import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Única fuente de verdad de la orientación de la app.
///
/// El video que publica el teléfono toma la orientación de la PANTALLA, no la
/// del teléfono (así funciona la cámara de WebRTC en Android). Con la pantalla
/// fijada por cada vista, el mismo teléfono quieto transmitía unas veces en
/// vertical y otras de lado, el tamaño del video cambiaba a mitad de la
/// transmisión (la IA recibía cuadros corruptos) y las zonas dibujadas en una
/// orientación no servían para la otra.
///
/// Regla:
/// - Transmitiendo: la pantalla sigue la posición FÍSICA del teléfono (por el
///   acelerómetro, aunque el usuario tenga el giro automático bloqueado). El
///   video sale siempre derecho y solo cambia si el teléfono se gira de verdad.
/// - Sin transmitir: vertical, salvo la pestaña Cámara cuando es la pantalla
///   visible (horizontal). Las pantallas abiertas encima de la pestaña Cámara
///   ya no heredan su horizontal: antes la app giraba sola al guardar zonas.
class OrientacionApp {
  OrientacionApp._();
  static final instance = OrientacionApp._();

  bool _publicando = false;
  bool _pestanaCamara = false;
  DeviceOrientation? _fisica;
  DeviceOrientation? _candidata;
  DateTime? _candidataDesde;
  StreamSubscription<AccelerometerEvent>? _acelerometro;
  List<DeviceOrientation>? _aplicada;

  /// Se llama cuando el teléfono, transmitiendo, cambia de posición física
  /// (después de que la pantalla ya giró): el publicador reinicia la sesión
  /// para que el video arranque limpio con el tamaño nuevo.
  void Function(DeviceOrientation)? alCambiarFisicaTransmitiendo;

  DeviceOrientation? get fisica => _fisica;

  /// Antes de abrir la cámara: fija la pantalla a la posición física y espera
  /// a que termine de girar, para que el video arranque ya con su orientación
  /// definitiva (si gira después, cambia de tamaño a mitad de la transmisión).
  Future<void> iniciarTransmision({Duration esperaGiro = const Duration(milliseconds: 900)}) async {
    final antes = _aplicada;
    _publicando = true;
    _fisica = null;
    _candidata = null;
    _escucharAcelerometro();
    final limite = DateTime.now().add(const Duration(milliseconds: 1500));
    while (_fisica == null && DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _aplicar();
    if (!listEquals(antes, _aplicada)) await Future<void>.delayed(esperaGiro);
  }

  /// La transmisión terminó: vuelve la orientación de cada vista.
  void finTransmision() {
    if (!_publicando) return;
    _publicando = false;
    unawaited(_acelerometro?.cancel());
    _acelerometro = null;
    _aplicar();
  }

  void setPestanaCamara(bool valor) {
    if (valor == _pestanaCamara) return;
    _pestanaCamara = valor;
    _aplicar();
  }

  @visibleForTesting
  List<DeviceOrientation> deseada() {
    if (_publicando) return [_fisica ?? DeviceOrientation.portraitUp];
    if (_pestanaCamara) {
      return const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
    }
    return const [DeviceOrientation.portraitUp];
  }

  void _aplicar() {
    final d = deseada();
    if (listEquals(d, _aplicada)) return;
    _aplicada = d;
    unawaited(SystemChrome.setPreferredOrientations(d));
  }

  void _escucharAcelerometro() {
    if (_acelerometro != null) return;
    try {
      _acelerometro = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen((e) => muestra(e.x, e.y, e.z), onError: (_) {});
    } catch (_) {
      // Sin acelerómetro: se transmite en la orientación actual de la pantalla.
    }
  }

  /// Clasifica una lectura del acelerómetro. El eje que apunta hacia arriba
  /// marca +9.8: +y vertical, −y vertical invertido, +x girado a la izquierda
  /// (landscapeLeft), −x girado a la derecha. Sobre la mesa (domina z) no se
  /// cambia nada. Solo se acepta un cambio estable durante 0.8 s, para que un
  /// movimiento brusco no gire la pantalla.
  @visibleForTesting
  void muestra(double x, double y, double z, {DateTime? ahora}) {
    final t = ahora ?? DateTime.now();
    final ax = x.abs(), ay = y.abs();
    DeviceOrientation? o;
    if (ay > 6 && ay > ax * 1.5) {
      o = y > 0 ? DeviceOrientation.portraitUp : DeviceOrientation.portraitDown;
    } else if (ax > 6 && ax > ay * 1.5) {
      o = x > 0 ? DeviceOrientation.landscapeLeft : DeviceOrientation.landscapeRight;
    }
    if (o == null) return;
    if (_fisica == null) {
      // Primera lectura: se adopta de inmediato (la aplica iniciarTransmision).
      _fisica = o;
      return;
    }
    if (o == _fisica) {
      _candidata = null;
      return;
    }
    if (o != _candidata) {
      _candidata = o;
      _candidataDesde = t;
      return;
    }
    if (t.difference(_candidataDesde!) >= const Duration(milliseconds: 800)) {
      _fisica = o;
      _candidata = null;
      _aplicar();
      if (_publicando) alCambiarFisicaTransmitiendo?.call(o);
    }
  }

  @visibleForTesting
  void reiniciarParaPruebas() {
    unawaited(_acelerometro?.cancel());
    _acelerometro = null;
    _publicando = false;
    _pestanaCamara = false;
    _fisica = null;
    _candidata = null;
    _aplicada = null;
    alCambiarFisicaTransmitiendo = null;
  }
}
