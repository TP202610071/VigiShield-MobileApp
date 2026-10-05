import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Fija la rotación del video publicado según la posición física del teléfono
/// (ver RotacionCamara.kt). Así la interfaz puede quedarse en vertical mientras
/// el teléfono transmite acostado.
///
/// Solo Android: en iPhone la cámara de WebRTC ya rota con la orientación
/// física del dispositivo, no con la de la pantalla.
class RotacionCamara {
  static const _canal = MethodChannel('vigishield/rotacion_camara');

  static Future<void> fijar(MediaStreamTrack pista, {required int grados, required bool frontal}) async {
    if (kIsWeb || !Platform.isAndroid || pista.id == null) return;
    try {
      await _canal.invokeMethod<int>('fijar', {'trackId': pista.id, 'grados': grados, 'frontal': frontal});
    } catch (e) {
      // Sin el procesador el video sale con la rotación de la pantalla: se
      // nota de lado, pero la transmisión sigue.
      debugPrint('[VS-CAM] no se pudo fijar la rotación: $e');
    }
  }
}
