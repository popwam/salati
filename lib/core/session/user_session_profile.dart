class UserSessionProfile {
  const UserSessionProfile({
    required this.uid,
    required this.email,
    required this.role,
    required this.planId,
    required this.permissions,
  });

  final String uid;
  final String? email;
  final String role;
  final String planId;
  final Set<String> permissions;
}
