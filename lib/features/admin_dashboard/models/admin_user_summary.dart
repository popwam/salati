import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard_access.dart';

enum AdminUserPlan { free, pro, plus }

AdminUserPlan adminUserPlanFromValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'pro':
      return AdminUserPlan.pro;
    case 'plus':
      return AdminUserPlan.plus;
    default:
      return AdminUserPlan.free;
  }
}

String adminUserPlanId(AdminUserPlan plan) {
  switch (plan) {
    case AdminUserPlan.free:
      return 'free';
    case AdminUserPlan.pro:
      return 'pro';
    case AdminUserPlan.plus:
      return 'plus';
  }
}

String adminUserPlanLabel(AdminUserPlan plan) {
  switch (plan) {
    case AdminUserPlan.free:
      return 'Free';
    case AdminUserPlan.pro:
      return 'Pro';
    case AdminUserPlan.plus:
      return 'Plus';
  }
}

int adminUserPlanRank(AdminUserPlan plan) {
  switch (plan) {
    case AdminUserPlan.free:
      return 0;
    case AdminUserPlan.pro:
      return 1;
    case AdminUserPlan.plus:
      return 2;
  }
}

String adminDashboardRoleValue(AdminDashboardRole role) {
  switch (role) {
    case AdminDashboardRole.user:
      return 'user';
    case AdminDashboardRole.admin:
      return 'admin';
    case AdminDashboardRole.superAdmin:
      return 'superAdmin';
  }
}

class AdminUserSummary {
  const AdminUserSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.plan,
    required this.role,
    required this.points,
    required this.isBlocked,
    required this.aiUsageLimitOverride,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
  });

  final String uid;
  final String name;
  final String? email;
  final String? phone;
  final AdminUserPlan plan;
  final AdminDashboardRole role;
  final int points;
  final bool isBlocked;
  final int? aiUsageLimitOverride;
  final Set<String> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (email?.trim().isNotEmpty == true) {
      return email!.trim();
    }
    if (phone?.trim().isNotEmpty == true) {
      return phone!.trim();
    }
    return uid;
  }

  String get planId => adminUserPlanId(plan);

  bool get isPrivileged => role != AdminDashboardRole.user;

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) {
      return true;
    }

    final normalized = query.trim().toLowerCase();
    return displayName.toLowerCase().contains(normalized) ||
        (email?.toLowerCase().contains(normalized) ?? false) ||
        (phone?.toLowerCase().contains(normalized) ?? false);
  }

  factory AdminUserSummary.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final plan = adminUserPlanFromValue(
      _stringValue(data['plan']) ?? _stringValue(data['planId']),
    );
    final legacyIsAdmin = data['isAdmin'] == true;

    return AdminUserSummary(
      uid: document.id,
      name: _stringValue(data['name']) ?? '',
      email: _stringValue(data['email']),
      phone: _stringValue(data['phone']) ?? _stringValue(data['phoneNumber']),
      plan: plan,
      role: adminDashboardRoleFromValue(
        _stringValue(data['role']),
        fallbackIsAdmin: legacyIsAdmin,
      ),
      points: (_intValue(data['points']) ?? 0).clamp(0, 1 << 31).toInt(),
      isBlocked: data['isBlocked'] == true,
      aiUsageLimitOverride: _intValue(data['aiUsageLimitOverride']),
      permissions: _stringSetValue(data['permissions']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      lastLoginAt:
          _dateValue(data['lastLoginAt']) ??
          _dateValue(data['lastSignInAt']) ??
          _dateValue(data['lastSeenAt']) ??
          _dateValue(data['lastActiveAt']),
    );
  }

  static String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static Set<String> _stringSetValue(dynamic value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }
}
