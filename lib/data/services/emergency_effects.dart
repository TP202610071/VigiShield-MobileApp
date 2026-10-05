import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Lo que la alerta hace en el teléfono. Es una interfaz para poder probar la
/// lógica de la alerta sin sonar ni llamar de verdad.
abstract class EmergencyEffects {
  Future<void> start(double volume);
  Future<void> setVolume(double volume);
  Future<void> stop();

  /// Pide permiso para llamar sin confirmación (solo Android).
  Future<bool> requestCallPermission();

  /// Lanza la llamada. En iPhone el sistema siempre pide confirmarla: iOS no
  /// deja a ninguna app llamar por su cuenta.
  Future<bool> call(String number);
}

class DeviceEmergencyEffects implements EmergencyEffects {
  static const _channel = MethodChannel('vigishield/emergency');
  final AudioPlayer _player = AudioPlayer(playerId: 'emergencia');
  Timer? _vibration;
  bool _running = false;

  @override
  Future<void> start(double volume) async {
    if (_running) return setVolume(volume);
    _running = true;
    unawaited(WakelockPlus.enable());
    try {
      // respectSilence:false — una alarma debe oírse aunque el iPhone tenga
      // el interruptor de silencio puesto. El volumen lo decide el ajuste.
      await _player.setAudioContext(
          AudioContextConfig(respectSilence: false, stayAwake: true).build());
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarma.wav'), volume: volume);
    } catch (_) {/* sin audio la alerta sigue: pantalla y vibración */}
    if (await Vibration.hasVibrator()) {
      // Un pulso por segundo en vez de un patrón con repetición: iOS ignora la
      // repetición de patrones y así vibra igual en las dos plataformas.
      void pulso() => Vibration.vibrate(duration: 600);
      pulso();
      _vibration = Timer.periodic(const Duration(seconds: 1), (_) => pulso());
    }
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() async {
    _running = false;
    _vibration?.cancel();
    _vibration = null;
    unawaited(Vibration.cancel());
    unawaited(WakelockPlus.disable());
    try { await _player.stop(); } catch (_) {}
  }

  @override
  Future<bool> requestCallPermission() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('requestCallPermission') ?? false;
  }

  @override
  Future<bool> call(String number) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>('placeCall', {'number': number}) ?? false;
    }
    return launchUrl(Uri(scheme: 'tel', path: number));
  }
}
