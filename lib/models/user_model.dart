class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final double? commissionRate; // Campo Novo

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.commissionRate,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      commissionRate: (map['commissionRate'] ?? 0.0).toDouble(),
    );
  }
}