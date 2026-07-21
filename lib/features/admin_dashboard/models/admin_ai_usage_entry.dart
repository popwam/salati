import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard_access.dart';

class AdminAiUsageEntry {
  const AdminAiUsageEntry({
    required this.uid,
    required this.name,
    required this.email,
    required this.planId,
    required this.role,
    required this.isBlocked,
    required this.aiUsageLimitOverride,
    required this.usedToday,
    required this.usageDailyLimit,
    required this.planDailyLimit,
    required this.resetDate,
    required this.userUpdatedAt,
    required this.usageUpdatedAt,
  });

  final String uid;
  final String name;
  final String? email;
  final String planId;
  final AdminDashboardRole role;
  final bool isBlocked;
  final int? aiUsageLimitOverride;
  final int usedToday;
  final int? usageDailyLimit;
  final int? planDailyLimit;
  final String? resetDate;
  final DateTime? userUpdatedAt;
  final DateTime? usageUpdatedAt;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (email?.trim().isNotEmpty == true) {
      return email!.trim();
    }
    return uid;
  }

  int get effectiveDailyLimit =>
      aiUsageLimitOverride ??
      usageDailyLimit ??
      planDailyLimit ??
      _fallbackPlanLimit(planId);

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) {
      return true;
    }

    final normalized = query.trim().toLowerCase();
    return displayName.toLowerCase().contains(normalized) ||
        (email?.toLowerCase().contains(normalized) ?? false) ||
        uid.toLowerCase().contains(normalized);
  }

  static int _fallbackPlanLimit(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'plus':
        return 100;
      case 'pro':
        return 50;
      default:
        return 5;
    }
  }

  static DateTime? dateValue(dynamic value) {
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

  static int? intValue(dynamic value) {
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

  static String? stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
