class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });
}
