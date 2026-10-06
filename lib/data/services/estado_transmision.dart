import 'package:dio/dio.dart';

import '../../core/storage/auth_storage.dart';
import '../models/camera_config_model.dart';
import 'mobile_camera_publisher.dart';

/// ¿Alguien está transmitiendo la cámara de un teléfono ahora mismo?
///
/// La cámara de un teléfono solo transmite mientras VigiShield está abierta en
/// ese teléfono: al salir de la app, el sistema le quita la cámara y la
/// transmisión se corta. La cámara sigue «Activa» (eso indica si la IA la
/// analiza), así que la pestaña Cámara se quedaba en «Conectando…» sin explicar
/// nada y parecía que el sistema se había caído. Se pregunta al servidor de
/// video, que solo responde sí o no.
class EstadoTransmision {
  EstadoTransmision(this._storage, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              responseType: ResponseType.json,
            ));

  final AuthStorage _storage;
  final Dio _dio;

  /// true: alguien la transmite. false: nadie. null: no se pudo saber (sin
  /// red, servidor sin la consulta o no es una cámara de teléfono). Con null
  /// la app sigue como antes: intenta abrir el video.
  Future<bool?> enVivo(CameraConfigModel cam) async {
    if (!cam.isMobileWebRtc) return null;
    final url = urlEnVivo(cam);
    if (url == null) return null;
    try {
      final token = await _storage.getToken();
      final resp = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
        }),
      );
      final valor = resp.data?['enVivo'];
      return valor is bool ? valor : null;
    } catch (_) {
      return null;
    }
  }

  /// `https://<servidor de video>/ai/en-vivo/<clave>`, o null si la cámara no
  /// trae los datos para armarla.
  static String? urlEnVivo(CameraConfigModel cam) {
    final hls = cam.hlsViewUrl;
    final clave = cam.streamKey;
    if (hls == null || hls.isEmpty || clave == null || clave.isEmpty) return null;
    final host = Uri.tryParse(hls)?.host ?? '';
    if (host.isEmpty) return null;
    return 'https://$host/ai/en-vivo/$clave';
  }
}

/// ¿Este teléfono está transmitiendo (o empezando a transmitir) esta cámara?
bool transmiteEsteTelefono(CameraConfigModel cam, MobileCameraPublisher? pub) =>
    pub != null && pub.cameraId == cam.id && (pub.isPublishing || pub.isStarting);

/// Hay que pedir que se transmita solo si es la cámara de un teléfono, este
/// teléfono no la está transmitiendo y el servidor confirma que nadie más lo
/// hace. Si no se pudo saber, no se bloquea el video.
bool faltaTransmitir(CameraConfigModel cam, MobileCameraPublisher? pub, bool? enVivo) =>
    cam.isMobileWebRtc && !transmiteEsteTelefono(cam, pub) && enVivo == false;
