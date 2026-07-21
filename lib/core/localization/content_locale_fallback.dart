class ContentLocaleFallback {
  const ContentLocaleFallback._();

  static const dashboardLanguageNote =
      'Content languages currently supported: Arabic, English, French.';

  static const supportedDashboardContentLocales = {'ar', 'en', 'fr'};

  static String resolve({
    required String localeCode,
    String? ar,
    String? en,
    String? fr,
    Iterable<String?> readableFallbacks = const [],
    String fallback = '',
  }) {
    final normalizedLocale = localeCode.trim().toLowerCase();
    final preferred = normalizedLocale.startsWith('ar')
        ? <String?>[ar, en, fr]
        : normalizedLocale.startsWith('fr')
        ? <String?>[fr, en, ar]
        : <String?>[en, ar, fr];

    for (final value in [...preferred, ...readableFallbacks, fallback]) {
      final normalized = _clean(value);
      if (normalized != null) {
        return normalized;
      }
    }
    return '';
  }

  static String? _clean(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
