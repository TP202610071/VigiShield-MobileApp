import 'package:flutter/foundation.dart';
import '../data/models/camera_config_model.dart';
import '../data/models/zone_model.dart';
import '../data/services/camera_service.dart';
import '../data/services/camera_lan_control.dart';

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

  /// HLS URL for streaming — works on all platforms including over the internet.
  /// The AI backend keeps the MediaMTX HLS muxer warm so cold-start is instant.
  String? get streamViewUrl => selectedCamera?.hlsViewUrl;

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

  /// Guarda las zonas de interés (ROI) de una cámara y refresca la copia local.
  Future<bool> updateZones(String id, List<Zone> zones) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.updateZones(id, zones);
      final idx = _cameras.indexWhere((c) => c.id == id);
      if (idx >= 0) {
        final list = List<CameraConfigModel>.from(_cameras);
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

  // ── Live camera image/video controls (hi3510 CGI via backend) ───────────────

  /// Lee los ajustes de la cámara. Intenta primero por la red local (el único
  /// camino que funciona con el backend en la nube: una IP privada no se
  /// alcanza desde la VM) y solo si eso falla prueba por el servidor, que sí
  /// sirve si algún día el backend corre en la misma red que la cámara.
  Future<Map<String, String>?> loadCameraControls(String id) async {
    final lan = await _lanControl(id);
    if (lan != null) {
      try {
        return await lan.read();
      } catch (e) {
        _error = e.toString();
      }
    }
    try {
      return await _service.getCameraControls(id);
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  /// Aplica los ajustes, con la misma preferencia por la red local.
  Future<bool> applyCameraControls(String id, Map<String, String> settings) async {
    final lan = await _lanControl(id);
    if (lan != null) {
      try {
        await lan.apply(settings);
        return true;
      } catch (e) {
        _error = e.toString();
      }
    }
    try {
      await _service.updateCameraControls(id, settings);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Cachea el acceso a la cámara para no pedirlo en cada lectura y escritura.
  final Map<String, CameraLanControl> _lanCache = {};

  Future<CameraLanControl?> _lanControl(String id) async {
    final cacheado = _lanCache[id];
    if (cacheado != null) return cacheado;
    try {
      final acceso = await _service.getCameraLanAccess(id);
      if (acceso.ip.isEmpty) return null;
      return _lanCache[id] = CameraLanControl(acceso);
    } catch (_) {
      // Sin IP configurada (cámara CGNAT) o sin permiso: queda el backend.
      return null;
    }
  }
}
