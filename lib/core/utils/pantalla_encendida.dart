import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantener la pantalla encendida, compartido entre varias partes de la app.
///
/// Cada una pide la pantalla con su motivo y la suelta al terminar; se apaga
/// solo cuando nadie la necesita. Antes cada una llamaba a WakelockPlus por su
/// cuenta: al desactivar la alerta de emergencia se soltaba la pantalla aunque
/// el teléfono siguiera transmitiendo, la pantalla se apagaba y, al pasar a
/// segundo plano, la transmisión se cortaba.
class PantallaEncendida {
  PantallaEncendida._();
  static final _motivos = <String>{};

  static void pedir(String motivo) {
    if (_motivos.add(motivo) && _motivos.length == 1) unawaited(_aplicar(true));
  }

  static void soltar(String motivo) {
    if (_motivos.remove(motivo) && _motivos.isEmpty) unawaited(_aplicar(false));
  }

  static Future<void> _aplicar(bool encendida) async {
    try {
      await (encendida ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {/* sin plataforma (pruebas) */}
  }
}
