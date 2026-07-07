class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String householdId;
  final String? whatsAppNumber;
  final String? avatarPath;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.householdId,
    this.whatsAppNumber,
    this.avatarPath,
    required this.createdAt,
  });

  /// Admin accounts inherit every primary-resident power.
  bool get isPrimary => role == 'Primary' || role == 'Admin';
  bool get isAdmin => role == 'Admin';

  /// Full avatar URL given the current server base, or null to fall back to initials.
  String? avatarUrl(String serverBaseUrl) {
    if (avatarPath == null || avatarPath!.isEmpty) return null;
    if (avatarPath!.startsWith('http')) return avatarPath;
    return '${serverBaseUrl.replaceAll(RegExp(r'/$'), '')}$avatarPath';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        householdId: json['householdId'] as String,
        whatsAppNumber: json['whatsAppNumber'] as String?,
        avatarPath: json['avatarPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A developer/administrator account (developer screen).
class AdminUser {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A household + its primary user, for the developer alert-trigger tool.
class HouseholdSummary {
  final String householdId;
  final String name;
  final String email;

  const HouseholdSummary({
    required this.householdId,
    required this.name,
    required this.email,
  });

  factory HouseholdSummary.fromJson(Map<String, dynamic> json) => HouseholdSummary(
        householdId: json['householdId'] as String,
        name: (json['name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
      );
}
