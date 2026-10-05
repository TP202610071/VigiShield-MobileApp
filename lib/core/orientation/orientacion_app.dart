import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Única fuente de verdad de la orientación de la app.
///
/// Regla:
/// - La interfaz va SIEMPRE en vertical, gire como gire el teléfono.
/// - Las únicas vistas en horizontal son las de video: la pestaña Cámara cuando
///   es la pantalla visible y el clip de un evento a pantalla completa. Las
///   pantallas abiertas encima de la pestaña Cámara vuelven a vertical.
/// - Transmitiendo, el acelerómetro da la posición FÍSICA del teléfono (aunque
///   el usuario tenga el giro automático bloqueado). La pantalla NO la sigue:
///   la usa el publicador para fijar la rotación del video ([gradosFisicos]).
///
/// Antes la pantalla entera seguía al teléfono mientras transmitía, porque la
/// cámara de WebRTC en Android rota el video según la pantalla. Con el teléfono
/// acostado, toda la app quedaba en horizontal hasta cortar la transmisión.
/// Ahora la rotación de cada cuadro se fija aparte (RotacionCamara).
class OrientacionApp {
  OrientacionApp._();
  static final instance = OrientacionApp._();

  bool _publicando = false;
  final Set<String> _vistasHorizontales = {};
  DeviceOrientation? _fisica;
  DeviceOrientation? _candidata;
  DateTime? _candidataDesde;
  StreamSubscription<AccelerometerEvent>? _acelerometro;
  List<DeviceOrientation>? _aplicada;

  /// Se llama cuando el teléfono, transmitiendo, cambia de posición física:
  /// el publicador reinicia la sesión para que el video arranque limpio con la
  /// rotación y el tamaño nuevos (un cambio a mitad corrompe los cuadros de la IA).
  void Function(DeviceOrientation)? alCambiarFisicaTransmitiendo;

  DeviceOrientation? get fisica => _fisica;

  /// Posición física en grados, como la rotación de pantalla de Android:
  /// 0 vertical, 90 girado a la izquierda (landscapeLeft, apoyado sobre su lado
  /// izquierdo), 180 de cabeza, 270 girado a la derecha. Sin lectura (sobre la
  /// mesa), 0.
  int get gradosFisicos => switch (_fisica) {
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
        _ => 0,
      };

  /// Antes de abrir la cámara: espera la primera lectura del acelerómetro para
  /// que el video arranque ya con su rotación definitiva.
  Future<void> iniciarTransmision() async {
    _publicando = true;
    _fisica = null;
    _candidata = null;
    _escucharAcelerometro();
    final limite = DateTime.now().add(const Duration(milliseconds: 1500));
    while (_fisica == null && DateTime.now().isBefore(limite)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// La transmisión terminó: ya no hace falta el acelerómetro.
  void finTransmision() {
    if (!_publicando) return;
    _publicando = false;
    unawaited(_acelerometro?.cancel());
    _acelerometro = null;
  }

  /// La pestaña Cámara pasó a ser (o dejó de ser) la pantalla visible.
  void setPestanaCamara(bool valor) => _vistaHorizontal('camara', valor);

  /// Un clip de evento se abrió (o se cerró) a pantalla completa.
  void setVideoCompleto(bool valor) => _vistaHorizontal('clip', valor);

  void _vistaHorizontal(String vista, bool valor) {
    final cambio = valor ? _vistasHorizontales.add(vista) : _vistasHorizontales.remove(vista);
    if (cambio) _aplicar();
  }

  @visibleForTesting
  List<DeviceOrientation> deseada() => _vistasHorizontales.isNotEmpty
      ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
      : const [DeviceOrientation.portraitUp];

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
      // Sin acelerómetro: se transmite como si estuviera en vertical.
    }
  }

  /// Clasifica una lectura del acelerómetro. El eje que apunta hacia arriba
  /// marca +9.8: +y vertical, −y vertical invertido, +x girado a la izquierda
  /// (landscapeLeft), −x girado a la derecha. Sobre la mesa (domina z) no se
  /// cambia nada. Solo se acepta un cambio estable durante [estable], para que
  /// manipular el teléfono no reinicie la transmisión: con la app en vertical,
  /// la gente lo usa de pie y luego lo acuesta, y con 0.8 s un tester reinició
  /// siete veces en tres minutos (cada reinicio corta el video y la IA).
  static const estable = Duration(milliseconds: 2500);

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
      // Primera lectura: se adopta de inmediato (la espera iniciarTransmision).
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
    if (t.difference(_candidataDesde!) >= estable) {
      _fisica = o;
      _candidata = null;
      if (_publicando) alCambiarFisicaTransmitiendo?.call(o);
    }
  }

  @visibleForTesting
  void reiniciarParaPruebas() {
    unawaited(_acelerometro?.cancel());
    _acelerometro = null;
    _publicando = false;
    _vistasHorizontales.clear();
    _fisica = null;
    _candidata = null;
    _aplicada = null;
    alCambiarFisicaTransmitiendo = null;
  }
}
