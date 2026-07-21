import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/models/feature_entitlement.dart';
import 'package:salati/core/models/plan.dart';
import 'package:salati/features/subscriptions/domain/entitlement_checker.dart';

void main() {
  const checker = EntitlementChecker();

  test('returns enabled feature when entitlement exists', () {
    final result = checker.isEnabled(
      featureKey: 'advanced_adhkar',
      entitlements: const [
        FeatureEntitlement(
          featureKey: 'advanced_adhkar',
          enabled: true,
          source: 'plan:pro',
        ),
      ],
    );

    expect(result, isTrue);
  });

  test('finds active plan by plan id', () {
    final plan = checker.activePlanFor(
      planId: 'plus',
      plans: const [
        Plan(id: 'free', name: 'مجاني', priceLabel: '0', isActive: true),
        Plan(id: 'plus', name: 'بلس', priceLabel: '39', isActive: true),
      ],
    );

    expect(plan?.id, 'plus');
  });
}
