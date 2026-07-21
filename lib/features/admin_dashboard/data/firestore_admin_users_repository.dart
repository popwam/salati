import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_admin_audit_logger.dart';
import 'admin_dashboard_functions.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_user_summary.dart';

class FirestoreAdminUsersRepository {
  FirestoreAdminUsersRepository({
    required bool firebaseConfigured,
    AdminDashboardFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? AdminDashboardFunctions();

  final bool _firebaseConfigured;
  final AdminDashboardFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Stream<List<AdminUserSummary>> watchUsers({int? limit}) {
    if (!_firebaseConfigured) {
      return Stream<List<AdminUserSummary>>.value(const []);
    }

    Query<Map<String, dynamic>> query = _usersCollection;
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(AdminUserSummary.fromDocument)
          .toList(growable: false);
    });
  }

  Future<void> updateUserSettings({
    required String uid,
    AdminUserPlan? plan,
    AdminDashboardRole? role,
    bool? isBlocked,
    int? aiUsageLimitOverride,
    bool clearAiUsageLimitOverride = false,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final userDocument = _usersCollection.doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocument);
      if (!snapshot.exists) {
        throw StateError('تعذر العثور على المستخدم المطلوب.');
      }

      final rawData = snapshot.data() ?? const <String, dynamic>{};
      final previousRole = adminDashboardRoleFromValue(
        _stringValue(rawData['role']),
        fallbackIsAdmin: rawData['isAdmin'] == true,
      );
      final previousRoleValue = adminDashboardRoleValue(previousRole);
      final previousPermissions = _permissionsFromValue(rawData['permissions']);
      final sortedPreviousPermissions = previousPermissions.toList()..sort();
      final previousPlanId =
          _stringValue(rawData['planId']) ??
          _stringValue(rawData['plan']) ??
          'free';
      final previousUserSettings = <String, dynamic>{
        'isBlocked': rawData['isBlocked'] == true,
        'aiUsageLimitOverride': _intValue(rawData['aiUsageLimitOverride']),
      };

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (plan != null) {
        final planId = adminUserPlanId(plan);
        updates['plan'] = planId;
        updates['planId'] = planId;
      }

      if (role != null) {
        final hasPermissionsField = rawData.containsKey('permissions');

        updates['role'] = adminDashboardRoleValue(role);
        updates['isAdmin'] = role != AdminDashboardRole.user;

        switch (role) {
          case AdminDashboardRole.user:
            updates['permissions'] = const <String>[];
            break;
          case AdminDashboardRole.admin:
            if (!hasPermissionsField || previousPermissions.isEmpty) {
              final defaultPermissions =
                  AdminDashboardPermission.adminDefaults.toList()..sort();
              updates['permissions'] = defaultPermissions;
            }
            break;
          case AdminDashboardRole.superAdmin:
            final allPermissions = AdminDashboardPermission.all.toList()
              ..sort();
            updates['permissions'] = allPermissions;
            break;
        }
      }

      if (isBlocked != null) {
        updates['isBlocked'] = isBlocked;
      }

      if (clearAiUsageLimitOverride) {
        updates['aiUsageLimitOverride'] = FieldValue.delete();
      } else if (aiUsageLimitOverride != null) {
        updates['aiUsageLimitOverride'] = aiUsageLimitOverride;
      }

      if (updates.length == 1) {
        return;
      }

      transaction.update(userDocument, updates);

      if (plan != null) {
        final nextPlanId = adminUserPlanId(plan);
        FirestoreAdminAuditLogger.writeLogInTransaction(
          transaction,
          action: 'change_plan',
          targetId: uid,
          before: {'plan': previousPlanId, 'planId': previousPlanId},
          after: {'plan': nextPlanId, 'planId': nextPlanId},
        );
      }

      if (role != null) {
        final nextPermissions = _resolveRolePermissionsAfterUpdate(
          role: role,
          previousPermissions: previousPermissions,
          hasPermissionsField: rawData.containsKey('permissions'),
        );

        FirestoreAdminAuditLogger.writeLogInTransaction(
          transaction,
          action: 'change_role',
          targetId: uid,
          before: {
            'role': previousRoleValue,
            'isAdmin': previousRole != AdminDashboardRole.user,
            'permissions': sortedPreviousPermissions,
          },
          after: {
            'role': adminDashboardRoleValue(role),
            'isAdmin': role != AdminDashboardRole.user,
            'permissions': nextPermissions,
          },
        );
      }

      if (isBlocked != null ||
          clearAiUsageLimitOverride ||
          aiUsageLimitOverride != null) {
        final nextUserSettings = <String, dynamic>{
          'isBlocked': isBlocked ?? previousUserSettings['isBlocked'],
          'aiUsageLimitOverride': clearAiUsageLimitOverride
              ? null
              : aiUsageLimitOverride ??
                    previousUserSettings['aiUsageLimitOverride'],
        };

        FirestoreAdminAuditLogger.writeLogInTransaction(
          transaction,
          action: 'update_user',
          targetId: uid,
          before: previousUserSettings,
          after: nextUserSettings,
        );
      }
    });
  }

  Future<void> updateUserStatus({
    required String uid,
    required bool isBlocked,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase is not configured or uid is invalid.');
    }
    await _functions.call(
      'updateDashboardUserStatus',
      data: {'uid': uid.trim(), 'isBlocked': isBlocked},
    );
  }

  Future<void> adjustUserPoints({
    required String uid,
    required int delta,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }
    if (delta == 0) {
      return;
    }

    final userDocument = _usersCollection.doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocument);
      if (!snapshot.exists) {
        throw StateError('تعذر العثور على المستخدم المطلوب.');
      }

      final previousPoints = _intValue(snapshot.data()?['points']) ?? 0;
      final nextPoints = previousPoints + delta;
      if (nextPoints < 0) {
        throw StateError('لا يمكن أن يصبح رصيد النقاط أقل من صفر.');
      }

      transaction.update(userDocument, {
        'points': nextPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'adjust_user_points',
        targetId: uid,
        before: {'points': previousPoints},
        after: {'points': nextPoints, 'delta': delta},
      );
    });
  }

  Future<void> updateUserPermissions({
    required String uid,
    required Set<String> permissions,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final sortedPermissions = permissions.toList()..sort();
    final userDocument = _usersCollection.doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocument);
      if (!snapshot.exists) {
        throw StateError('تعذر العثور على المستخدم المطلوب.');
      }

      final previousPermissions = _permissionsFromValue(
        snapshot.data()?['permissions'],
      ).toList()..sort();

      transaction.update(userDocument, {
        'permissions': sortedPermissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'change_permissions',
        targetId: uid,
        before: {'permissions': previousPermissions},
        after: {'permissions': sortedPermissions},
      );
    });
  }

  Set<String> _permissionsFromValue(dynamic value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }

  int? _intValue(dynamic value) {
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

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  List<String> _resolveRolePermissionsAfterUpdate({
    required AdminDashboardRole role,
    required Set<String> previousPermissions,
    required bool hasPermissionsField,
  }) {
    switch (role) {
      case AdminDashboardRole.user:
        return const <String>[];
      case AdminDashboardRole.admin:
        if (!hasPermissionsField || previousPermissions.isEmpty) {
          final defaults = AdminDashboardPermission.adminDefaults.toList()
            ..sort();
          return defaults;
        }
        final currentPermissions = previousPermissions.toList()..sort();
        return currentPermissions;
      case AdminDashboardRole.superAdmin:
        final allPermissions = AdminDashboardPermission.all.toList()..sort();
        return allPermissions;
    }
  }
}
