import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSubscriptionPlan {
  const AdminSubscriptionPlan({
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
    required this.maxCustomDhikrCategories,
    required this.maxCustomDhikrItemsPerCategory,
    required this.maxCustomDuaCategories,
    required this.maxCustomDuaItemsPerCategory,
    required this.isActive,
    required this.updatedAt,
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
  final int maxCustomDhikrCategories;
  final int maxCustomDhikrItemsPerCategory;
  final int maxCustomDuaCategories;
  final int maxCustomDuaItemsPerCategory;
  final bool isActive;
  final DateTime? updatedAt;

  int get sortOrder {
    switch (id) {
      case 'free':
        return 0;
      case 'pro':
        return 1;
      case 'plus':
        return 2;
      default:
        return 100;
    }
  }

  factory AdminSubscriptionPlan.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final fallback = _fallbackFor(document.id);

    return AdminSubscriptionPlan(
      id: document.id,
      title:
          _stringValue(data['title']) ??
          _stringValue(data['name']) ??
          fallback.title,
      priceMonthly:
          _doubleValue(data['priceMonthly']) ??
          _doubleValue(data['monthlyPrice']) ??
          _doubleValue(data['priceLabel']) ??
          fallback.priceMonthly,
      priceYearly:
          _doubleValue(data['priceYearly']) ??
          _doubleValue(data['yearlyPrice']) ??
          fallback.priceYearly,
      aiDailyLimit: _intValue(data['aiDailyLimit']) ?? fallback.aiDailyLimit,
      maxFavorites: _intValue(data['maxFavorites']) ?? fallback.maxFavorites,
      maxReflections:
          _intValue(data['maxReflections']) ?? fallback.maxReflections,
      allowQuranAyahMode:
          _boolValue(data['allowQuranAyahMode']) ?? fallback.allowQuranAyahMode,
      allowQuranWordMode:
          _boolValue(data['allowQuranWordMode']) ?? fallback.allowQuranWordMode,
      allowQuranAi: _boolValue(data['allowQuranAi']) ?? fallback.allowQuranAi,
      allowPremiumThemes:
          _boolValue(data['allowPremiumThemes']) ?? fallback.allowPremiumThemes,
      maxCustomDhikrCategories:
          _intValue(data['maxCustomDhikrCategories']) ??
          fallback.maxCustomDhikrCategories,
      maxCustomDhikrItemsPerCategory:
          _intValue(data['maxCustomDhikrItemsPerCategory']) ??
          fallback.maxCustomDhikrItemsPerCategory,
      maxCustomDuaCategories:
          _intValue(data['maxCustomDuaCategories']) ??
          fallback.maxCustomDuaCategories,
      maxCustomDuaItemsPerCategory:
          _intValue(data['maxCustomDuaItemsPerCategory']) ??
          fallback.maxCustomDuaItemsPerCategory,
      isActive: _boolValue(data['isActive']) ?? true,
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  static AdminSubscriptionPlan _fallbackFor(String planId) {
    switch (planId) {
      case 'pro':
        return const AdminSubscriptionPlan(
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
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 10,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 10,
          isActive: true,
          updatedAt: null,
        );
      case 'plus':
        return const AdminSubscriptionPlan(
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
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 30,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 30,
          isActive: true,
          updatedAt: null,
        );
      default:
        return const AdminSubscriptionPlan(
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
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 2,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 2,
          isActive: true,
          updatedAt: null,
        );
    }
  }

  static String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
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

  static double? _doubleValue(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
