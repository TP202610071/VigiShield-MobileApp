import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class AuthStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── JWT Token ──────────────────────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: AppConstants.tokenKey);

  // ── Server URL ─────────────────────────────────────────────────────────────
  // Persists the backend base URL so it works on real devices (not just emulator).

  Future<String?> getServerUrl() =>
      _storage.read(key: AppConstants.serverUrlKey);

  Future<void> saveServerUrl(String url) =>
      _storage.write(key: AppConstants.serverUrlKey, value: url);

  Future<void> deleteServerUrl() =>
      _storage.delete(key: AppConstants.serverUrlKey);

  // ── Language ───────────────────────────────────────────────────────────────

  Future<String?> getLocale() => _storage.read(key: AppConstants.localeKey);

  Future<void> saveLocale(String code) =>
      _storage.write(key: AppConstants.localeKey, value: code);

  // ── Developer role preview ──────────────────────────────────────────────────

  Future<String?> getPreviewRole() =>
      _storage.read(key: AppConstants.previewRoleKey);

  Future<void> savePreviewRole(String? role) => role == null
      ? _storage.delete(key: AppConstants.previewRoleKey)
      : _storage.write(key: AppConstants.previewRoleKey, value: role);
}
