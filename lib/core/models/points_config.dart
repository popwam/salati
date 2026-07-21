class PlanPointsRule {
  const PlanPointsRule({
    required this.planId,
    required this.prayerOnTime,
    required this.prayerLate,
    required this.prayerMissed,
    required this.adhkarCompletion,
    required this.duaCompletion,
    required this.qiyamCompletion,
  });

  final String planId;
  final int prayerOnTime;
  final int prayerLate;
  final int prayerMissed;
  final int adhkarCompletion;
  final int duaCompletion;
  final int qiyamCompletion;

  static const free = PlanPointsRule(
    planId: 'free',
    prayerOnTime: 10,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 10,
    duaCompletion: 10,
    qiyamCompletion: 50,
  );

  static const plus = PlanPointsRule(
    planId: 'plus',
    prayerOnTime: 20,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 15,
    duaCompletion: 15,
    qiyamCompletion: 50,
  );

  static const pro = PlanPointsRule(
    planId: 'pro',
    prayerOnTime: 20,
    prayerLate: 5,
    prayerMissed: -1,
    adhkarCompletion: 15,
    duaCompletion: 15,
    qiyamCompletion: 50,
  );

  factory PlanPointsRule.fromMap(String planId, Map<String, dynamic> map) {
    final fallback = PointsRulesConfig.defaults.ruleForPlan(planId);
    return PlanPointsRule(
      planId: planId.trim().isEmpty ? fallback.planId : planId.trim(),
      prayerOnTime: _intValue(map['prayerOnTime']) ?? fallback.prayerOnTime,
      prayerLate: _intValue(map['prayerLate']) ?? fallback.prayerLate,
      prayerMissed: _intValue(map['prayerMissed']) ?? fallback.prayerMissed,
      adhkarCompletion:
          _intValue(map['adhkarCompletion']) ?? fallback.adhkarCompletion,
      duaCompletion: _intValue(map['duaCompletion']) ?? fallback.duaCompletion,
      qiyamCompletion:
          _intValue(map['qiyamCompletion']) ?? fallback.qiyamCompletion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prayerOnTime': prayerOnTime,
      'prayerLate': prayerLate,
      'prayerMissed': prayerMissed,
      'adhkarCompletion': adhkarCompletion,
      'duaCompletion': duaCompletion,
      'qiyamCompletion': qiyamCompletion,
    };
  }

  PlanPointsRule copyWith({
    int? prayerOnTime,
    int? prayerLate,
    int? prayerMissed,
    int? adhkarCompletion,
    int? duaCompletion,
    int? qiyamCompletion,
  }) {
    return PlanPointsRule(
      planId: planId,
      prayerOnTime: prayerOnTime ?? this.prayerOnTime,
      prayerLate: prayerLate ?? this.prayerLate,
      prayerMissed: prayerMissed ?? this.prayerMissed,
      adhkarCompletion: adhkarCompletion ?? this.adhkarCompletion,
      duaCompletion: duaCompletion ?? this.duaCompletion,
      qiyamCompletion: qiyamCompletion ?? this.qiyamCompletion,
    );
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class PointsRulesConfig {
  const PointsRulesConfig({required this.rulesByPlan});

  final Map<String, PlanPointsRule> rulesByPlan;

  static const defaults = PointsRulesConfig(
    rulesByPlan: {
      'free': PlanPointsRule.free,
      'plus': PlanPointsRule.plus,
      'pro': PlanPointsRule.pro,
    },
  );

  factory PointsRulesConfig.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return defaults;
    }

    final resolved = <String, PlanPointsRule>{...defaults.rulesByPlan};
    for (final entry in map.entries) {
      final planId = entry.key.trim().toLowerCase();
      final value = entry.value;
      if (planId.isEmpty || value is! Map) {
        continue;
      }
      resolved[planId] = PlanPointsRule.fromMap(
        planId,
        value.map((key, item) => MapEntry(key.toString(), item)),
      );
    }

    return PointsRulesConfig(rulesByPlan: resolved);
  }

  PlanPointsRule ruleForPlan(String? planId) {
    final normalized = planId?.trim().toLowerCase();
    return rulesByPlan[normalized] ??
        rulesByPlan['free'] ??
        PlanPointsRule.free;
  }

  Map<String, dynamic> toMap() {
    return rulesByPlan.map((key, value) => MapEntry(key, value.toMap()));
  }
}

enum PrayerPointResult { onTime, late, missed }

class PointsEngine {
  const PointsEngine(this.rules);

  final PointsRulesConfig rules;

  int prayerPoints({
    required String? planId,
    required PrayerPointResult result,
  }) {
    final rule = rules.ruleForPlan(planId);
    return switch (result) {
      PrayerPointResult.onTime => rule.prayerOnTime,
      PrayerPointResult.late => rule.prayerLate,
      PrayerPointResult.missed => rule.prayerMissed,
    };
  }

  int adhkarCompletionPoints(String? planId) {
    return rules.ruleForPlan(planId).adhkarCompletion;
  }

  int duaCompletionPoints(String? planId) {
    return rules.ruleForPlan(planId).duaCompletion;
  }

  int qiyamCompletionPoints(String? planId) {
    return rules.ruleForPlan(planId).qiyamCompletion;
  }
}
