class AuthSession {
  const AuthSession({
    required this.uid,
    required this.isAnonymous,
    required this.email,
  });

  final String uid;
  final bool isAnonymous;
  final String? email;
}
