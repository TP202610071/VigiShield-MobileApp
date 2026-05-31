class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String householdId;
  final String? whatsAppNumber;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.householdId,
    this.whatsAppNumber,
    required this.createdAt,
  });

  bool get isPrimary => role == 'Primary';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        householdId: json['householdId'] as String,
        whatsAppNumber: json['whatsAppNumber'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
