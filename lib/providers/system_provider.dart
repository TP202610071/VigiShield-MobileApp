import 'package:flutter/foundation.dart';
import '../data/models/system_status_model.dart';
import '../data/models/alert_config_model.dart';
import '../data/services/system_service.dart';
import '../core/network/api_client.dart';

class SystemProvider extends ChangeNotifier {
  final SystemService _service;

  SystemProvider(this._service);

  SystemStatusModel? _status;
  AlertConfigModel? _alertConfig;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  SystemStatusModel? get status => _status;
  AlertConfigModel? get alertConfig => _alertConfig;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  Future<void> fetchStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _status = await _service.getStatus();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> pauseMonitoring() async {
    _isUpdating = true;
    notifyListeners();
    try {
      await _service.pauseMonitoring();
      _status = SystemStatusModel(
        isMonitoringActive: false,
        lastEventAt: _status?.lastEventAt,
        eventsTodayCount: _status?.eventsTodayCount ?? 0,
        streamUrl: _status?.streamUrl ?? '',
      );
      return true;
    } on ApiException {
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> resumeMonitoring() async {
    _isUpdating = true;
    notifyListeners();
    try {
      await _service.resumeMonitoring();
      _status = SystemStatusModel(
        isMonitoringActive: true,
        lastEventAt: _status?.lastEventAt,
        eventsTodayCount: _status?.eventsTodayCount ?? 0,
        streamUrl: _status?.streamUrl ?? '',
      );
      return true;
    } on ApiException {
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> fetchAlertConfig() async {
    try {
      _alertConfig = await _service.getAlertConfig();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> updateAlertConfig(AlertConfigModel config) async {
    _isUpdating = true;
    notifyListeners();
    try {
      _alertConfig = await _service.updateAlertConfig(config);
      return true;
    } on ApiException {
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}
