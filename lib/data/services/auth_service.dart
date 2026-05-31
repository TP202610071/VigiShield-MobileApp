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

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _client.put('/api/auth/change-password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  Future<void> recoverPassword(String email) =>
      _client.post('/api/auth/recover-password', body: {'email': email});

  Future<void> logout() => _client.post('/api/auth/logout');
}
