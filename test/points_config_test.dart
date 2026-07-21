import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/models/points_config.dart';

void main() {
  test('default prayer point rules match Slice 1 requirements', () {
    final rules = PointsRulesConfig.defaults;

    expect(rules.ruleForPlan('free').prayerOnTime, 10);
    expect(rules.ruleForPlan('free').prayerLate, 5);
    expect(rules.ruleForPlan('free').prayerMissed, -1);
    expect(rules.ruleForPlan('free').qiyamCompletion, 50);
    expect(rules.ruleForPlan('plus').prayerOnTime, 20);
    expect(rules.ruleForPlan('pro').adhkarCompletion, 15);
  });

  test('points rules parse custom plan maps with fallback defaults', () {
    final rules = PointsRulesConfig.fromMap({
      'custom': {
        'prayerOnTime': 30,
        'prayerLate': '12',
        'prayerMissed': -4,
        'adhkarCompletion': 8,
        'duaCompletion': 9,
        'qiyamCompletion': 50,
      },
    });

    final custom = rules.ruleForPlan('custom');
    expect(custom.planId, 'custom');
    expect(custom.prayerOnTime, 30);
    expect(custom.prayerLate, 12);
    expect(custom.prayerMissed, -4);
    expect(custom.adhkarCompletion, 8);
    expect(custom.duaCompletion, 9);
    expect(custom.qiyamCompletion, 50);

    expect(rules.ruleForPlan('missing').planId, 'free');
  });
}
