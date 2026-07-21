import '../localization/content_locale_fallback.dart';

class Plan {
  const Plan({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.nameFr = '',
    required this.priceLabel,
    required this.isActive,
    this.sortOrder = 0,
    this.description,
    this.descriptionAr,
    this.descriptionEn,
    this.descriptionFr,
    this.aiDailyLimit = 5,
    this.maxFavorites = 0,
    this.maxReflections = 0,
    this.allowQuranAyahMode = false,
    this.allowQuranWordMode = false,
    this.allowQuranAi = false,
    this.allowPremiumThemes = false,
    this.maxCustomDhikrCategories = 0,
    this.maxCustomDhikrItemsPerCategory = 0,
    this.maxCustomDuaCategories = 0,
    this.maxCustomDuaItemsPerCategory = 0,
  });

  final String id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String nameFr;
  final String priceLabel;
  final bool isActive;
  final int sortOrder;
  final String? description;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? descriptionFr;
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

  factory Plan.fromMap(Map<String, dynamic> map) {
    final id = _stringValue(map['id']) ?? '';

    return Plan(
      id: id,
      name:
          _stringValue(map['name']) ??
          _stringValue(map['title']) ??
          _stringValue(map['nameEn']) ??
          _stringValue(map['titleEn']) ??
          '',
      nameAr: _stringValue(map['nameAr']) ?? _stringValue(map['titleAr']) ?? '',
      nameEn: _stringValue(map['nameEn']) ?? _stringValue(map['titleEn']) ?? '',
      nameFr: _stringValue(map['nameFr']) ?? _stringValue(map['titleFr']) ?? '',
      priceLabel: _stringValue(map['priceLabel']) ?? '',
      isActive: map['isActive'] as bool? ?? true,
      sortOrder: _intValue(map['sortOrder']) ?? 0,
      description: _stringValue(map['description']),
      descriptionAr: _stringValue(map['descriptionAr']),
      descriptionEn: _stringValue(map['descriptionEn']),
      descriptionFr: _stringValue(map['descriptionFr']),
      aiDailyLimit: _intValue(map['aiDailyLimit']) ?? _fallbackAiLimit(id),
      maxFavorites: _intValue(map['maxFavorites']) ?? _fallbackFavorites(id),
      maxReflections:
          _intValue(map['maxReflections']) ?? _fallbackReflections(id),
      allowQuranAyahMode:
          _boolValue(map['allowQuranAyahMode']) ?? _fallbackQuranModes(id),
      allowQuranWordMode:
          _boolValue(map['allowQuranWordMode']) ?? _fallbackQuranModes(id),
      allowQuranAi: _boolValue(map['allowQuranAi']) ?? _fallbackQuranAi(id),
      allowPremiumThemes: _boolValue(map['allowPremiumThemes']) ?? false,
      maxCustomDhikrCategories: _intValue(map['maxCustomDhikrCategories']) ?? 0,
      maxCustomDhikrItemsPerCategory:
          _intValue(map['maxCustomDhikrItemsPerCategory']) ?? 0,
      maxCustomDuaCategories: _intValue(map['maxCustomDuaCategories']) ?? 0,
      maxCustomDuaItemsPerCategory:
          _intValue(map['maxCustomDuaItemsPerCategory']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (nameAr.trim().isNotEmpty) 'nameAr': nameAr,
      if (nameEn.trim().isNotEmpty) 'nameEn': nameEn,
      if (nameFr.trim().isNotEmpty) 'nameFr': nameFr,
      'priceLabel': priceLabel,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'description': description,
      if (descriptionAr?.trim().isNotEmpty == true)
        'descriptionAr': descriptionAr,
      if (descriptionEn?.trim().isNotEmpty == true)
        'descriptionEn': descriptionEn,
      if (descriptionFr?.trim().isNotEmpty == true)
        'descriptionFr': descriptionFr,
      'aiDailyLimit': aiDailyLimit,
      'maxFavorites': maxFavorites,
      'maxReflections': maxReflections,
      'allowQuranAyahMode': allowQuranAyahMode,
      'allowQuranWordMode': allowQuranWordMode,
      'allowQuranAi': allowQuranAi,
      'allowPremiumThemes': allowPremiumThemes,
      'maxCustomDhikrCategories': maxCustomDhikrCategories,
      'maxCustomDhikrItemsPerCategory': maxCustomDhikrItemsPerCategory,
      'maxCustomDuaCategories': maxCustomDuaCategories,
      'maxCustomDuaItemsPerCategory': maxCustomDuaItemsPerCategory,
    };
  }

  String displayName(String localeCode) {
    return ContentLocaleFallback.resolve(
      localeCode: localeCode,
      ar: nameAr,
      en: nameEn,
      fr: nameFr,
      readableFallbacks: [name],
      fallback: 'Plan',
    );
  }

  String? displayDescription(String localeCode) {
    final value = ContentLocaleFallback.resolve(
      localeCode: localeCode,
      ar: descriptionAr,
      en: descriptionEn,
      fr: descriptionFr,
      readableFallbacks: [description],
    );
    return value.isEmpty ? null : value;
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

  static bool? _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static int _fallbackAiLimit(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'plus':
        return 100;
      case 'pro':
        return 50;
      default:
        return 5;
    }
  }

  static int _fallbackFavorites(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'plus':
        return 150;
      case 'pro':
        return 50;
      default:
        return 10;
    }
  }

  static int _fallbackReflections(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'plus':
        return 150;
      case 'pro':
        return 50;
      default:
        return 10;
    }
  }

  static bool _fallbackQuranModes(String planId) {
    final normalized = planId.trim().toLowerCase();
    return normalized == 'pro' || normalized == 'plus';
  }

  static bool _fallbackQuranAi(String planId) {
    return planId.trim().toLowerCase() == 'plus';
  }
}
