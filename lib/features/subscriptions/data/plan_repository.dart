import '../../../core/models/plan.dart';

abstract class PlanRepository {
  Stream<List<Plan>> watchPlans({bool includeInactive = false});

  Future<void> ensureDefaults();

  Future<void> updatePlanStatus({
    required String planId,
    required bool isActive,
  });
}
