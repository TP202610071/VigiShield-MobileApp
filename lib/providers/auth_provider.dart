import 'package:flutter/foundation.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../core/storage/auth_storage.dart';
import '../core/network/api_client.dart';

enum AuthState { initial, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final AuthStorage _storage;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthProvider(this._authService, this._storage);

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

  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (_) {}
    await _storage.deleteToken();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
