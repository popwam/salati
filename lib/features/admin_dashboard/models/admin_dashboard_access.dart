enum AdminDashboardRole { user, admin, superAdmin }

AdminDashboardRole adminDashboardRoleFromValue(
  String? value, {
  bool fallbackIsAdmin = false,
}) {
  switch (value?.trim().toLowerCase()) {
    case 'admin':
      return AdminDashboardRole.admin;
    case 'superadmin':
    case 'super_admin':
    case 'super-admin':
      return AdminDashboardRole.superAdmin;
    default:
      return fallbackIsAdmin
          ? AdminDashboardRole.admin
          : AdminDashboardRole.user;
  }
}

String adminDashboardRoleLabel(AdminDashboardRole role) {
  switch (role) {
    case AdminDashboardRole.user:
      return 'User';
    case AdminDashboardRole.admin:
      return 'Admin';
    case AdminDashboardRole.superAdmin:
      return 'Super Admin';
  }
}

class AdminDashboardPermission {
  static const dashboardView = 'dashboard.view';
  static const usersManage = 'users.manage';
  static const usersPointsManage = 'users.points.manage';
  static const usersPlanManage = 'users.plan.manage';
  static const subscriptionsManage = 'subscriptions.manage';
  static const languagesManage = 'languages.manage';
  static const contentManage = 'content.manage';
  static const azkarManage = 'azkar.manage';
  static const duasManage = 'duas.manage';
  static const storeManage = 'store.manage';
  static const aiLimitsManage = 'ai_limits.manage';
  static const appConfigManage = 'app_config.manage';
  static const halaqatManage = 'halaqat.manage';

  static const all = <String>{dashboardView};

  static const adminDefaults = <String>{dashboardView};
}

class AdminDashboardAccess {
  const AdminDashboardAccess({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.isLocalMode = false,
  });

  final String uid;
  final String name;
  final String? email;
  final AdminDashboardRole role;
  final Set<String> permissions;
  final bool isLocalMode;

  bool get isSuperAdmin => role == AdminDashboardRole.superAdmin;

  bool get isPrimaryAdministrator => isSuperAdmin;

  bool get hasDashboardEntry =>
      isSuperAdmin ||
      role == AdminDashboardRole.admin ||
      permissions.contains(AdminDashboardPermission.dashboardView);

  Set<String> get effectivePermissions {
    if (hasDashboardEntry) {
      return AdminDashboardPermission.all;
    }
    return permissions;
  }

  bool get isPrivileged => hasDashboardEntry;

  bool get canOpenDashboardHome => hasDashboardEntry;

  bool can(String permission) {
    return hasDashboardEntry;
  }

  factory AdminDashboardAccess.fromDocument({
    required String uid,
    required Map<String, dynamic>? data,
  }) {
    return AdminDashboardAccess.fromResolvedAccess(
      uid: uid,
      data: data,
      resolvedPermissions: null,
    );
  }

  factory AdminDashboardAccess.fromResolvedAccess({
    required String uid,
    required Map<String, dynamic>? data,
    required Set<String>? resolvedPermissions,
  }) {
    final rawData = data ?? const <String, dynamic>{};
    final legacyIsAdmin = rawData['isAdmin'] == true;
    final role = adminDashboardRoleFromValue(
      rawData['role'] is String ? rawData['role'] as String : null,
      fallbackIsAdmin: legacyIsAdmin,
    );
    final rawName = rawData['name'] is String
        ? rawData['name'] as String
        : null;
    final rawDisplayName = rawData['displayName'] is String
        ? rawData['displayName'] as String
        : null;
    final rawEmail = rawData['email'] is String
        ? rawData['email'] as String
        : null;

    final finalPermissions =
        resolvedPermissions ??
        _resolvePermissions(
          role: role,
          rawPermissions: _stringSetFrom(rawData['permissions']),
        );

    return AdminDashboardAccess(
      uid: uid,
      name: _displayNameFor(
        name: rawName,
        displayName: rawDisplayName,
        email: rawEmail,
      ),
      email: rawEmail,
      role: role,
      permissions: finalPermissions,
    );
  }

  static Set<String> _stringSetFrom(dynamic value) {
    if (value == null) {
      return <String>{};
    }
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  static String _displayNameFor({
    required String? name,
    required String? displayName,
    required String? email,
  }) {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      return trimmedDisplayName;
    }

    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      final atIndex = trimmedEmail.indexOf('@');
      if (atIndex > 0) {
        return trimmedEmail.substring(0, atIndex);
      }
      return trimmedEmail;
    }

    return 'المشرف';
  }

  static Set<String> _resolvePermissions({
    required AdminDashboardRole role,
    required Set<String> rawPermissions,
  }) {
    if (role == AdminDashboardRole.superAdmin) {
      return {...rawPermissions};
    }

    return {...rawPermissions};
  }
}
