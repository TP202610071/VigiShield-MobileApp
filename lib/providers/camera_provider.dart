import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/models/camera_config_model.dart';
import '../data/models/zone_model.dart';
import '../data/services/camera_service.dart';
import '../data/services/camera_lan_control.dart';
import 'session_scoped.dart';

class CameraProvider extends ChangeNotifier implements SessionScoped {
  final CameraDataService _service;

  CameraProvider(this._service);

  List<CameraConfigModel> _cameras = [];
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  /// Todas las que se pueden ver, incluido el video de ejemplo en curso.
  List<CameraConfigModel> get cameras => _cameras;

  /// Solo las cámaras del usuario (sin el video de ejemplo): «Mis cámaras»,
  /// filtros del historial y todo lo que se configura.
  List<CameraConfigModel> get misCamaras =>
      cameras.where((c) => !c.isSample).toList();

  /// Video de ejemplo en curso, si hay.
  CameraConfigModel? get ejemplo =>
      cameras.where((c) => c.isSample).firstOrNull;

  /// Lo pide quien inicia el video de ejemplo: la pestaña Cámara lo abre en
  /// modo IA para que se vea lo que detecta. Se consume una vez.
  bool abrirEnModoIa = false;

  /// Videos distintos que ya vio el hogar, de cuántos (para «Otro video»).
  int ejemplosVistos = 0, ejemplosTotal = 0;
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
    final selectedId = selectedCamera?.id;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _cameras = await _service.getCameras();
      _programarFinEjemplo();
      final previousIdx = selectedId == null
          ? -1
          : _cameras.indexWhere((c) => c.id == selectedId);
      if (previousIdx >= 0) {
        _selectedIndex = previousIdx;
      } else {
        final defaultIdx = _cameras.indexWhere((c) => c.isDefault);
        _selectedIndex = defaultIdx >= 0 ? defaultIdx : 0;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// La última cámara creada en esta sesión (para llevar a sus zonas).
  CameraConfigModel? ultimaCreada;

  Future<bool> createCamera(SaveCameraRequest req) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _service.createCamera(req);
      ultimaCreada = created;
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

  /// Enciende o apaga el procesamiento de IA de una camara.
  Future<bool> setActive(String id, bool enabled) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.setActive(id, enabled);
      _cameras = _cameras.map((c) => c.id == id ? updated : c).toList();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> setNotificationsEnabled(String id, bool enabled) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.setNotificationsEnabled(id, enabled);
      _cameras = _cameras.map((c) => c.id == id ? updated : c).toList();
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

  // ── Video de ejemplo ────────────────────────────────────────────────────────

  Timer? _finEjemplo;
  bool _iniciandoEjemplo = false;
  bool get iniciandoEjemplo => _iniciandoEjemplo;

  /// Pide un video de ejemplo y lo deja seleccionado.
  Future<bool> iniciarEjemplo({bool otro = false}) async {
    if (_iniciandoEjemplo) return false;
    _iniciandoEjemplo = true;
    _error = null;
    notifyListeners();
    try {
      final sesion = await _service.startSampleVideo(otro: otro);
      ejemplosVistos = sesion.seen;
      ejemplosTotal = sesion.total;
      _cameras = [
        ..._cameras.where((c) => !c.isSample && c.id != sesion.camera.id),
        sesion.camera,
      ];
      _selectedIndex = _cameras.length - 1;
      abrirEnModoIa = true;
      _programarFinEjemplo();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _iniciandoEjemplo = false;
      notifyListeners();
    }
  }

  /// Termina el video de ejemplo antes de tiempo.
  Future<void> terminarEjemplo() async {
    try {
      await _service.stopSampleVideo();
    } catch (_) {
      // Si falla, igual vence solo en unos minutos.
    }
    _quitarEjemplo();
  }

  /// Al vencer la sesión se quita de la lista: el backend ya no la devuelve
  /// y la IA deja de analizarla.
  void _programarFinEjemplo() {
    _finEjemplo?.cancel();
    final cam = ejemplo;
    if (cam == null) return;
    _finEjemplo = Timer(cam.sampleRemaining + const Duration(seconds: 1), _quitarEjemplo);
  }

  void _quitarEjemplo() {
    _finEjemplo?.cancel();
    final eraSeleccionado = selectedCamera?.isSample ?? false;
    if (!_cameras.any((c) => c.isSample)) return;
    _cameras = _cameras.where((c) => !c.isSample).toList();
    if (eraSeleccionado || _selectedIndex >= _cameras.length) {
      final principal = _cameras.indexWhere((c) => c.isDefault);
      _selectedIndex = principal >= 0 ? principal : 0;
    }
    abrirEnModoIa = false;
    notifyListeners();
  }

  // ── Live camera image/video controls (hi3510 CGI via backend) ───────────────

  /// Lee los ajustes de la cámara. Intenta primero por la red local (el único
  /// camino que funciona con el backend en la nube: una IP privada no se
  /// alcanza desde la VM) y solo si eso falla prueba por el servidor, que sí
  /// sirve si algún día el backend corre en la misma red que la cámara.
  /// Motivo del último fallo de control, para que la hoja diga qué hacer.
  CameraControlFailure lastControlFailure = CameraControlFailure.unreachable;

  Future<Map<String, String>?> loadCameraControls(String id) async {
    final lan = await _lanControl(id);
    if (lan != null) {
      try {
        return await lan.read();
      } on CameraLanAuthFailed catch (e) {
        _error = e.toString();
        lastControlFailure = CameraControlFailure.badCredentials;
        return null; // Reintentar por el servidor daría el mismo rechazo.
      } catch (e) {
        _error = e.toString();
        lastControlFailure = CameraControlFailure.unreachable;
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
      } on CameraLanAuthFailed catch (e) {
        _error = e.toString();
        lastControlFailure = CameraControlFailure.badCredentials;
        return false;
      } catch (e) {
        _error = e.toString();
        lastControlFailure = CameraControlFailure.unreachable;
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
  /// Borra todo lo de la sesión: las cámaras de una cuenta no deben quedar
  /// visibles al entrar con otra.
  @override
  void clearSession() {
    _finEjemplo?.cancel();
    abrirEnModoIa = false;
    _cameras = [];
    _selectedIndex = 0;
    _isLoading = false;
    _isSaving = false;
    _error = null;
    _lanCache.clear();
    lastControlFailure = CameraControlFailure.unreachable;
    notifyListeners();
  }


  @override
  void dispose() {
    _finEjemplo?.cancel();
    super.dispose();
  }
}

/// Por qué no se pudo controlar la cámara. Cada caso se arregla distinto.
enum CameraControlFailure { unreachable, badCredentials }
