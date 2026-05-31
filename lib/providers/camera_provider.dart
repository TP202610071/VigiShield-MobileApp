import 'package:flutter/foundation.dart';
import '../data/models/camera_config_model.dart';
import '../data/services/camera_service.dart';

class CameraProvider extends ChangeNotifier {
  final CameraDataService _service;

  CameraProvider(this._service);

  List<CameraConfigModel> _cameras = [];
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<CameraConfigModel> get cameras => _cameras;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// The camera currently shown in the stream view.
  CameraConfigModel? get selectedCamera =>
      _cameras.isEmpty ? null : _cameras[_selectedIndex.clamp(0, _cameras.length - 1)];

  /// HLS URL for the currently selected camera.
  String? get hlsViewUrl => selectedCamera?.hlsViewUrl;

  bool get hasMultipleCameras => _cameras.length > 1;

  /// Switch to a camera by its list index.
  void selectCamera(int index) {
    if (index < 0 || index >= _cameras.length) return;
    _selectedIndex = index;
    notifyListeners();
  }

  /// Switch to a camera by its ID.
  void selectCameraById(String id) {
    final idx = _cameras.indexWhere((c) => c.id == id);
    if (idx >= 0) selectCamera(idx);
  }

  Future<void> fetchCameras() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cameras = await _service.getCameras();
      // Auto-select the default camera
      final defaultIdx = _cameras.indexWhere((c) => c.isDefault);
      _selectedIndex = defaultIdx >= 0 ? defaultIdx : 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCamera(SaveCameraRequest req) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _service.createCamera(req);
      _cameras = [..._cameras, created];
      if (created.isDefault) selectCameraById(created.id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateCamera(String id, SaveCameraRequest req) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateCamera(id, req);
      final idx = _cameras.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final list = List<CameraConfigModel>.from(_cameras);
        // If this camera is now the default, clear default on others
        if (updated.isDefault) {
          for (int i = 0; i < list.length; i++) {
            if (list[i].id != id && list[i].isDefault) {
              list[i] = CameraConfigModel.fromJson({
                ...list[i] as dynamic,
                'isDefault': false,
              });
            }
          }
        }
        list[idx] = updated;
        _cameras = list;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCamera(String id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _service.deleteCamera(id);
      _cameras = _cameras.where((c) => c.id != id).toList();
      _selectedIndex = _selectedIndex.clamp(0, (_cameras.length - 1).clamp(0, 999));
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
