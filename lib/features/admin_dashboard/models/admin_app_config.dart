import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/points_config.dart';

class AdminAppConfig {
  const AdminAppConfig({
    required this.status,
    required this.homeCardOrder,
    required this.hiddenHomeSections,
    required this.onboardingTitle,
    required this.onboardingBody,
    required this.paywallTitle,
    required this.paywallBody,
    required this.globalMessage,
    required this.themeName,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.backgroundColorHex,
    required this.surfaceColorHex,
    required this.textColorHex,
    required this.defaultWidgetStyle,
    required this.availableAiTokens,
    required this.featureFlags,
    required this.pointsRules,
    this.updatedAt,
  });

  final String status;
  final List<String> homeCardOrder;
  final Set<String> hiddenHomeSections;
  final String onboardingTitle;
  final String onboardingBody;
  final String paywallTitle;
  final String paywallBody;
  final String globalMessage;
  final String themeName;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String backgroundColorHex;
  final String surfaceColorHex;
  final String textColorHex;
  final String defaultWidgetStyle;
  final int availableAiTokens;
  final Map<String, bool> featureFlags;
  final PointsRulesConfig pointsRules;
  final DateTime? updatedAt;

  static const fallback = AdminAppConfig(
    status: 'draft',
    homeCardOrder: ['next_prayer', 'quick_actions', 'prayer_times', 'progress'],
    hiddenHomeSections: <String>{},
    onboardingTitle: 'صلاتي',
    onboardingBody:
        'تابع مواقيت الصلاة والقرآن والأذكار والتنبيهات من مكان واحد.',
    paywallTitle: 'ارتق بتجربتك',
    paywallBody: 'افتح مزايا إضافية للمتابعة والتخصيص.',
    globalMessage: '',
    themeName: 'Salati Emerald',
    primaryColorHex: '#1F9D62',
    secondaryColorHex: '#F5A524',
    backgroundColorHex: '#F7FBF8',
    surfaceColorHex: '#FFFFFF',
    textColorHex: '#10231A',
    defaultWidgetStyle: 'ios_soft',
    availableAiTokens: 210210,
    featureFlags: <String, bool>{
      'quran_ai': false,
      'premium_widgets': true,
      'custom_content': true,
    },
    pointsRules: PointsRulesConfig.defaults,
  );

  AdminAppConfig copyWith({
    String? status,
    List<String>? homeCardOrder,
    Set<String>? hiddenHomeSections,
    String? onboardingTitle,
    String? onboardingBody,
    String? paywallTitle,
    String? paywallBody,
    String? globalMessage,
    String? themeName,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? backgroundColorHex,
    String? surfaceColorHex,
    String? textColorHex,
    String? defaultWidgetStyle,
    int? availableAiTokens,
    Map<String, bool>? featureFlags,
    PointsRulesConfig? pointsRules,
    DateTime? updatedAt,
  }) {
    return AdminAppConfig(
      status: status ?? this.status,
      homeCardOrder: homeCardOrder ?? this.homeCardOrder,
      hiddenHomeSections: hiddenHomeSections ?? this.hiddenHomeSections,
      onboardingTitle: onboardingTitle ?? this.onboardingTitle,
      onboardingBody: onboardingBody ?? this.onboardingBody,
      paywallTitle: paywallTitle ?? this.paywallTitle,
      paywallBody: paywallBody ?? this.paywallBody,
      globalMessage: globalMessage ?? this.globalMessage,
      themeName: themeName ?? this.themeName,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      surfaceColorHex: surfaceColorHex ?? this.surfaceColorHex,
      textColorHex: textColorHex ?? this.textColorHex,
      defaultWidgetStyle: defaultWidgetStyle ?? this.defaultWidgetStyle,
      availableAiTokens: availableAiTokens ?? this.availableAiTokens,
      featureFlags: featureFlags ?? this.featureFlags,
      pointsRules: pointsRules ?? this.pointsRules,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({String? statusOverride}) {
    return {
      'status': statusOverride ?? status,
      'homeCardOrder': homeCardOrder,
      'hiddenHomeSections': hiddenHomeSections.toList()..sort(),
      'onboardingTitle': onboardingTitle,
      'onboardingBody': onboardingBody,
      'paywallTitle': paywallTitle,
      'paywallBody': paywallBody,
      'globalMessage': globalMessage,
      'themeName': themeName,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'backgroundColorHex': backgroundColorHex,
      'surfaceColorHex': surfaceColorHex,
      'textColorHex': textColorHex,
      'defaultWidgetStyle': defaultWidgetStyle,
      'availableAiTokens': availableAiTokens,
      'themePalette': {
        'name': themeName,
        'primary': primaryColorHex,
        'secondary': secondaryColorHex,
        'background': backgroundColorHex,
        'surface': surfaceColorHex,
        'text': textColorHex,
      },
      'featureFlags': featureFlags,
      'pointsRules': pointsRules.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory AdminAppConfig.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return fallback.copyWith(
      status: _stringValue(map['status']) ?? fallback.status,
      homeCardOrder: _stringList(map['homeCardOrder']).isEmpty
          ? fallback.homeCardOrder
          : _stringList(map['homeCardOrder']),
      hiddenHomeSections: _stringList(map['hiddenHomeSections']).toSet(),
      onboardingTitle:
          _stringValue(map['onboardingTitle']) ?? fallback.onboardingTitle,
      onboardingBody:
          _stringValue(map['onboardingBody']) ?? fallback.onboardingBody,
      paywallTitle: _stringValue(map['paywallTitle']) ?? fallback.paywallTitle,
      paywallBody: _stringValue(map['paywallBody']) ?? fallback.paywallBody,
      globalMessage: _stringValue(map['globalMessage']) ?? '',
      themeName: _stringValue(map['themeName']) ?? fallback.themeName,
      primaryColorHex:
          _stringValue(map['primaryColorHex']) ?? fallback.primaryColorHex,
      secondaryColorHex:
          _stringValue(map['secondaryColorHex']) ??
          _themePaletteString(map, 'secondary') ??
          fallback.secondaryColorHex,
      backgroundColorHex:
          _stringValue(map['backgroundColorHex']) ??
          _themePaletteString(map, 'background') ??
          fallback.backgroundColorHex,
      surfaceColorHex:
          _stringValue(map['surfaceColorHex']) ??
          _themePaletteString(map, 'surface') ??
          fallback.surfaceColorHex,
      textColorHex:
          _stringValue(map['textColorHex']) ??
          _themePaletteString(map, 'text') ??
          fallback.textColorHex,
      defaultWidgetStyle:
          _stringValue(map['defaultWidgetStyle']) ??
          fallback.defaultWidgetStyle,
      availableAiTokens:
          _intValue(map['availableAiTokens']) ??
          _intValue(map['aiDailyLimit']) ??
          _intValue(map['tokenBudget']) ??
          fallback.availableAiTokens,
      featureFlags: _boolMap(map['featureFlags']).isEmpty
          ? fallback.featureFlags
          : _boolMap(map['featureFlags']),
      pointsRules: PointsRulesConfig.fromMap(
        map['pointsRules'] as Map<String, dynamic>? ?? const {},
      ),
      updatedAt: _dateValue(map['updatedAt']),
    );
  }
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.truncate();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

Map<String, bool> _boolMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item == true));
  }
  return const <String, bool>{};
}

String? _themePaletteString(Map<String, dynamic> map, String key) {
  final palette = map['themePalette'];
  if (palette is Map) {
    final value = palette[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
