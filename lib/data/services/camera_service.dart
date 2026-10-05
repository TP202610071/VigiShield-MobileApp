import '../models/camera_config_model.dart';
import '../models/zone_model.dart';
import '../../core/network/api_client.dart';
import 'camera_lan_control.dart';
import 'mobile_camera_publisher.dart';
import 'package:dio/dio.dart';

class CameraDataService implements MobilePublishTransport {
  final ApiClient _api;
  CameraDataService(this._api);

  Future<CameraConfigModel> setNotificationsEnabled(String id, bool enabled) async {
    try {
      final response = await _api.dio.patch<Map<String, dynamic>>(
        '/api/stream/cameras/${Uri.encodeComponent(id)}/notifications', data: {'enabled': enabled});
      return CameraConfigModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException('No se pudo cambiar las notificaciones.', e.response?.statusCode);
    }
  }

  /// Enciende o apaga el procesamiento de IA de una cámara.
  Future<CameraConfigModel> setActive(String id, bool enabled) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '/api/stream/cameras/${Uri.encodeComponent(id)}/active', body: {'enabled': enabled});
    return CameraConfigModel.fromJson(data);
  }

  @override
  Future<MobilePublishAnswer> publish(String cameraId, String sdp) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/api/stream/cameras/${Uri.encodeComponent(cameraId)}/publish', body: {'sdp': sdp});
    return MobilePublishAnswer(data['sessionId'] as String, data['sdp'] as String);
  }

  @override
  Future<void> unpublish(String cameraId, String sessionId) => _api.delete(
    '/api/stream/cameras/${Uri.encodeComponent(cameraId)}/publish/${Uri.encodeComponent(sessionId)}');

  /// Guarda las zonas de interés (ROI) dibujadas por el usuario para una cámara.
  /// Una lista vacía borra las zonas (vuelve al comportamiento sin contexto).
  Future<CameraConfigModel> updateZones(String cameraId, List<Zone> zones) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/api/stream/cameras/$cameraId/zones',
      body: {'zones': encodeZones(zones)},
    );
    return CameraConfigModel.fromJson(data);
  }

  Future<List<CameraConfigModel>> getCameras() async {
    final data = await _api.get<List<dynamic>>('/api/stream/cameras');
    return data.map((j) => CameraConfigModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<CameraConfigModel> createCamera(SaveCameraRequest req) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/api/stream/cameras',
      body: req.toJson(),
    );
    return CameraConfigModel.fromJson(data);
  }

  Future<CameraConfigModel> updateCamera(String id, SaveCameraRequest req) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/api/stream/cameras/$id',
      body: req.toJson(),
    );
    return CameraConfigModel.fromJson(data);
  }

  Future<void> deleteCamera(String id) async {
    await _api.delete('/api/stream/cameras/$id');
  }

  /// Read live image/video settings from the camera (hi3510 CGI via backend).
  Future<Map<String, String>> getCameraControls(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/api/stream/cameras/$id/control');
    return data.map((k, v) => MapEntry(k, '$v'));
  }

  /// Apply image/video settings to the camera.
  Future<void> updateCameraControls(String id, Map<String, String> settings) async {
    await _api.put('/api/stream/cameras/$id/control', body: settings);
  }

  /// IP y credenciales para hablar con la cámara desde la red local.
  Future<CameraLanAccess> getCameraLanAccess(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/api/stream/cameras/$id/lan-access');
    return CameraLanAccess.fromJson(data);
  }
}
