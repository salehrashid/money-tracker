class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });

  final String id;
  final String? email;
  final bool isEmailVerified;
}
