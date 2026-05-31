import '../models/system_status_model.dart';
import '../models/alert_config_model.dart';
import '../../core/network/api_client.dart';

class SystemService {
  final ApiClient _client;

  SystemService(this._client);

  Future<SystemStatusModel> getStatus() async {
    final data = await _client.get<Map<String, dynamic>>('/api/system/status');
    return SystemStatusModel.fromJson(data);
  }

  Future<void> pauseMonitoring() => _client.put('/api/system/pause');

  Future<void> resumeMonitoring() => _client.put('/api/system/resume');

  Future<AlertConfigModel> getAlertConfig() async {
    final data = await _client.get<Map<String, dynamic>>('/api/config/alerts');
    return AlertConfigModel.fromJson(data);
  }

  Future<AlertConfigModel> updateAlertConfig(AlertConfigModel config) async {
    final data = await _client.put<Map<String, dynamic>>('/api/config/alerts', body: config.toJson());
    return AlertConfigModel.fromJson(data);
  }
}
