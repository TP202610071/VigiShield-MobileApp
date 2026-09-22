import '../../core/network/api_client.dart';

/// Residente secundario del hogar (acceso de solo lectura).
class SecondaryUser {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  const SecondaryUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory SecondaryUser.fromJson(Map<String, dynamic> j) => SecondaryUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Datos de una invitación, para mostrarlos ANTES de pedir la contraseña.
class InvitationInfo {
  final bool valid;
  final String? reason; // no_existe | ya_usada | caducada
  final String? email;
  final String? invitedBy;
  final String? householdAddress;

  const InvitationInfo({
    required this.valid,
    this.reason,
    this.email,
    this.invitedBy,
    this.householdAddress,
  });

  factory InvitationInfo.fromJson(Map<String, dynamic> j) => InvitationInfo(
        valid: j['valid'] as bool,
        reason: j['reason'] as String?,
        email: j['email'] as String?,
        invitedBy: j['invitedBy'] as String?,
        householdAddress: j['householdAddress'] as String?,
      );
}

class UserService {
  final ApiClient _client;
  UserService(this._client);

  Future<List<SecondaryUser>> getSecondaryUsers() async {
    final data = await _client.get<List<dynamic>>('/api/users');
    return data
        .map((e) => SecondaryUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Invita por correo. El backend envía el mensaje con el enlace; aquí no se
  /// maneja el token, precisamente para que no pueda compartirse por otra vía.
  Future<void> invite(String email) =>
      _client.post('/api/users/invite', body: {'email': email});

  Future<void> revoke(String userId) =>
      _client.delete('/api/users/$userId/revoke');

  // ── Sin sesión (quien acepta todavía no tiene cuenta) ──────────────────────

  Future<InvitationInfo> getInvitation(String token) async {
    final data = await _client.get<Map<String, dynamic>>('/api/users/invitation/$token');
    return InvitationInfo.fromJson(data);
  }

  Future<void> acceptInvitation(String token, String name, String password) =>
      _client.post('/api/users/accept-invitation',
          body: {'token': token, 'name': name, 'password': password});
}
