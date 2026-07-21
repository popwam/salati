import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/localization/content_locale_fallback.dart';

class StoreCatalogItem {
  const StoreCatalogItem({
    required this.id,
    required this.type,
    required this.title,
    this.titleAr = '',
    this.titleEn = '',
    this.titleFr = '',
    required this.description,
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.descriptionFr = '',
    required this.previewUrl,
    required this.value,
    this.assetKind = '',
    this.assetUrl = '',
    this.unlockKey = '',
    this.metadata = const <String, dynamic>{},
    required this.pricePoints,
    required this.requiredPlan,
    required this.isActive,
  });

  final String id;
  final String type;
  final String title;
  final String titleAr;
  final String titleEn;
  final String titleFr;
  final String description;
  final String descriptionAr;
  final String descriptionEn;
  final String descriptionFr;
  final String previewUrl;
  final String value;
  final String assetKind;
  final String assetUrl;
  final String unlockKey;
  final Map<String, dynamic> metadata;
  final int pricePoints;
  final String requiredPlan;
  final bool isActive;

  String get displayTitle => localizedTitle('ar');

  String localizedTitle(String languageCode) {
    return ContentLocaleFallback.resolve(
      localeCode: languageCode,
      ar: titleAr,
      en: titleEn,
      fr: titleFr,
      readableFallbacks: [
        title,
        metadataString('themeName'),
        metadataString('widgetName'),
        metadataString('soundName'),
        metadataString('fontFamily'),
      ],
      fallback: _readableTypeLabel(type),
    );
  }

  String localizedDescription(String languageCode) {
    return ContentLocaleFallback.resolve(
      localeCode: languageCode,
      ar: descriptionAr,
      en: descriptionEn,
      fr: descriptionFr,
      readableFallbacks: [description],
    );
  }

  String get featureKey {
    final normalizedType = type.trim().toLowerCase();
    final normalizedValue = value.trim();
    switch (normalizedType) {
      case 'theme':
        return 'theme:${normalizedValue.isEmpty ? id : normalizedValue}';
      case 'adhan_sound':
        return 'adhan:${normalizedValue.isEmpty ? id : normalizedValue}';
      case 'widget_unlock':
        return 'widget:${normalizedValue.isEmpty ? id : normalizedValue}';
      case 'mushaf_pack':
        return 'mushaf:${normalizedValue.isEmpty ? id : normalizedValue}';
      case 'font':
        return 'font:$normalizedValue';
      case 'quran_font':
        return 'quran_font:$normalizedValue';
      case 'mushaf':
        return 'mushaf:$normalizedValue';
      case 'widget':
        return 'widget:$normalizedValue';
      case 'adhan':
        return 'adhan:$normalizedValue';
      case 'calendar':
        return 'calendar:$normalizedValue';
      case 'gift_card':
        return 'gift_card:$normalizedValue';
      case 'paid_feature':
        return 'paid_feature:$normalizedValue';
      case 'pro_trial':
        return 'pro_trial:$normalizedValue';
      default:
        return '$normalizedType:$normalizedValue';
    }
  }

  bool get isDefaultFree => pricePoints == 0;

  String? metadataString(String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Map<String, dynamic> metadataMap(String key) {
    final value = metadata[key];
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  Map<String, String> get themeColors {
    final theme = metadataMap('theme');
    if (theme.isNotEmpty) {
      return {
        'primary': '${theme['primaryColor'] ?? ''}'.trim(),
        'secondary': '${theme['secondaryColor'] ?? ''}'.trim(),
        'background': '${theme['backgroundColor'] ?? ''}'.trim(),
        'surface': '${theme['surfaceColor'] ?? ''}'.trim(),
        'text': '${theme['textColor'] ?? ''}'.trim(),
      }..removeWhere((key, value) => value.isEmpty);
    }
    final colors = metadataMap('colors');
    return colors.map((key, item) => MapEntry(key, item.toString().trim()))
      ..removeWhere((key, value) => value.isEmpty);
  }

  String get assetSummary {
    final parts = <String>[];
    switch (type.trim().toLowerCase()) {
      case 'mushaf':
      case 'mushaf_pack':
        parts.add(metadataString('license') ?? 'Mushaf pack');
      case 'theme':
        final themeName = metadataString('themeName');
        if (themeName != null) {
          parts.add(themeName);
        }
      case 'font':
      case 'quran_font':
        parts.add(metadataString('fontFamily') ?? _readableTypeLabel(type));
      case 'widget':
      case 'widget_unlock':
        parts.add(metadataString('widgetName') ?? _readableTypeLabel(type));
      case 'adhan':
      case 'adhan_sound':
        final soundName = metadataString('soundName') ?? localizedTitle('ar');
        parts.add(soundName);
      default:
        parts.add(_readableTypeLabel(type));
    }
    return parts.where((part) => part.trim().isNotEmpty).join(' - ');
  }

  factory StoreCatalogItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final metadata = _mapValue(data['metadata']);
    final theme = _mapValue(data['theme']);
    return StoreCatalogItem(
      id: document.id,
      type: _stringValue(data['type']) ?? 'theme',
      title: _stringValue(data['title']) ?? '',
      titleAr: _stringValue(data['titleAr']) ?? '',
      titleEn: _stringValue(data['titleEn']) ?? '',
      titleFr: _stringValue(data['titleFr']) ?? '',
      description: _stringValue(data['description']) ?? '',
      descriptionAr: _stringValue(data['descriptionAr']) ?? '',
      descriptionEn: _stringValue(data['descriptionEn']) ?? '',
      descriptionFr: _stringValue(data['descriptionFr']) ?? '',
      previewUrl: _stringValue(data['previewUrl']) ?? '',
      value: _stringValue(data['value']) ?? '',
      assetKind: _stringValue(data['assetKind']) ?? '',
      assetUrl: _stringValue(data['assetUrl']) ?? '',
      unlockKey: _stringValue(data['unlockKey']) ?? '',
      metadata: {...metadata, if (theme.isNotEmpty) 'theme': theme},
      pricePoints: _intValue(data['pricePoints']) ?? 0,
      requiredPlan: _stringValue(data['requiredPlan']) ?? 'free',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestoreData() {
    return {
      'type': type,
      'title': title,
      if (titleAr.trim().isNotEmpty) 'titleAr': titleAr,
      if (titleEn.trim().isNotEmpty) 'titleEn': titleEn,
      if (titleFr.trim().isNotEmpty) 'titleFr': titleFr,
      'description': description,
      if (descriptionAr.trim().isNotEmpty) 'descriptionAr': descriptionAr,
      if (descriptionEn.trim().isNotEmpty) 'descriptionEn': descriptionEn,
      if (descriptionFr.trim().isNotEmpty) 'descriptionFr': descriptionFr,
      'previewUrl': previewUrl,
      'value': value,
      'assetKind': assetKind,
      'assetUrl': assetUrl,
      'unlockKey': unlockKey,
      'metadata': metadata,
      'pricePoints': pricePoints,
      'requiredPlan': requiredPlan,
      'isActive': isActive,
    };
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

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  static String _readableTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'theme':
        return 'Theme';
      case 'font':
      case 'quran_font':
        return 'Font';
      case 'mushaf':
      case 'mushaf_pack':
        return 'Mushaf';
      case 'widget':
      case 'widget_unlock':
        return 'Widget';
      case 'adhan':
      case 'adhan_sound':
        return 'Adhan sound';
      case 'gift':
      case 'gift_card':
        return 'Gift';
      default:
        return 'Reward';
    }
  }
}

class StoreCatalogDefaults {
  const StoreCatalogDefaults._();

  static const List<StoreCatalogItem> items = [
    StoreCatalogItem(
      id: 'theme_emerald_default',
      type: 'theme',
      title: 'الثيم الافتراضي',
      description: 'الثيم المجاني الوحيد في الإعدادات.',
      previewUrl: '',
      value: 'emerald',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'theme_indigo',
      type: 'theme',
      title: 'ثيم نيلي',
      description: 'ثيم مدفوع من المتجر بسعر 15 نقطة.',
      previewUrl: '',
      value: 'indigo',
      pricePoints: 15,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'theme_sunrise',
      type: 'theme',
      title: 'ثيم الشروق',
      description: 'ثيم دافئ مدفوع بسعر 15 نقطة.',
      previewUrl: '',
      value: 'sunrise',
      pricePoints: 15,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'theme_rose',
      type: 'theme',
      title: 'ثيم وردي',
      description: 'ثيم مميز مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'rose',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'theme_graphite',
      type: 'theme',
      title: 'ثيم جرافيت',
      description: 'ثيم عملي مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'graphite',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'font_cairo_default',
      type: 'font',
      title: 'Cairo الافتراضي',
      description: 'خط التطبيق المجاني الافتراضي.',
      previewUrl: '',
      value: 'cairo',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'font_tajawal',
      type: 'font',
      title: 'Tajawal',
      description: 'خط تطبيق مدفوع بسعر 15 نقطة.',
      previewUrl: '',
      value: 'tajawal',
      pricePoints: 15,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'font_noto',
      type: 'font',
      title: 'Noto Sans Arabic',
      description: 'خط تطبيق مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'noto',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'font_ibm',
      type: 'font',
      title: 'IBM Plex Arabic',
      description: 'خط تطبيق مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'ibm',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'quran_font_amiri_quran_default',
      type: 'quran_font',
      title: 'خط القرآن الافتراضي',
      description:
          'خط Amiri Quran المجاني الافتراضي لعرض الرسم العثماني بوضوح.',
      previewUrl: '',
      value: 'amiri_quran',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'quran_font_amiri',
      type: 'quran_font',
      title: 'Amiri للقرآن',
      description: 'خط قرآن مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'amiri',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'quran_font_naskh',
      type: 'quran_font',
      title: 'Noto Naskh Arabic',
      description: 'خط قرآن مدفوع بسعر 30 نقطة.',
      previewUrl: '',
      value: 'naskh',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'widget_next_prayer',
      type: 'widget',
      title: 'ويدجت الصلاة القادمة',
      description: 'ويدجت مجاني ثابت يعرض الصلاة القادمة والعد التنازلي.',
      previewUrl: '',
      value: 'next_prayer_widget',
      assetKind: 'widget_unlock_key',
      unlockKey: 'widget:next_prayer_widget:free:v1',
      metadata: {
        'widgetName': 'ويدجت الصلاة القادمة',
        'widgetKey': 'next_prayer_widget',
        'isFreeWidget': true,
      },
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'widget_prayer_times',
      type: 'widget',
      title: 'ويدجت مواقيت الصلاة',
      description: 'منتج ويدجت يظهر في المتجر، وقيمته prayer_times_widget.',
      previewUrl: '',
      value: 'prayer_times_widget',
      assetKind: 'widget_unlock_key',
      unlockKey: 'widget:prayer_times_widget:unlock:v1',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'widget_calendar',
      type: 'widget',
      title: 'ويدجت التقويم',
      description: 'ويدجت للتقويم الهجري والميلادي.',
      previewUrl: '',
      value: 'calendar_widget',
      assetKind: 'widget_unlock_key',
      unlockKey: 'widget:calendar_widget:unlock:v1',
      metadata: {
        'widgetName': 'ويدجت التاريخ',
        'widgetKey': 'calendar_widget',
        'isFreeWidget': true,
      },
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'widget_quran_share',
      type: 'widget',
      title: 'ويدجت الآية اليومية',
      description:
          'منتج متجر مخصص لويدجت الآية اليومية. التنفيذ الأصلي للويدجت موضح في next.md.',
      previewUrl: '',
      value: 'daily_ayah_widget',
      assetKind: 'widget_unlock_key',
      unlockKey: 'widget:daily_ayah_widget:unlock:v1',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'adhan_default',
      type: 'adhan',
      title: 'الأذان الافتراضي للصلوات',
      description: 'صوت الأذان الافتراضي للصلوات غير الفجر.',
      previewUrl: '',
      value: 'default_adhan',
      assetKind: 'adhan_audio',
      assetUrl: 'assets/music/azan/def.mp3',
      unlockKey: 'default_adhan',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'adhan_fajr_default',
      type: 'adhan',
      title: 'أذان الفجر الافتراضي',
      description: 'صوت افتراضي مستقل للفجر.',
      previewUrl: '',
      value: 'fajr_default_adhan',
      assetKind: 'adhan_audio',
      assetUrl: 'assets/music/azan/fagr.mp3',
      unlockKey: 'fajr_default_adhan',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'adhan_mishary',
      type: 'adhan',
      title: 'مشاري العفاسي',
      description:
          'مؤذن مقترح مدفوع. أضف ملف الصوت بنفس value في الأصول لاحقا.',
      previewUrl: '',
      value: 'mishary_alafasy',
      assetKind: 'adhan_audio',
      unlockKey: 'mishary_alafasy',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'adhan_abdul_basit',
      type: 'adhan',
      title: 'عبد الباسط عبد الصمد',
      description: 'مؤذن مقترح مدفوع.',
      previewUrl: '',
      value: 'abdul_basit',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'adhan_minshawi',
      type: 'adhan',
      title: 'محمد صديق المنشاوي',
      description: 'مؤذن مقترح مدفوع.',
      previewUrl: '',
      value: 'minshawi',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'calendar_hijri',
      type: 'calendar',
      title: 'التقويم الهجري المتقدم',
      description: 'بطاقات التقويم والعد التنازلي بسعر 15 نقطة.',
      previewUrl: '',
      value: 'advanced_hijri_calendar',
      pricePoints: 15,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'gift_card_50',
      type: 'gift_card',
      title: 'Gift Card 50',
      description: 'بطاقة هدية داخلية يمكن إدارتها من الداشبورد.',
      previewUrl: '',
      value: 'gift_card_50',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'paid_touch_lock',
      type: 'paid_feature',
      title: 'تعطيل اللمس أثناء القراءة',
      description:
          'ميزة مدفوعة تمنع اللمس العارض أثناء قراءة الورد أو سورة الكهف.',
      previewUrl: '',
      value: 'reader_touch_lock',
      pricePoints: 15,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'paid_advanced_alerts',
      type: 'paid_feature',
      title: 'تنبيهات متقدمة',
      description:
          'ميزة مدفوعة لتجهيز تنبيهات إضافية للأذكار والورد والجمعة عند اكتمال نظام التنبيهات.',
      previewUrl: '',
      value: 'advanced_alerts',
      pricePoints: 30,
      requiredPlan: 'free',
      isActive: true,
    ),
    StoreCatalogItem(
      id: 'pro_trial_ads_5',
      type: 'pro_trial',
      title: 'فتح Pro لمدة 3 أيام',
      description: 'يفتح Pro لمدة 3 أيام بعد مشاهدة 5 إعلانات مكتملة.',
      previewUrl: '',
      value: 'pro_3_days_ads_5',
      pricePoints: 0,
      requiredPlan: 'free',
      isActive: true,
    ),
  ];
}
