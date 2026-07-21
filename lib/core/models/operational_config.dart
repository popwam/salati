import 'points_config.dart';

class OperationalConfig {
  const OperationalConfig({
    required this.defaultUserPlanId,
    required this.authAvailability,
    required this.prayerProvider,
    required this.contentSources,
    required this.quranLimits,
    required this.pointsRules,
  });

  final String defaultUserPlanId;
  final AuthAvailability authAvailability;
  final PrayerProviderConfig prayerProvider;
  final ContentSourcesConfig contentSources;
  final QuranLimitsConfig quranLimits;
  final PointsRulesConfig pointsRules;

  factory OperationalConfig.defaults() {
    return const OperationalConfig(
      defaultUserPlanId: 'free',
      authAvailability: AuthAvailability(
        anonymousEnabled: true,
        googleEnabled: true,
        phoneEnabled: true,
        emailPasswordEnabled: true,
      ),
      prayerProvider: PrayerProviderConfig(
        providerType: 'local_calculation',
        calculationMethod: 'egyptian',
        apiBaseUrl: '',
        availableCountries: ['مصر', 'السعودية'],
        defaultCountry: 'مصر',
        defaultCity: 'القاهرة',
        defaultLatitude: 30.0444,
        defaultLongitude: 31.2357,
      ),
      contentSources: ContentSourcesConfig(
        adhkarSource: 'local',
        hadithSource: 'local',
        textSource: 'local',
      ),
      pointsRules: PointsRulesConfig.defaults,
      quranLimits: QuranLimitsConfig(
        ayahFreeMinutes: 60,
        wordFreeMinutes: 30,
        rewardedAyahMinutes: 60,
        rewardedWordMinutes: 30,
      ),
    );
  }

  factory OperationalConfig.fromMap(Map<String, dynamic> map) {
    return OperationalConfig(
      defaultUserPlanId: map['defaultUserPlanId'] as String? ?? 'free',
      authAvailability: AuthAvailability.fromMap(
        map['authAvailability'] as Map<String, dynamic>? ?? const {},
      ),
      prayerProvider: PrayerProviderConfig.fromMap(
        map['prayerProvider'] as Map<String, dynamic>? ?? const {},
      ),
      contentSources: ContentSourcesConfig.fromMap(
        map['contentSources'] as Map<String, dynamic>? ?? const {},
      ),
      quranLimits: QuranLimitsConfig.fromMap(
        map['quranLimits'] as Map<String, dynamic>? ?? const {},
      ),
      pointsRules: PointsRulesConfig.fromMap(
        map['pointsRules'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultUserPlanId': defaultUserPlanId,
      'authAvailability': authAvailability.toMap(),
      'prayerProvider': prayerProvider.toMap(),
      'contentSources': contentSources.toMap(),
      'quranLimits': quranLimits.toMap(),
      'pointsRules': pointsRules.toMap(),
    };
  }

  OperationalConfig copyWith({
    String? defaultUserPlanId,
    AuthAvailability? authAvailability,
    PrayerProviderConfig? prayerProvider,
    ContentSourcesConfig? contentSources,
    QuranLimitsConfig? quranLimits,
    PointsRulesConfig? pointsRules,
  }) {
    return OperationalConfig(
      defaultUserPlanId: defaultUserPlanId ?? this.defaultUserPlanId,
      authAvailability: authAvailability ?? this.authAvailability,
      prayerProvider: prayerProvider ?? this.prayerProvider,
      contentSources: contentSources ?? this.contentSources,
      quranLimits: quranLimits ?? this.quranLimits,
      pointsRules: pointsRules ?? this.pointsRules,
    );
  }
}

class QuranLimitsConfig {
  const QuranLimitsConfig({
    required this.ayahFreeMinutes,
    required this.wordFreeMinutes,
    required this.rewardedAyahMinutes,
    required this.rewardedWordMinutes,
  });

  final int ayahFreeMinutes;
  final int wordFreeMinutes;
  final int rewardedAyahMinutes;
  final int rewardedWordMinutes;

  factory QuranLimitsConfig.fromMap(Map<String, dynamic> map) {
    return QuranLimitsConfig(
      ayahFreeMinutes: _minutesValue(map['ayahFreeMinutes'], fallback: 60),
      wordFreeMinutes: _minutesValue(map['wordFreeMinutes'], fallback: 30),
      rewardedAyahMinutes: _minutesValue(
        map['rewardedAyahMinutes'],
        fallback: 60,
      ),
      rewardedWordMinutes: _minutesValue(
        map['rewardedWordMinutes'],
        fallback: 30,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ayahFreeMinutes': ayahFreeMinutes,
      'wordFreeMinutes': wordFreeMinutes,
      'rewardedAyahMinutes': rewardedAyahMinutes,
      'rewardedWordMinutes': rewardedWordMinutes,
    };
  }

  static int _minutesValue(dynamic value, {required int fallback}) {
    int? parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value.trim());
    }
    return (parsed ?? fallback).clamp(1, 240).toInt();
  }
}

class AuthAvailability {
  const AuthAvailability({
    required this.anonymousEnabled,
    required this.googleEnabled,
    required this.phoneEnabled,
    required this.emailPasswordEnabled,
  });

  final bool anonymousEnabled;
  final bool googleEnabled;
  final bool phoneEnabled;
  final bool emailPasswordEnabled;

  factory AuthAvailability.fromMap(Map<String, dynamic> map) {
    return AuthAvailability(
      anonymousEnabled: map['anonymousEnabled'] as bool? ?? true,
      googleEnabled: map['googleEnabled'] as bool? ?? true,
      phoneEnabled: map['phoneEnabled'] as bool? ?? true,
      emailPasswordEnabled: map['emailPasswordEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'anonymousEnabled': anonymousEnabled,
      'googleEnabled': googleEnabled,
      'phoneEnabled': phoneEnabled,
      'emailPasswordEnabled': emailPasswordEnabled,
    };
  }

  AuthAvailability copyWith({
    bool? anonymousEnabled,
    bool? googleEnabled,
    bool? phoneEnabled,
    bool? emailPasswordEnabled,
  }) {
    return AuthAvailability(
      anonymousEnabled: anonymousEnabled ?? this.anonymousEnabled,
      googleEnabled: googleEnabled ?? this.googleEnabled,
      phoneEnabled: phoneEnabled ?? this.phoneEnabled,
      emailPasswordEnabled: emailPasswordEnabled ?? this.emailPasswordEnabled,
    );
  }
}

class PrayerProviderConfig {
  static const _defaultLatitudeValue = 30.0444;
  static const _defaultLongitudeValue = 31.2357;

  const PrayerProviderConfig({
    required this.providerType,
    required this.calculationMethod,
    required this.apiBaseUrl,
    required this.availableCountries,
    required this.defaultCountry,
    required this.defaultCity,
    required this.defaultLatitude,
    required this.defaultLongitude,
  });

  final String providerType;
  final String calculationMethod;
  final String apiBaseUrl;
  final List<String> availableCountries;
  final String defaultCountry;
  final String defaultCity;
  final double defaultLatitude;
  final double defaultLongitude;

  factory PrayerProviderConfig.fromMap(Map<String, dynamic> map) {
    return PrayerProviderConfig(
      providerType: map['providerType'] as String? ?? 'local_calculation',
      calculationMethod: map['calculationMethod'] as String? ?? 'egyptian',
      apiBaseUrl: map['apiBaseUrl'] as String? ?? '',
      availableCountries:
          (map['availableCountries'] as List<dynamic>? ?? const ['مصر'])
              .map((item) => item.toString())
              .toList(),
      defaultCountry: map['defaultCountry'] as String? ?? 'مصر',
      defaultCity: map['defaultCity'] as String? ?? 'القاهرة',
      defaultLatitude: _parseCoordinate(
        map['defaultLatitude'],
        fallback: _defaultLatitudeValue,
      ),
      defaultLongitude: _parseCoordinate(
        map['defaultLongitude'],
        fallback: _defaultLongitudeValue,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerType': providerType,
      'calculationMethod': calculationMethod,
      'apiBaseUrl': apiBaseUrl,
      'availableCountries': availableCountries,
      'defaultCountry': defaultCountry,
      'defaultCity': defaultCity,
      'defaultLatitude': defaultLatitude,
      'defaultLongitude': defaultLongitude,
    };
  }

  PrayerProviderConfig copyWith({
    String? providerType,
    String? calculationMethod,
    String? apiBaseUrl,
    List<String>? availableCountries,
    String? defaultCountry,
    String? defaultCity,
    double? defaultLatitude,
    double? defaultLongitude,
  }) {
    return PrayerProviderConfig(
      providerType: providerType ?? this.providerType,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      availableCountries: availableCountries ?? this.availableCountries,
      defaultCountry: defaultCountry ?? this.defaultCountry,
      defaultCity: defaultCity ?? this.defaultCity,
      defaultLatitude: defaultLatitude ?? this.defaultLatitude,
      defaultLongitude: defaultLongitude ?? this.defaultLongitude,
    );
  }

  static double _parseCoordinate(dynamic value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }
}

class ContentSourcesConfig {
  const ContentSourcesConfig({
    required this.adhkarSource,
    required this.hadithSource,
    required this.textSource,
  });

  final String adhkarSource;
  final String hadithSource;
  final String textSource;

  factory ContentSourcesConfig.fromMap(Map<String, dynamic> map) {
    return ContentSourcesConfig(
      adhkarSource: map['adhkarSource'] as String? ?? 'local',
      hadithSource: map['hadithSource'] as String? ?? 'local',
      textSource: map['textSource'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adhkarSource': adhkarSource,
      'hadithSource': hadithSource,
      'textSource': textSource,
    };
  }

  ContentSourcesConfig copyWith({
    String? adhkarSource,
    String? hadithSource,
    String? textSource,
  }) {
    return ContentSourcesConfig(
      adhkarSource: adhkarSource ?? this.adhkarSource,
      hadithSource: hadithSource ?? this.hadithSource,
      textSource: textSource ?? this.textSource,
    );
  }
}
