import 'dart:io';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../../core/network/api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<({String token, UserModel user})> login(String email, String password) async {
    final data = await _client.post<Map<String, dynamic>>('/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<({String token, UserModel user})> register({
    required String email,
    required String password,
    required String name,
    required String householdAddress,
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/api/auth/register', body: {
      'email': email,
      'password': password,
      'name': name,
      'householdAddress': householdAddress,
    });
    return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<UserModel> getMe() async {
    final data = await _client.get<Map<String, dynamic>>('/api/auth/me');
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateProfile({required String name, String? whatsAppNumber, String? fcmToken}) async {
    final data = await _client.put<Map<String, dynamic>>('/api/auth/profile', body: {
      'name': name,
      if (whatsAppNumber != null) 'whatsAppNumber': whatsAppNumber,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
    return UserModel.fromJson(data);
  }

  Future<UserModel> uploadAvatar(File file) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(RegExp(r'[\\/]')).last,
      ),
    });
    final data =
        await _client.postMultipart<Map<String, dynamic>>('/api/auth/avatar', form);
    return UserModel.fromJson(data);
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _client.put('/api/auth/change-password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  Future<void> recoverPassword(String email) =>
      _client.post('/api/auth/recover-password', body: {'email': email});

  Future<void> logout() => _client.post('/api/auth/logout');

  // ── Admin management (developer screen) ─────────────────────────────────────

  Future<List<AdminUser>> getAdmins() async {
    final data = await _client.get<List<dynamic>>('/api/users/admins');
    return data.map((j) => AdminUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<AdminUser> addAdmin(String email) async {
    final data = await _client
        .post<Map<String, dynamic>>('/api/users/admins', body: {'email': email});
    return AdminUser.fromJson(data);
  }

  Future<void> removeAdmin(String id) => _client.delete('/api/users/admins/$id');

  // ── Developer alert-trigger tool (Admin only) ───────────────────────────────

  Future<List<HouseholdSummary>> searchHouseholds(String query) async {
    final data = await _client.get<List<dynamic>>(
        '/api/users/households', queryParams: {'query': query});
    return data
        .map((j) => HouseholdSummary.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Trigger a real alert for any household (saved + notified + shown in the app).
  Future<void> simulateEvent(String householdId, String eventType) =>
      _client.post('/api/events/simulate', body: {
        'householdId': householdId,
        'eventType': eventType,
      });
}
