import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/localization/content_locale_fallback.dart';

class AdminStoreItem {
  const AdminStoreItem({
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
    required this.assetKind,
    required this.assetUrl,
    required this.unlockKey,
    this.metadata = const <String, dynamic>{},
    required this.pricePoints,
    required this.requiredPlan,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    return ContentLocaleFallback.resolve(
      localeCode: 'en',
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

  String? metadataString(String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? metadataInt(String key) {
    final value = metadata[key];
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

  bool metadataBool(String key) => metadata[key] == true;

  Map<String, dynamic> metadataMap(String key) {
    final value = metadata[key];
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  String get assetSummary {
    final parts = <String>[];
    switch (type.trim().toLowerCase()) {
      case 'mushaf':
      case 'mushaf_pack':
        final start = metadataInt('fileStartIndex');
        final end = metadataInt('fileEndIndex');
        if (start != null && end != null) {
          parts.add('Pages $start-$end');
        } else {
          parts.add('Mushaf pack');
        }
      case 'theme':
        final colors = metadataMap('colors');
        final themeName = metadataString('themeName');
        if (themeName != null) {
          parts.add(themeName);
        }
        for (final entry in colors.entries) {
          final value = '${entry.value}'.trim();
          if (value.isNotEmpty) {
            parts.add('${entry.key}: $value');
          }
        }
      case 'widget':
      case 'widget_unlock':
        final widgetName = metadataString('widgetName');
        if (widgetName != null) {
          parts.add(widgetName);
        }
        parts.add(metadataBool('isFreeWidget') ? 'free widget' : 'paid widget');
      case 'adhan':
      case 'adhan_sound':
        parts.add(metadataString('soundName') ?? 'Adhan sound');
      case 'font':
      case 'quran_font':
        parts.add(metadataString('fontFamily') ?? 'Font');
      default:
        parts.add(_readableTypeLabel(type));
    }
    return parts.where((part) => part.trim().isNotEmpty).join(' - ');
  }

  factory AdminStoreItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return AdminStoreItem(
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
      metadata: _mapValue(data['metadata']),
      pricePoints: _intValue(data['pricePoints']) ?? 0,
      requiredPlan: _stringValue(data['requiredPlan']) ?? 'free',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
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
