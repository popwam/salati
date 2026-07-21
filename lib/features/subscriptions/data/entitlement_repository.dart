import '../../../core/models/feature_entitlement.dart';

abstract class EntitlementRepository {
  Stream<List<FeatureEntitlement>> watchUserEntitlements(String uid);
}
