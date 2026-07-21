import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../../../core/models/app_user.dart';
import '../../../core/session/user_session_profile.dart';
import 'user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  @override
  Future<AppUser> ensureUserProfile({
    required String uid,
    required String defaultPlanId,
    String? email,
    String? name,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final userRef = _usersCollection.doc(uid);
    final path = 'users/$uid';
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      snapshot = await userRef.get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(path: path, operation: 'get', error: error);
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'get',
          error: error,
        );
      }
      rethrow;
    }

    if (!snapshot.exists) {
      try {
        FirestoreDebugLogger.attempt(path: path, operation: 'set');
        await userRef.set(
          _buildNewUserPayload(
            uid: uid,
            defaultPlanId: defaultPlanId,
            email: email,
            name: name,
          ),
        );
        FirestoreDebugLogger.success(path: path, operation: 'set');
        return AppUser(
          uid: uid,
          name: name?.trim().isNotEmpty == true ? name!.trim() : 'مستخدم جديد',
          email: email?.trim(),
          planId: defaultPlanId,
          subscriptionStatus: 'active',
          isAdmin: false,
          points: 0,
          isBlocked: false,
        );
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          FirestoreDebugLogger.denied(
            path: path,
            operation: 'set',
            error: error,
          );
        } else {
          FirestoreDebugLogger.failure(
            path: path,
            operation: 'set',
            error: error,
          );
        }
        rethrow;
      }
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final updates = _buildExistingUserUpdates(
      uid: uid,
      data: data,
      defaultPlanId: defaultPlanId,
      email: email,
      name: name,
    );

    if (updates.isNotEmpty) {
      try {
        FirestoreDebugLogger.attempt(path: path, operation: 'set(merge)');
        await userRef.set(updates, SetOptions(merge: true));
        FirestoreDebugLogger.success(path: path, operation: 'set(merge)');
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          FirestoreDebugLogger.denied(
            path: path,
            operation: 'set(merge)',
            error: error,
          );
        } else {
          FirestoreDebugLogger.failure(
            path: path,
            operation: 'set(merge)',
            error: error,
          );
        }
        rethrow;
      }
    }

    return AppUser.fromMap({
      ...data,
      ..._previewMergedUserState(data: data, updates: updates),
      'uid': snapshot.id,
    });
  }

  @override
  Future<UserSessionProfile?> loadUserSessionProfile({
    required String uid,
    required String defaultPlanId,
    String? fallbackEmail,
  }) async {
    if (uid.isEmpty) {
      return null;
    }

    if (!_firebaseConfigured) {
      return UserSessionProfile(
        uid: uid,
        email: fallbackEmail,
        role: 'user',
        planId: defaultPlanId,
        permissions: const <String>{},
      );
    }

    final path = 'users/$uid';
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await _usersCollection.doc(uid).get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      final data = snapshot.data() ?? const <String, dynamic>{};
      final email =
          _stringValue(data['email']) ??
          (fallbackEmail?.trim().isNotEmpty == true
              ? fallbackEmail!.trim()
              : null);

      return UserSessionProfile(
        uid: uid,
        email: email,
        role: _resolvedRole(data),
        planId: _resolvedPlanId(data, defaultPlanId: defaultPlanId),
        permissions: _resolvedPermissions(data),
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(path: path, operation: 'get', error: error);
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'get',
          error: error,
        );
      }
      rethrow;
    }
  }

  @override
  Stream<AppUser?> watchCurrentUser(String uid) {
    if (!_firebaseConfigured || uid.isEmpty) {
      return Stream<AppUser?>.value(null);
    }
    final path = 'users/$uid';
    FirestoreDebugLogger.attempt(path: path, operation: 'listen');

    return _usersCollection
        .doc(uid)
        .snapshots()
        .handleError((error) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            FirestoreDebugLogger.denied(
              path: path,
              operation: 'listen',
              error: error,
            );
            return;
          }
          FirestoreDebugLogger.failure(
            path: path,
            operation: 'listen',
            error: error,
          );
        })
        .map((snapshot) {
          FirestoreDebugLogger.success(path: path, operation: 'listen');
          if (!snapshot.exists) {
            return null;
          }

          return AppUser.fromMap({'uid': snapshot.id, ...?snapshot.data()});
        });
  }

  @override
  Stream<List<AppUser>> watchUsers() {
    if (!_firebaseConfigured) {
      return Stream<List<AppUser>>.value(const []);
    }
    const path = 'users';
    FirestoreDebugLogger.attempt(path: path, operation: 'listen');

    return _usersCollection
        .snapshots()
        .handleError((error) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            FirestoreDebugLogger.denied(
              path: path,
              operation: 'listen',
              error: error,
            );
            return;
          }
          FirestoreDebugLogger.failure(
            path: path,
            operation: 'listen',
            error: error,
          );
        })
        .map((snapshot) {
          FirestoreDebugLogger.success(path: path, operation: 'listen');
          return snapshot.docs
              .map((doc) => AppUser.fromMap({'uid': doc.id, ...doc.data()}))
              .toList();
        });
  }

  @override
  Future<void> updateUserAdminSettings({
    required String uid,
    String? planId,
    int? points,
    bool? isBlocked,
    int? aiUsageLimitOverride,
    bool clearAiUsageLimitOverride = false,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final path = 'users/$uid';
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (planId != null) {
      updates['planId'] = planId;
      updates['plan'] = planId;
    }
    if (points != null) {
      updates['points'] = points;
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

    FirestoreDebugLogger.attempt(path: path, operation: 'update');
    try {
      await _usersCollection.doc(uid).update(updates);
      FirestoreDebugLogger.success(path: path, operation: 'update');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'update',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'update',
          error: error,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> updateOwnProfile({
    required String uid,
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final cleanName = name?.trim();
    if (cleanName != null && cleanName.isNotEmpty) {
      updates['name'] = cleanName;
    }

    if (clearAvatar) {
      updates['avatarUrl'] = FieldValue.delete();
      updates['photoUrl'] = FieldValue.delete();
    } else if (avatarUrl?.trim().isNotEmpty == true) {
      final cleanAvatar = avatarUrl!.trim();
      updates['avatarUrl'] = cleanAvatar;
      updates['photoUrl'] = cleanAvatar;
    }

    if (updates.length == 1) {
      return;
    }

    final path = 'users/$uid';
    FirestoreDebugLogger.attempt(path: path, operation: 'update(profile)');
    try {
      await _usersCollection.doc(uid).update(updates);
      FirestoreDebugLogger.success(path: path, operation: 'update(profile)');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'update(profile)',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'update(profile)',
          error: error,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> adjustUserPoints({
    required String uid,
    required int delta,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final path = 'users/$uid';
    FirestoreDebugLogger.attempt(path: path, operation: 'update');
    try {
      final userDocument = _usersCollection.doc(uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocument);
        if (!snapshot.exists) {
          throw StateError('تعذر العثور على المستخدم المطلوب.');
        }
        final data = snapshot.data() ?? const <String, dynamic>{};
        final previousPoints = _intValue(data['points']) ?? 0;
        final nextPoints = previousPoints + delta;
        if (nextPoints < 0) {
          throw StateError('لا يمكن أن يصبح رصيد النقاط أقل من صفر.');
        }
        transaction.update(userDocument, {
          'points': nextPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      FirestoreDebugLogger.success(path: path, operation: 'update');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'update',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'update',
          error: error,
        );
      }
      rethrow;
    }
  }

  String _resolvedRole(Map<String, dynamic> data) {
    final role = _stringValue(data['role']);
    if (role != null) {
      return role;
    }
    return data['isAdmin'] == true ? 'admin' : 'user';
  }

  String _resolvedPlanId(
    Map<String, dynamic> data, {
    required String defaultPlanId,
  }) {
    return _stringValue(data['planId']) ??
        _stringValue(data['plan']) ??
        defaultPlanId;
  }

  Set<String> _resolvedPermissions(Map<String, dynamic> data) {
    return _stringSetValue(data['permissions']);
  }

  Map<String, dynamic> _buildNewUserPayload({
    required String uid,
    required String defaultPlanId,
    String? email,
    String? name,
  }) {
    return {
      'uid': uid,
      'name': name?.trim().isNotEmpty == true ? name!.trim() : 'مستخدم جديد',
      'email': email?.trim().isNotEmpty == true ? email!.trim() : null,
      'phone': null,
      'avatarUrl': null,
      'photoUrl': null,
      'role': 'user',
      'permissions': const <String>[],
      'plan': defaultPlanId,
      'planId': defaultPlanId,
      'subscriptionStatus': 'active',
      'points': 0,
      'isBlocked': false,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _buildExistingUserUpdates({
    required String uid,
    required Map<String, dynamic> data,
    required String defaultPlanId,
    String? email,
    String? name,
  }) {
    final updates = <String, dynamic>{};

    final resolvedPlanId = _resolvedPlanId(data, defaultPlanId: defaultPlanId);
    final resolvedPlan =
        _stringValue(data['plan']) ??
        _stringValue(data['planId']) ??
        defaultPlanId;

    if (!_hasStringValue(data['name']) && name?.trim().isNotEmpty == true) {
      updates['name'] = name!.trim();
    }
    if (!_hasStringValue(data['email']) && email?.trim().isNotEmpty == true) {
      updates['email'] = email!.trim();
    }
    if (!_hasStringValue(data['plan'])) {
      updates['plan'] = resolvedPlan;
    }
    if (!_hasStringValue(data['planId'])) {
      updates['planId'] = resolvedPlanId;
    }
    if (!_hasStringValue(data['subscriptionStatus'])) {
      updates['subscriptionStatus'] = 'active';
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }

    return updates;
  }

  Map<String, dynamic> _previewMergedUserState({
    required Map<String, dynamic> data,
    required Map<String, dynamic> updates,
  }) {
    final merged = <String, dynamic>{...data};
    for (final entry in updates.entries) {
      if (entry.value is FieldValue) {
        continue;
      }
      merged[entry.key] = entry.value;
    }
    return merged;
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

  Set<String> _stringSetValue(dynamic value) {
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
}
