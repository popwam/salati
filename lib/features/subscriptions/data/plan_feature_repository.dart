import '../../../core/models/feature_entitlement.dart';

abstract class PlanFeatureRepository {
  Stream<List<FeatureEntitlement>> watchFeaturesForPlan(
    String planId, {
    bool includeDisabled = false,
  });

  Future<void> updateFeatureEnabled({
    required String planId,
    required String featureKey,
    required bool enabled,
  });
}
