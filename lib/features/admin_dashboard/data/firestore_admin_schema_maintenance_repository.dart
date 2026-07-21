import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin/data/app_config_repository.dart';
import '../../subscriptions/data/plan_repository.dart';
import 'firestore_admin_audit_logger.dart';
import '../models/admin_dashboard_access.dart';

class AdminMaintenanceActionResult {
  const AdminMaintenanceActionResult({
    required this.action,
    required this.affectedCount,
    required this.summary,
  });

  final String action;
  final int affectedCount;
  final Map<String, dynamic> summary;
}

class FirestoreAdminSchemaMaintenanceRepository {
  FirestoreAdminSchemaMaintenanceRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _rolesCollection =>
      FirebaseFirestore.instance.collection('roles');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Future<AdminMaintenanceActionResult> runSystemSync({
    required AppConfigRepository appConfigRepository,
    required PlanRepository planRepository,
  }) async {
    if (!_firebaseConfigured) {
      return const AdminMaintenanceActionResult(
        action: 'system_sync',
        affectedCount: 0,
        summary: <String, dynamic>{'firebaseConfigured': false},
      );
    }

    await appConfigRepository.ensureDefaults();
    await planRepository.ensureDefaults();
    await ensureRoleDocuments();
    final usersUpdated = await backfillUsersSchema();

    final summary = <String, dynamic>{
      'settingsEnsured': true,
      'plansEnsured': true,
      'rolesEnsured': 3,
      'usersUpdated': usersUpdated,
    };

    await FirestoreAdminAuditLogger.writeLog(
      action: 'system_sync',
      targetId: 'system',
      before: const <String, dynamic>{'status': 'requested'},
      after: summary,
    );

    return AdminMaintenanceActionResult(
      action: 'system_sync',
      affectedCount: usersUpdated,
      summary: summary,
    );
  }

  Future<void> ensureRoleDocuments() async {
    if (!_firebaseConfigured) {
      return;
    }

    await _ensureRoleDocument(
      roleId: 'user',
      title: 'User',
      description: 'Regular app user without dashboard access.',
      permissions: const <String>[],
    );
    await _ensureRoleDocument(
      roleId: 'admin',
      title: 'Admin',
      description: 'Standard dashboard administrator.',
      permissions: AdminDashboardPermission.adminDefaults.toList()..sort(),
    );
    await _ensureRoleDocument(
      roleId: 'superAdmin',
      title: 'Super Admin',
      description:
          'Full administrative access. Effective access does not depend on this document.',
      permissions: AdminDashboardPermission.adminDefaults.toList()..sort(),
    );
  }

  Future<int> backfillUsersSchema({
    String? onlyUserId,
    int batchSize = 200,
  }) async {
    if (!_firebaseConfigured) {
      return 0;
    }

    Query<Map<String, dynamic>> query = _usersCollection;
    if (onlyUserId != null && onlyUserId.trim().isNotEmpty) {
      query = query.where(FieldPath.documentId, isEqualTo: onlyUserId.trim());
    }

    var lastDocumentId = '';
    var updatedUsers = 0;

    while (true) {
      Query<Map<String, dynamic>> pageQuery = query.limit(batchSize);
      if (lastDocumentId.isNotEmpty) {
        final lastSnapshot = await _usersCollection.doc(lastDocumentId).get();
        if (!lastSnapshot.exists) {
          break;
        }
        pageQuery = pageQuery.startAfterDocument(lastSnapshot);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = FirebaseFirestore.instance.batch();
      var hasWrites = false;

      for (final document in snapshot.docs) {
        final updates = _buildUserBackfillUpdates(
          uid: document.id,
          data: document.data(),
        );
        if (updates.isEmpty) {
          continue;
        }
        batch.update(document.reference, updates);
        hasWrites = true;
        updatedUsers += 1;
      }

      if (hasWrites) {
        await batch.commit();
      }

      if (snapshot.docs.length < batchSize) {
        break;
      }
      lastDocumentId = snapshot.docs.last.id;
    }

    return updatedUsers;
  }

  Future<AdminMaintenanceActionResult> rebuildPermissionsCache({
    String? onlyUserId,
    int batchSize = 200,
  }) async {
    if (!_firebaseConfigured) {
      return const AdminMaintenanceActionResult(
        action: 'rebuild_permissions_cache',
        affectedCount: 0,
        summary: <String, dynamic>{'firebaseConfigured': false},
      );
    }

    await ensureRoleDocuments();
    final backfilledUsers = await backfillUsersSchema(
      onlyUserId: onlyUserId,
      batchSize: batchSize,
    );

    Query<Map<String, dynamic>> query = _usersCollection;
    if (onlyUserId != null && onlyUserId.trim().isNotEmpty) {
      query = query.where(FieldPath.documentId, isEqualTo: onlyUserId.trim());
    }

    var lastDocumentId = '';
    var updatedUsers = 0;

    while (true) {
      Query<Map<String, dynamic>> pageQuery = query.limit(batchSize);
      if (lastDocumentId.isNotEmpty) {
        final lastSnapshot = await _usersCollection.doc(lastDocumentId).get();
        if (!lastSnapshot.exists) {
          break;
        }
        pageQuery = pageQuery.startAfterDocument(lastSnapshot);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = FirebaseFirestore.instance.batch();
      var hasWrites = false;

      for (final document in snapshot.docs) {
        final updates = _buildPermissionsCacheUpdates(data: document.data());
        if (updates.isEmpty) {
          continue;
        }
        batch.update(document.reference, updates);
        hasWrites = true;
        updatedUsers += 1;
      }

      if (hasWrites) {
        await batch.commit();
      }

      if (snapshot.docs.length < batchSize) {
        break;
      }
      lastDocumentId = snapshot.docs.last.id;
    }

    final summary = <String, dynamic>{
      'backfilledUsers': backfilledUsers,
      'permissionsUpdated': updatedUsers,
      'target': onlyUserId?.trim().isNotEmpty == true
          ? onlyUserId!.trim()
          : 'all_users',
    };

    await FirestoreAdminAuditLogger.writeLog(
      action: 'rebuild_permissions_cache',
      targetId: onlyUserId?.trim().isNotEmpty == true
          ? onlyUserId!.trim()
          : 'users',
      before: const <String, dynamic>{'status': 'requested'},
      after: summary,
    );

    return AdminMaintenanceActionResult(
      action: 'rebuild_permissions_cache',
      affectedCount: updatedUsers,
      summary: summary,
    );
  }

  Future<AdminMaintenanceActionResult> resetAllAiUsage({
    int batchSize = 200,
    String? resetDate,
  }) async {
    if (!_firebaseConfigured) {
      return const AdminMaintenanceActionResult(
        action: 'reset_ai_usage',
        affectedCount: 0,
        summary: <String, dynamic>{'firebaseConfigured': false},
      );
    }

    final nextResetDate = resetDate ?? _formatDateOnly(DateTime.now());
    var lastDocumentId = '';
    var affectedUsers = 0;

    while (true) {
      Query<Map<String, dynamic>> pageQuery = _usersCollection.limit(batchSize);
      if (lastDocumentId.isNotEmpty) {
        final lastSnapshot = await _usersCollection.doc(lastDocumentId).get();
        if (!lastSnapshot.exists) {
          break;
        }
        pageQuery = pageQuery.startAfterDocument(lastSnapshot);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final document in snapshot.docs) {
        batch.set(
          document.reference.collection('usage').doc('ai'),
          {
            'usedToday': 0,
            'resetDate': nextResetDate,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        affectedUsers += 1;
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) {
        break;
      }
      lastDocumentId = snapshot.docs.last.id;
    }

    final summary = <String, dynamic>{
      'affectedUsers': affectedUsers,
      'resetDate': nextResetDate,
    };

    await FirestoreAdminAuditLogger.writeLog(
      action: 'reset_ai_usage',
      targetId: 'users',
      before: const <String, dynamic>{'status': 'requested'},
      after: summary,
    );

    return AdminMaintenanceActionResult(
      action: 'reset_ai_usage',
      affectedCount: affectedUsers,
      summary: summary,
    );
  }

  Future<void> _ensureRoleDocument({
    required String roleId,
    required String title,
    required String description,
    required List<String> permissions,
  }) async {
    final roleDocument = _rolesCollection.doc(roleId);
    final snapshot = await roleDocument.get();
    final existing = snapshot.data() ?? const <String, dynamic>{};

    final sortedPermissions = [...permissions]..sort();
    final updates = <String, dynamic>{};

    if (!snapshot.exists) {
      updates.addAll({
        'id': roleId,
        'title': title,
        'description': description,
        'permissions': sortedPermissions,
        'isSystem': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await roleDocument.set(updates, SetOptions(merge: true));
      return;
    }

    if (!_hasStringValue(existing['id'])) {
      updates['id'] = roleId;
    }
    if (!_hasStringValue(existing['title'])) {
      updates['title'] = title;
    }
    if (!_hasStringValue(existing['description'])) {
      updates['description'] = description;
    }
    if (existing['permissions'] is! Iterable) {
      updates['permissions'] = sortedPermissions;
    }
    if (existing['isSystem'] != true) {
      updates['isSystem'] = true;
    }
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await roleDocument.set(updates, SetOptions(merge: true));
    }
  }

  Map<String, dynamic> _buildUserBackfillUpdates({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final updates = <String, dynamic>{};

    final role =
        _stringValue(data['role']) ??
        (data['isAdmin'] == true ? 'admin' : 'user');
    final isAdmin = data['isAdmin'] == true || role != 'user';
    final permissions = data['permissions'] is Iterable
        ? data['permissions']
        : const <String>[];
    final planId =
        _stringValue(data['planId']) ?? _stringValue(data['plan']) ?? 'free';
    final plan =
        _stringValue(data['plan']) ?? _stringValue(data['planId']) ?? 'free';

    if (!_hasStringValue(data['uid'])) {
      updates['uid'] = uid;
    }
    if (!_hasStringValue(data['role'])) {
      updates['role'] = role;
    }
    if (data['permissions'] is! Iterable) {
      updates['permissions'] = permissions;
    }
    if (data['isBlocked'] == null) {
      updates['isBlocked'] = false;
    }
    if (data['isAdmin'] == null) {
      updates['isAdmin'] = isAdmin;
    }
    if (data['points'] == null) {
      updates['points'] = 0;
    }
    if (!_hasStringValue(data['plan'])) {
      updates['plan'] = plan;
    }
    if (!_hasStringValue(data['planId'])) {
      updates['planId'] = planId;
    }
    if (!_hasStringValue(data['subscriptionStatus'])) {
      updates['subscriptionStatus'] = 'active';
    }
    if (!data.containsKey('aiUsageLimitOverride')) {
      updates['aiUsageLimitOverride'] = null;
    }

    final createdAtTimestamp = _timestampFromDynamic(data['createdAt']);
    if (createdAtTimestamp != null && data['createdAt'] is! Timestamp) {
      updates['createdAt'] = createdAtTimestamp;
    } else if (data['createdAt'] == null) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    final updatedAtTimestamp = _timestampFromDynamic(data['updatedAt']);
    if (updatedAtTimestamp != null && data['updatedAt'] is! Timestamp) {
      updates['updatedAt'] = updatedAtTimestamp;
    } else {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }

    return updates;
  }

  Map<String, dynamic> _buildPermissionsCacheUpdates({
    required Map<String, dynamic> data,
  }) {
    final role =
        _stringValue(data['role']) ??
        (data['isAdmin'] == true ? 'admin' : 'user');
    final normalizedPermissions = _normalizedPermissions(data['permissions']);

    late final List<String> nextPermissions;
    switch (role) {
      case 'admin':
        nextPermissions = normalizedPermissions.isEmpty
            ? (AdminDashboardPermission.adminDefaults.toList()..sort())
            : normalizedPermissions;
        break;
      case 'superAdmin':
        nextPermissions = normalizedPermissions;
        break;
      default:
        nextPermissions = const <String>[];
        break;
    }

    final currentPermissions = data['permissions'];
    if (_sameStringLists(normalizedPermissions, nextPermissions) &&
        currentPermissions is Iterable) {
      return const <String, dynamic>{};
    }

    return <String, dynamic>{
      'permissions': nextPermissions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool _hasStringValue(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  List<String> _normalizedPermissions(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    final permissions =
        value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return permissions;
  }

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Timestamp? _timestampFromDynamic(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }
}
