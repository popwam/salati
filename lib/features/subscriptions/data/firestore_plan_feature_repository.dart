import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../../../core/models/feature_entitlement.dart';
import 'plan_feature_repository.dart';

class FirestorePlanFeatureRepository implements PlanFeatureRepository {
  FirestorePlanFeatureRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  @override
  Stream<List<FeatureEntitlement>> watchFeaturesForPlan(
    String planId, {
    bool includeDisabled = false,
  }) {
    if (!_firebaseConfigured || planId.isEmpty) {
      return Stream<List<FeatureEntitlement>>.value(const []);
    }

    final path = includeDisabled
        ? 'plans/$planId/features'
        : 'plans/$planId/features[enabled=true]';
    FirestoreDebugLogger.attempt(path: path, operation: 'listen');

    final query = FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .collection('features');

    final effectiveQuery = includeDisabled
        ? query
        : query.where('enabled', isEqualTo: true);

    return effectiveQuery
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

  @override
  Future<void> updateFeatureEnabled({
    required String planId,
    required String featureKey,
    required bool enabled,
  }) async {
    if (!_firebaseConfigured || planId.isEmpty || featureKey.isEmpty) {
      throw StateError('Firebase غير مهيأ أو بيانات الميزة غير صالحة.');
    }
    final path = 'plans/$planId/features/$featureKey';
    FirestoreDebugLogger.attempt(path: path, operation: 'update');

    try {
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .collection('features')
          .doc(featureKey)
          .update({'enabled': enabled});
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
}
