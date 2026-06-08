import '../models/camera_config_model.dart';
import '../../core/network/api_client.dart';

class CameraDataService {
  final ApiClient _api;
  CameraDataService(this._api);

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
}
