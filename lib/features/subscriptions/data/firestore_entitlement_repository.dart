import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../../../core/models/feature_entitlement.dart';
import 'entitlement_repository.dart';

class FirestoreEntitlementRepository implements EntitlementRepository {
  FirestoreEntitlementRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  @override
  Stream<List<FeatureEntitlement>> watchUserEntitlements(String uid) {
    if (!_firebaseConfigured || uid.isEmpty) {
      return Stream<List<FeatureEntitlement>>.value(const []);
    }
    final path = 'users/$uid/entitlements';
    FirestoreDebugLogger.attempt(path: path, operation: 'listen');

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('entitlements')
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
              .map(
                (doc) => FeatureEntitlement.fromMap({
                  'featureKey': doc.id,
                  ...doc.data(),
                }),
              )
              .toList();
        });
  }
}
