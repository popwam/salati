import '../../../core/models/app_user.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/points_config.dart';

class SubscriptionState {
  const SubscriptionState({
    this.isLoading = true,
    this.error,
    this.currentUser,
    this.plans = const [],
    this.entitlements = const [],
    this.pointsRules = PointsRulesConfig.defaults,
    this.firebaseConfigured = false,
  });

  final bool isLoading;
  final String? error;
  final AppUser? currentUser;
  final List<Plan> plans;
  final List<FeatureEntitlement> entitlements;
  final PointsRulesConfig pointsRules;
  final bool firebaseConfigured;

  SubscriptionState copyWith({
    bool? isLoading,
    String? error,
    AppUser? currentUser,
    List<Plan>? plans,
    List<FeatureEntitlement>? entitlements,
    PointsRulesConfig? pointsRules,
    bool? firebaseConfigured,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentUser: currentUser ?? this.currentUser,
      plans: plans ?? this.plans,
      entitlements: entitlements ?? this.entitlements,
      pointsRules: pointsRules ?? this.pointsRules,
      firebaseConfigured: firebaseConfigured ?? this.firebaseConfigured,
    );
  }
}
