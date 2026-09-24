import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../core/storage/auth_storage.dart';
import '../core/network/api_client.dart';
import 'session_scoped.dart';

enum AuthState { initial, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final AuthStorage _storage;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthProvider(this._authService, this._storage);

  /// Almacen cifrado de la sesion. Lo usa el bloqueo biometrico para
  /// guardar su bandera junto al token, no en preferencias en claro.
  AuthStorage get storage => _storage;

  AuthState get state => _state;
  UserModel? get user => _user;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isInitial => _state == AuthState.initial;
  String? get errorMessage => _errorMessage;

  /// Exposed so screens can call one-off auth endpoints (e.g. recoverPassword).
  AuthService get service => _authService;

  Future<void> tryRestoreSession() async {
    final token = await _storage.getToken();
    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await _authService.getMe();
      _state = AuthState.authenticated;
    } catch (_) {
      await _storage.deleteToken();
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    try {
      final result = await _authService.login(email, password);
      await _storage.saveToken(result.token);
      // Se vacía ANTES de entrar: si la cuenta anterior dejó cámaras o eventos
      // cargados, se verían un instante (o hasta la primera recarga) como si
      // fueran de la cuenta nueva.
      _clearSessionData();
      _user = result.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String householdAddress,
  }) async {
    _errorMessage = null;
    try {
      final result = await _authService.register(
        email: email,
        password: password,
        name: name,
        householdAddress: householdAddress,
      );
      await _storage.saveToken(result.token);
      // Se vacía ANTES de entrar: si la cuenta anterior dejó cámaras o eventos
      // cargados, se verían un instante (o hasta la primera recarga) como si
      // fueran de la cuenta nueva.
      _clearSessionData();
      _user = result.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Providers con datos de la sesión, que hay que vaciar al cerrarla.
  ///
  /// Viven toda la vida de la app, así que sin esto las cámaras y los eventos
  /// de una cuenta seguían visibles al entrar con otra.
  final List<SessionScoped> _sessionScoped = [];

  void registerSessionScoped(Iterable<SessionScoped> providers) {
    _sessionScoped
      ..clear()
      ..addAll(providers);
  }

  void _clearSessionData() {
    for (final p in _sessionScoped) {
      p.clearSession();
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    await _storage.deleteToken();
    _user = null;
    _state = AuthState.unauthenticated;
    _clearSessionData();
    notifyListeners();
  }

  /// Re-fetch the current user (e.g. after a role/profile change elsewhere).
  Future<void> refreshUser() async {
    try {
      _user = await _authService.getMe();
      notifyListeners();
    } catch (_) {/* keep the cached user */}
  }

  Future<bool> uploadAvatar(File file) async {
    _errorMessage = null;
    try {
      _user = await _authService.uploadAvatar(file);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({required String name, String? whatsAppNumber}) async {
    _errorMessage = null;
    try {
      _user = await _authService.updateProfile(
          name: name, whatsAppNumber: whatsAppNumber);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String current, String next) async {
    _errorMessage = null;
    try {
      await _authService.changePassword(current, next);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Restablece la contraseña con el token del correo (sin sesión previa).
  Future<bool> resetPassword(String token, String newPassword) async {
    _errorMessage = null;
    try {
      await _authService.resetPassword(token, newPassword);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
