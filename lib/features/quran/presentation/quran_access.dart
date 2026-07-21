import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/plan.dart';
import '../../../core/services/app_services.dart';
import '../../auth/models/auth_session.dart';

typedef QuranAccessWidgetBuilder =
    Widget Function(BuildContext context, QuranAccessState access);

class QuranAccessState {
  const QuranAccessState({
    required this.session,
    required this.currentUser,
    required this.currentPlan,
    required this.plansLoaded,
    required this.entitlements,
  });

  final AuthSession? session;
  final AppUser? currentUser;
  final Plan? currentPlan;
  final bool plansLoaded;
  final List<FeatureEntitlement> entitlements;

  bool get hasAyahAccess =>
      _isFeatureEnabled('quran_ayah_mode') ||
      _isFeatureEnabled('quran_modes') ||
      (currentPlan == null
          ? !plansLoaded && _fallbackQuranModes
          : currentPlan!.isActive && currentPlan!.allowQuranAyahMode);

  bool get hasWordAccess =>
      _isFeatureEnabled('quran_word_mode') ||
      _isFeatureEnabled('quran_modes') ||
      (currentPlan == null
          ? !plansLoaded && _fallbackQuranModes
          : currentPlan!.isActive && currentPlan!.allowQuranWordMode);

  bool get hasPaidAccess => hasAyahAccess || hasWordAccess;

  bool get hasPlusAccess =>
      _isFeatureEnabled('quran_ai') ||
      (currentPlan == null
          ? !plansLoaded && currentUser?.plan == UserPlanType.plus
          : currentPlan!.isActive && currentPlan!.allowQuranAi);

  bool get _fallbackQuranModes =>
      currentUser?.plan == UserPlanType.pro ||
      currentUser?.plan == UserPlanType.plus;

  bool _isFeatureEnabled(String featureKey) {
    return entitlements.any(
      (item) => item.featureKey == featureKey && item.isActive,
    );
  }
}

class QuranAccessBuilder extends StatelessWidget {
  const QuranAccessBuilder({
    super.key,
    required this.services,
    required this.builder,
  });

  final AppServices services;
  final QuranAccessWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;
        if (session == null) {
          return builder(
            context,
            const QuranAccessState(
              session: null,
              currentUser: null,
              currentPlan: null,
              plansLoaded: false,
              entitlements: [],
            ),
          );
        }

        return StreamBuilder<AppUser?>(
          stream: services.userProfileRepository.watchCurrentUser(session.uid),
          builder: (context, userSnapshot) {
            final currentUser = userSnapshot.data;
            return StreamBuilder<List<FeatureEntitlement>>(
              stream: services.entitlementRepository.watchUserEntitlements(
                session.uid,
              ),
              builder: (context, entitlementSnapshot) {
                return StreamBuilder<List<Plan>>(
                  stream: services.planRepository.watchPlans(),
                  builder: (context, planSnapshot) {
                    final currentPlan = services.entitlementChecker
                        .activePlanFor(
                          planId: currentUser?.effectivePlanId ?? 'free',
                          plans: planSnapshot.data ?? const [],
                        );

                    return builder(
                      context,
                      QuranAccessState(
                        session: session,
                        currentUser: currentUser,
                        currentPlan: currentPlan,
                        plansLoaded: planSnapshot.hasData,
                        entitlements: entitlementSnapshot.data ?? const [],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
