import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../models/prayer_reflection_entry.dart';
import 'prayer_reflection_repository.dart';

class FirestorePrayerReflectionRepository
    implements PrayerReflectionRepository {
  FirestorePrayerReflectionRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Reflection] $message');
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sync');
  }

  String _syncDocId(String docId) {
    final safe = docId
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'prayer_reflection_${safe.isEmpty ? 'entry' : safe}';
  }

  @override
  Future<PrayerReflectionEntry?> loadReflection({
    required String uid,
    required String docId,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty || docId.isEmpty) {
      return null;
    }

    final syncDocId = _syncDocId(docId);
    final path = 'users/$uid/sync/$syncDocId';
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await _collection(uid).doc(syncDocId).get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return PrayerReflectionEntry.fromMap(
        data['originalDocId'] as String? ?? docId,
        data,
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
      return null;
    }
  }

  @override
  Future<bool> saveReflectionOnce({
    required String uid,
    required PrayerReflectionEntry entry,
  }) async {
    if (!_firebaseConfigured || uid.isEmpty || entry.docId.isEmpty) {
      _log('failed reason=config uidEmpty=${uid.isEmpty} docId=${entry.docId}');
      return false;
    }

    final syncDocId = _syncDocId(entry.docId);
    final ref = _collection(uid).doc(syncDocId);
    final path = 'users/$uid/sync/$syncDocId';
    FirestoreDebugLogger.attempt(
      path: path,
      operation: 'transaction(set-once)',
    );

    try {
      return FirebaseFirestore.instance
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(ref);
            if (snapshot.exists) {
              _log('failed reason=already-exists path=$path');
              return false;
            }
            transaction.set(ref, {
              ...entry.toFirestoreMap(),
              'originalDocId': entry.docId,
            });
            return true;
          })
          .then((saved) {
            FirestoreDebugLogger.success(
              path: path,
              operation: 'transaction(set-once)',
            );
            if (saved) {
              _log('success path=$path');
            }
            return saved;
          });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        _log('failed reason=permission-denied path=$path');
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'transaction(set-once)',
          error: error,
        );
      } else {
        _log('failed reason=${error.code} path=$path');
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'transaction(set-once)',
          error: error,
        );
      }
      return false;
    } catch (error) {
      _log('failed reason=$error path=$path');
      return false;
    }
  }
}
