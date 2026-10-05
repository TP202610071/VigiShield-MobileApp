import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MobilePublishAnswer {
  final String sessionId;
  final String sdp;
  const MobilePublishAnswer(this.sessionId, this.sdp);
}

/// Comprueba que la oferta sea exactamente una pista de video y nada más.
///
/// Devuelve el problema encontrado, o null si la oferta sirve. El servidor
/// aplica la misma regla, pero fallar aquí ahorra un viaje y, sobre todo, deja
/// un mensaje que se entiende: antes el teléfono solo decía que no se pudo.
///
/// La garantía de "sin audio" es parte del trato con los participantes de la
/// validación: la cámara de su casa no puede acabar grabando conversaciones.
String? problemaDeOferta(String sdp) {
  if (!sdp.startsWith('v=0\r\n') && !sdp.startsWith('v=0\n')) {
    return 'La oferta de video no tiene el formato esperado.';
  }
  final medios = sdp
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((l) => l.startsWith('m='))
      .toList();
  if (medios.any((m) => m.startsWith('m=audio'))) {
    return 'La oferta incluye audio y esta cámara solo debe enviar video.';
  }
  if (medios.length != 1 || !medios.first.startsWith('m=video ')) {
    return 'La oferta debe llevar una sola pista de video '
        '(lleva ${medios.length}).';
  }
  return null;
}

abstract interface class MobilePublishTransport {
  Future<MobilePublishAnswer> publish(String cameraId, String sdp);
  Future<void> unpublish(String cameraId, String sessionId);
}

/// Injectable hardware boundary: tests never request camera permission.
abstract interface class MobileCameraCapture {
  MediaStream? get stream;
  Future<void> open({required bool front});
  Future<String> offer(Duration timeout);
  Future<void> answer(String sdp);
  Future<void> close();
}

class WebRtcCameraCapture implements MobileCameraCapture {
  MediaStream? _stream;
  RTCPeerConnection? _peer;
  @override MediaStream? get stream => _stream;

  @override
  Future<void> open({required bool front}) async {
    _stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      // 16:9 apaisado: es el encuadre de una camara de vigilancia y el que
      // espera el visor en vivo, que gira a horizontal.
      'video': {'facingMode': front ? 'user' : 'environment',
        'width': {'ideal': 1280, 'min': 640}, 'height': {'ideal': 720, 'min': 360},
        'frameRate': {'ideal': 24, 'max': 30}},
    });
    _peer = await createPeerConnection({'sdpSemantics': 'unified-plan', 'iceServers': []});
    final capabilities = await getRtpSenderCapabilities('video');
    final codecs = (capabilities.codecs ?? <RTCRtpCodecCapability>[])
        .where((c) => c.mimeType.toLowerCase() == 'video/h264').toList();
    if (codecs.isEmpty) throw StateError('Este dispositivo no ofrece video H264.');
    for (final track in _stream!.getVideoTracks()) {
      final transceiver = await _peer!.addTransceiver(track: track,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly, streams: [_stream!]));
      await transceiver.setCodecPreferences(codecs);
    }
  }

  @override
  Future<String> offer(Duration timeout) async {
    final peer = _peer!;
    final gathered = Completer<void>();
    peer.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !gathered.isCompleted) gathered.complete();
    };
    try {
      // Sin constraints, flutter_webrtc usa OfferToReceiveAudio/Video = true y
      // añade dos líneas de recepción (una de ellas de AUDIO) encima de nuestro
      // transceptor sendonly. La oferta salía con tres m= y el servidor la
      // rechazaba con "Solo se permite video.". Esto solo publica: no recibe nada.
      await peer.setLocalDescription(await peer.createOffer(const {
        'mandatory': {'OfferToReceiveAudio': false, 'OfferToReceiveVideo': false},
        'optional': <dynamic>[],
      }));
      if (peer.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
        await gathered.future.timeout(timeout, onTimeout: () => throw TimeoutException('No se completó ICE. Revisa la red e intenta de nuevo.'));
      }
      final description = await peer.getLocalDescription();
      if (description?.sdp == null || description!.sdp!.isEmpty) throw StateError('Oferta SDP vacía.');
      final problema = problemaDeOferta(description.sdp!);
      if (problema != null) throw StateError(problema);
      return description.sdp!;
    } finally { peer.onIceGatheringState = null; }
  }

  @override Future<void> answer(String sdp) => _peer!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  @override
  Future<void> close() async {
    final stream = _stream; _stream = null;
    final peer = _peer; _peer = null;
    try {
      if (stream != null) {
        for (final track in stream.getTracks()) { await track.stop(); }
        await stream.dispose();
      }
    } finally {
      if (peer != null) { try { await peer.close(); } finally { await peer.dispose(); } }
    }
  }
}

/// Serializes startup/teardown; a late HTTP answer is still deleted after stop.
class MobileCameraPublisher extends ChangeNotifier {
  final MobilePublishTransport transport;
  final MobileCameraCapture capture;
  final Duration iceTimeout;
  MobileCameraPublisher({required this.transport, MobileCameraCapture? capture,
    this.iceTimeout = const Duration(seconds: 12)}) : capture = capture ?? WebRtcCameraCapture();
  String? _cameraId, _sessionId;
  String? error;
  bool isPublishing = false;
  bool isStarting = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _starting, _stopping;
  MediaStream? get stream => capture.stream;
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> start(String cameraId, {required bool front}) {
    if (_disposed || isStarting || isPublishing || _stopping != null) return Future.value();
    final generation = ++_generation;
    isStarting = true; error = null; _notify();
    return _starting = _start(generation, front, cameraId);
  }
  Future<void> _start(int generation, bool front, String cameraId) async {
    try {
      // Keep the original camera/session pair until DELETE succeeds.
      if (_sessionId != null) {
        await _cleanup();
        if (_sessionId != null) throw StateError('La sesión anterior sigue pendiente de cierre. Reintenta cuando haya conexión.');
      }
      if (generation != _generation) return;
      _cameraId = cameraId;
      await capture.open(front: front);
      if (generation != _generation) return;
      _notify();
      final offer = await capture.offer(iceTimeout);
      if (generation != _generation) return;
      final result = await transport.publish(_cameraId!, offer);
      _sessionId = result.sessionId;
      if (generation != _generation) return;
      if (result.sdp.isEmpty || result.sessionId.isEmpty) throw StateError('Respuesta de publicación inválida.');
      await capture.answer(result.sdp);
      if (generation == _generation) isPublishing = true;
    } catch (e) { if (generation == _generation) error = e.toString(); }
    finally {
      if (!isPublishing) await _cleanup();
      isStarting = false; _starting = null; _notify();
    }
  }
  Future<void> _cleanup() async {
    try { await capture.close(); } catch (e) { error ??= e.toString(); }
    final session = _sessionId; final camera = _cameraId;
    if (session != null && camera != null) {
      try {
        await transport.unpublish(camera, session);
        _sessionId = null;
      } catch (e) { error = 'No se pudo cerrar la sesión remota: $e'; }
    }
  }
  Future<void> stop() {
    if (_stopping != null) return _stopping!;
    ++_generation;
    isPublishing = false;
    return _stopping = _stop().whenComplete(() { _stopping = null; });
  }
  Future<void> _stop() async {
    // Release active tracks immediately, even while signaling is in flight.
    try { await capture.close(); } catch (e) { error = e.toString(); }
    await _starting;
    await _cleanup();
    _notify();
  }
  @override void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
