import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/session_scoped.dart';
import '../../core/orientation/orientacion_app.dart';
import 'rotacion_camara.dart';
import '../../core/network/api_client.dart';

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
  Future<bool> hasTorch();
  Future<void> setTorch(bool enabled);
  Future<String> offer(Duration timeout);
  Future<void> answer(String sdp);
  Future<void> close();
}

class WebRtcCameraCapture implements MobileCameraCapture {
  MediaStream? _stream;
  RTCPeerConnection? _peer;
  final List<RTCRtpSender> _senders = [];
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
    // La interfaz se queda en vertical aunque el teléfono esté acostado: la
    // rotación del video se fija con la posición física, no con la pantalla.
    for (final track in _stream!.getVideoTracks()) {
      await RotacionCamara.fijar(track,
          grados: OrientacionApp.instance.gradosFisicos, frontal: front);
    }
    _peer = await createPeerConnection({'sdpSemantics': 'unified-plan', 'iceServers': []});
    final capabilities = await getRtpSenderCapabilities('video');
    final codecs = (capabilities.codecs ?? <RTCRtpCodecCapability>[])
        .where((c) => c.mimeType.toLowerCase() == 'video/h264').toList();
    if (codecs.isEmpty) throw StateError('Este dispositivo no ofrece video H264.');
    for (final track in _stream!.getVideoTracks()) {
      final transceiver = await _peer!.addTransceiver(track: track,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendOnly, streams: [_stream!]));
      await transceiver.setCodecPreferences(codecs);
      _senders.add(transceiver.sender);
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

  @override
  Future<void> answer(String sdp) async {
    await _peer!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    await _mantenerResolucion();
  }

  /// WebRTC arranca con poca resolución y la sube cuando estima más ancho de
  /// banda (o la baja si falta). La IA lee el stream con OpenCV, que no
  /// soporta un cambio de tamaño a mitad: se quedaba con el último cuadro
  /// bueno y la vista de IA se congelaba a los pocos segundos. Con
  /// «maintain-resolution» el video sale siempre a 1280x720 y, si falta red,
  /// baja los cuadros por segundo.
  Future<void> _mantenerResolucion() async {
    for (final sender in _senders) {
      try {
        final parametros = sender.parameters;
        parametros.degradationPreference = RTCDegradationPreference.MAINTAIN_RESOLUTION;
        await sender.setParameters(parametros);
      } catch (e) {
        debugPrint('[VS-CAM] no se pudo fijar la resolución: $e');
      }
    }
  }
  MediaStreamTrack? get _videoTrack {
    final tracks = _stream?.getVideoTracks();
    return tracks == null || tracks.isEmpty ? null : tracks.first;
  }
  @override Future<bool> hasTorch() async => await _videoTrack?.hasTorch() ?? false;
  @override Future<void> setTorch(bool enabled) async {
    final track = _videoTrack;
    if (track == null) throw StateError('La cámara no está abierta.');
    await track.setTorch(enabled);
  }
  @override
  Future<void> close() async {
    final stream = _stream; _stream = null;
    final peer = _peer; _peer = null;
    _senders.clear();
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
class MobileCameraPublisher extends ChangeNotifier
    with WidgetsBindingObserver
    implements SessionScoped {
  final MobilePublishTransport transport;
  final MobileCameraCapture capture;
  final Duration iceTimeout;

  /// Se espera antes de abrir la cámara. La app fija aquí la orientación a la
  /// posición física del teléfono: el video toma la orientación de la pantalla
  /// en el momento de abrir la cámara, y si la pantalla gira después, el video
  /// cambia de tamaño a mitad de la transmisión.
  final Future<void> Function()? antesDeAbrir;

  /// El ciclo de vida lo vigila el PUBLICADOR, no la pantalla.
  ///
  /// Cuando lo hacia la pantalla, salir de ella la desmontaba y ya nadie
  /// paraba la transmision: la sesion quedaba viva en el servidor y bloqueaba
  /// la camara durante dos horas con un 409. Aqui se detiene siempre que la
  /// app deja de estar en primer plano, haya la pantalla que haya encima.
  ///
  /// [observarCicloDeVida] se desactiva en las pruebas, que manejan el ciclo
  /// de vida a mano.
  MobileCameraPublisher({required this.transport, MobileCameraCapture? capture,
    this.iceTimeout = const Duration(seconds: 12), bool observarCicloDeVida = true,
    this.antesDeAbrir})
      : capture = capture ?? WebRtcCameraCapture() {
    if (observarCicloDeVida) {
      _observando = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }
  bool _observando = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` llega tambien al girar la pantalla o al bajar el panel de
    // notificaciones; solo se corta cuando la app se va de verdad.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }
  String? _cameraId, _sessionId;
  String? error;
  bool isPublishing = false;
  bool isStarting = false;
  bool front = false;
  bool hasTorch = false;
  bool torchEnabled = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _starting, _stopping;
  MediaStream? get stream => capture.stream;
  /// Camara que se esta publicando, para saber si es la que se esta viendo.
  String? get cameraId => _cameraId;
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> start(String cameraId, {required bool front}) {
    if (_disposed || isStarting || isPublishing || _stopping != null) return Future.value();
    final generation = ++_generation;
    isStarting = true; error = null; _notify();
    return _starting = _start(generation, front, cameraId);
  }
  Future<void> _start(int generation, bool front, String cameraId) async {
    try {
      // Se intenta cerrar la sesión anterior, pero no se bloquea si no se
      // puede: el servidor reemplaza la publicación previa de la misma cámara.
      // Antes, una sesión que ya no existía (cámara borrada, servidor
      // reiniciado) dejaba el publicador trabado hasta cerrar la app.
      if (_sessionId != null) {
        await _cleanup();
        _sessionId = null;
        error = null;
      }
      if (generation != _generation) return;
      _cameraId = cameraId;
      this.front = front;
      hasTorch = false;
      torchEnabled = false;
      if (antesDeAbrir != null) await antesDeAbrir!();
      if (generation != _generation) return;
      await capture.open(front: front);
      if (generation != _generation) return;
      if (!front) {
        try { hasTorch = await capture.hasTorch(); } catch (_) { hasTorch = false; }
      }
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
    hasTorch = false;
    torchEnabled = false;
    try { await capture.close(); } catch (e) { error ??= e.toString(); }
    final session = _sessionId; final camera = _cameraId;
    if (session != null && camera != null) {
      try {
        await transport.unpublish(camera, session);
        _sessionId = null;
      } on ApiException catch (e) {
        // 404: la sesión ya no existe en el servidor; para nosotros, cerrada.
        if (e.statusCode == 404) {
          _sessionId = null;
        } else {
          error = 'No se pudo cerrar la sesión remota: $e';
        }
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
  /// Corta y vuelve a publicar la misma cámara con la misma lente. Se usa al
  /// girar el teléfono: arrancar una sesión nueva entrega un video limpio con
  /// el tamaño nuevo, en vez de cambiarlo a mitad de la transmisión.
  Future<void> reiniciar() async {
    final camara = _cameraId;
    if (!isPublishing || camara == null || _disposed) return;
    final lente = front;
    final linterna = torchEnabled;
    await stop();
    await start(camara, front: lente);
    if (linterna && isPublishing && hasTorch) {
      try { await setTorch(true); } catch (_) {}
    }
  }

  Future<void> setTorch(bool enabled) async {
    if (!isPublishing || front || !hasTorch) {
      throw StateError('La linterna no está disponible en esta cámara.');
    }
    await capture.setTorch(enabled);
    torchEnabled = enabled;
    _notify();
  }
  /// Cerrar sesion corta la transmision: la camara de una cuenta no puede
  /// seguir publicando cuando entra otra.
  @override
  void clearSession() { unawaited(stop()); }

  @override void dispose() {
    if (_observando) WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
