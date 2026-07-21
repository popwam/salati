import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_dashboard_summary.dart';
import '../models/admin_user_summary.dart';

class FirestoreAdminDashboardSummaryRepository {
  FirestoreAdminDashboardSummaryRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  Stream<AdminDashboardSummary> watchSummary() {
    if (!_firebaseConfigured) {
      return Stream<AdminDashboardSummary>.value(
        const AdminDashboardSummary(
          totalUsers: 0,
          activeUsersToday: 0,
          activeUsersLast7Days: 0,
          premiumUsers: 0,
          blockedUsers: 0,
          adminUsers: 0,
          usersWithAiLimitOverride: 0,
          totalPrayerPoints: 0,
          totalDhikrCategories: 0,
          totalDuas: 0,
          totalStoreItems: 0,
          availableAiTokens: 210210,
        ),
      );
    }

    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .asyncMap((usersSnapshot) async {
          final users = usersSnapshot.docs
              .map(AdminUserSummary.fromDocument)
              .toList(growable: false);
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final last7Days = now.subtract(const Duration(days: 7));

          final counts = await Future.wait<int>([
            _countCollection('content/adhkar/categories'),
            _countCollection('content/dua/categories'),
            _countCollection('store_items'),
          ]);
          final availableAiTokens = await _readAvailableAiTokens();

          return AdminDashboardSummary(
            totalUsers: users.length,
            activeUsersToday: users
                .where(
                  (user) => _activityDate(user)?.isAfter(todayStart) ?? false,
                )
                .length,
            activeUsersLast7Days: users
                .where(
                  (user) => _activityDate(user)?.isAfter(last7Days) ?? false,
                )
                .length,
            premiumUsers: users
                .where((user) => user.plan != AdminUserPlan.free)
                .length,
            blockedUsers: users.where((user) => user.isBlocked).length,
            adminUsers: users.where((user) => user.isPrivileged).length,
            usersWithAiLimitOverride: users
                .where((user) => user.aiUsageLimitOverride != null)
                .length,
            totalPrayerPoints: users.fold<int>(
              0,
              (total, user) => total + user.points,
            ),
            totalDhikrCategories: counts[0],
            totalDuas: counts[1],
            totalStoreItems: counts[2],
            availableAiTokens: availableAiTokens,
          );
        })
        .handleError((_) {
          return const AdminDashboardSummary(
            totalUsers: 0,
            activeUsersToday: 0,
            activeUsersLast7Days: 0,
            premiumUsers: 0,
            blockedUsers: 0,
            adminUsers: 0,
            usersWithAiLimitOverride: 0,
            totalPrayerPoints: 0,
            totalDhikrCategories: 0,
            totalDuas: 0,
            totalStoreItems: 0,
            availableAiTokens: 210210,
          );
        });
  }

  DateTime? _activityDate(AdminUserSummary user) {
    return user.lastLoginAt ?? user.updatedAt ?? user.createdAt;
  }

  Future<int> _countCollection(String path) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(path)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _readAvailableAiTokens() async {
    for (final path in [
      'settings/app_config',
      'remote_app_config/published',
      'remote_app_config/draft',
    ]) {
      try {
        final snapshot = await FirebaseFirestore.instance.doc(path).get();
        final data = snapshot.data();
        final value =
            data?['availableAiTokens'] ??
            data?['aiDailyLimit'] ??
            data?['tokenBudget'];
        final parsed = _intValue(value);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Try the next config document.
      }
    }
    return 210210;
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.truncate();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
