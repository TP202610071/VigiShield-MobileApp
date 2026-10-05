import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/storage/auth_storage.dart';
import '../models/camera_config_model.dart';

/// Una captura del video de una cámara, con su hora.
class Captura {
  const Captura(this.bytes, this.tomada);
  final Uint8List bytes;
  final DateTime tomada;
}

/// Capturas crudas del video de cada cámara, para dibujar las zonas de interés.
///
/// Salen del servidor de video (lo mismo que recibe y analiza el motor, con su
/// orientación y encuadre), no del último cuadro anotado por la IA: ese solo
/// existe si la cámara está activa y alguien la está mirando, y por eso la
/// vista previa salía unas veces sí y otras no. Se guardan en el teléfono por
/// cámara para que el editor abra al instante con la última.
class CapturaCamara {
  CapturaCamara(this._storage, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 18),
              responseType: ResponseType.bytes,
              validateStatus: (_) => true,
            ));

  final AuthStorage _storage;
  final Dio _dio;
  final _memoria = <String, Captura>{};

  Future<File> _archivo(String cameraId) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/capturas');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$cameraId.jpg');
  }

  /// La última captura guardada de la cámara, o null.
  Future<Captura?> guardada(String cameraId) async {
    final enMemoria = _memoria[cameraId];
    if (enMemoria != null) return enMemoria;
    try {
      final f = await _archivo(cameraId);
      if (!await f.exists()) return null;
      final c = Captura(await f.readAsBytes(), await f.lastModified());
      _memoria[cameraId] = c;
      return c;
    } catch (_) {
      return null;
    }
  }

  /// Toma una captura nueva del video en vivo. Null si la cámara no está
  /// transmitiendo o no hay red.
  Future<Captura?> tomar(CameraConfigModel cam) async {
    final hls = cam.hlsViewUrl;
    final clave = cam.streamKey;
    if (hls == null || hls.isEmpty || clave == null || clave.isEmpty) return null;
    final host = Uri.parse(hls).host;
    final token = await _storage.getToken();
    try {
      final resp = await _dio.get<List<int>>(
        'https://$host/ai/snapshot/${Uri.encodeComponent(clave)}',
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );
      final datos = resp.data;
      if (resp.statusCode != 200 || datos == null || datos.length < 1024) return null;
      final c = Captura(Uint8List.fromList(datos), DateTime.now());
      _memoria[cam.id] = c;
      try {
        await (await _archivo(cam.id)).writeAsBytes(c.bytes, flush: true);
      } catch (_) {/* sin disco: queda en memoria */}
      return c;
    } catch (_) {
      return null;
    }
  }
}
