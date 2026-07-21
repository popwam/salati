import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/plan.dart';

class EntitlementChecker {
  const EntitlementChecker();

  bool isEnabled({
    required String featureKey,
    required List<FeatureEntitlement> entitlements,
  }) {
    return entitlements.any(
      (item) => item.featureKey == featureKey && item.isActive,
    );
  }

  Plan? activePlanFor({required String planId, required List<Plan> plans}) {
    for (final plan in plans) {
      if (plan.id == planId) {
        return plan;
      }
    }

    return null;
  }
}
