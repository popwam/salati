import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_subscription_plan.dart';
import 'admin_dashboard_functions.dart';

class FirestoreAdminSubscriptionsRepository {
  FirestoreAdminSubscriptionsRepository({
    required bool firebaseConfigured,
    AdminDashboardFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? AdminDashboardFunctions();

  final bool _firebaseConfigured;
  final AdminDashboardFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _plansCollection =>
      FirebaseFirestore.instance.collection('plans');

  Future<void> ensureDefaults() async {
    if (!_firebaseConfigured) {
      return;
    }

    for (final plan in _defaultPlans) {
      await _functions.call(
        'savePlan',
        data: {'planId': plan.id, ...plan.toSeedMap()},
      );
    }
  }

  Stream<List<AdminSubscriptionPlan>> watchPlans() {
    if (!_firebaseConfigured) {
      return Stream<List<AdminSubscriptionPlan>>.value(const []);
    }

    return _plansCollection.snapshots().map((snapshot) {
      final plans = snapshot.docs
          .map(AdminSubscriptionPlan.fromDocument)
          .toList(growable: false);
      final sortedPlans = [...plans]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      return sortedPlans;
    });
  }

  Future<void> updatePlan({
    required String planId,
    required Map<String, dynamic> updates,
  }) async {
    if (!_firebaseConfigured || planId.trim().isEmpty) {
      throw StateError('Firebase is not configured or planId is invalid.');
    }

    if (updates.isEmpty) {
      return;
    }

    await _functions.call(
      'savePlan',
      data: {'planId': planId.trim(), ...updates},
    );
  }

  static const _defaultPlans = <_AdminSeedPlan>[
    _AdminSeedPlan(
      id: 'free',
      title: 'Free',
      priceMonthly: 0,
      priceYearly: 0,
      aiDailyLimit: 5,
      maxFavorites: 10,
      maxReflections: 10,
      allowQuranAyahMode: false,
      allowQuranWordMode: false,
      allowQuranAi: false,
      allowPremiumThemes: false,
      isActive: true,
      maxCustomDhikrCategories: 1,
      maxCustomDhikrItemsPerCategory: 2,
      maxCustomDuaCategories: 1,
      maxCustomDuaItemsPerCategory: 2,
    ),
    _AdminSeedPlan(
      id: 'pro',
      title: 'Pro',
      priceMonthly: 9.99,
      priceYearly: 89.99,
      aiDailyLimit: 50,
      maxFavorites: 50,
      maxReflections: 50,
      allowQuranAyahMode: true,
      allowQuranWordMode: true,
      allowQuranAi: false,
      allowPremiumThemes: false,
      isActive: true,
      maxCustomDhikrCategories: 1,
      maxCustomDhikrItemsPerCategory: 10,
      maxCustomDuaCategories: 1,
      maxCustomDuaItemsPerCategory: 10,
    ),
    _AdminSeedPlan(
      id: 'plus',
      title: 'Plus',
      priceMonthly: 19.99,
      priceYearly: 179.99,
      aiDailyLimit: 100,
      maxFavorites: 150,
      maxReflections: 150,
      allowQuranAyahMode: true,
      allowQuranWordMode: true,
      allowQuranAi: true,
      allowPremiumThemes: true,
      isActive: true,
      maxCustomDhikrCategories: 1,
      maxCustomDhikrItemsPerCategory: 30,
      maxCustomDuaCategories: 1,
      maxCustomDuaItemsPerCategory: 30,
    ),
  ];
}

class _AdminSeedPlan {
  const _AdminSeedPlan({
    required this.id,
    required this.title,
    required this.priceMonthly,
    required this.priceYearly,
    required this.aiDailyLimit,
    required this.maxFavorites,
    required this.maxReflections,
    required this.allowQuranAyahMode,
    required this.allowQuranWordMode,
    required this.allowQuranAi,
    required this.allowPremiumThemes,
    required this.isActive,
    required this.maxCustomDhikrCategories,
    required this.maxCustomDhikrItemsPerCategory,
    required this.maxCustomDuaCategories,
    required this.maxCustomDuaItemsPerCategory,
  });

  final String id;
  final String title;
  final double priceMonthly;
  final double priceYearly;
  final int aiDailyLimit;
  final int maxFavorites;
  final int maxReflections;
  final bool allowQuranAyahMode;
  final bool allowQuranWordMode;
  final bool allowQuranAi;
  final bool allowPremiumThemes;
  final bool isActive;
  final int maxCustomDhikrCategories;
  final int maxCustomDhikrItemsPerCategory;
  final int maxCustomDuaCategories;
  final int maxCustomDuaItemsPerCategory;

  Map<String, dynamic> toSeedMap() {
    final priceLabel = priceYearly == 0
        ? priceMonthly.toStringAsFixed(
            priceMonthly.truncateToDouble() == priceMonthly ? 0 : 2,
          )
        : '${priceMonthly.toStringAsFixed(priceMonthly.truncateToDouble() == priceMonthly ? 0 : 2)} / ${priceYearly.toStringAsFixed(priceYearly.truncateToDouble() == priceYearly ? 0 : 2)}';
    return {
      'title': title,
      'name': title,
      'priceMonthly': priceMonthly,
      'priceYearly': priceYearly,
      'priceLabel': priceLabel,
      'aiDailyLimit': aiDailyLimit,
      'maxFavorites': maxFavorites,
      'maxReflections': maxReflections,
      'allowQuranAyahMode': allowQuranAyahMode,
      'allowQuranWordMode': allowQuranWordMode,
      'allowQuranAi': allowQuranAi,
      'allowPremiumThemes': allowPremiumThemes,
      'isActive': isActive,
      'maxCustomDhikrCategories': maxCustomDhikrCategories,
      'maxCustomDhikrItemsPerCategory': maxCustomDhikrItemsPerCategory,
      'maxCustomDuaCategories': maxCustomDuaCategories,
      'maxCustomDuaItemsPerCategory': maxCustomDuaItemsPerCategory,
    };
  }
}
