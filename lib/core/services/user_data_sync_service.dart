import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_preferences.dart';

class UserDataSyncService {
  UserDataSyncService({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  DocumentReference<Map<String, dynamic>> _syncDocument(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sync')
        .doc('app_state');
  }

  Future<void> uploadLocalSnapshot({
    required String uid,
    required AppPreferences preferences,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase is not configured for user data sync.');
    }

    await _syncDocument(uid.trim()).set({
      ...preferences.exportSyncSnapshot(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> restoreRemoteSnapshot({
    required String uid,
    required AppPreferences preferences,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase is not configured for user data sync.');
    }

    final snapshot = await _syncDocument(uid.trim()).get();
    final data = snapshot.data();
    if (data == null) {
      return false;
    }

    await preferences.importSyncSnapshot(data);
    return true;
  }

  Future<DateTime?> remoteUpdatedAt(String uid) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return null;
    }

    final snapshot = await _syncDocument(uid.trim()).get();
    final data = snapshot.data();
    final timestamp = data?['serverUpdatedAt'];
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    final updatedAt = data?['updatedAt'];
    if (updatedAt is String) {
      return DateTime.tryParse(updatedAt);
    }
    return null;
  }
}
