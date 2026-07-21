import 'package:cloud_firestore/cloud_firestore.dart';

class AdminContentTranslation {
  const AdminContentTranslation({
    this.title = '',
    this.description = '',
    this.text = '',
    this.source = '',
  });

  final String title;
  final String description;
  final String text;
  final String source;

  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      text.trim().isEmpty &&
      source.trim().isEmpty;

  factory AdminContentTranslation.fromMap(Map<String, dynamic>? data) {
    final rawData = data ?? const <String, dynamic>{};
    return AdminContentTranslation(
      title: _stringValue(rawData['title']) ?? '',
      description: _stringValue(rawData['description']) ?? '',
      text: _stringValue(rawData['text']) ?? '',
      source: _stringValue(rawData['source']) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (title.trim().isNotEmpty) 'title': title.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (text.trim().isNotEmpty) 'text': text.trim(),
      if (source.trim().isNotEmpty) 'source': source.trim(),
    };
  }
}

class AdminContentCategory {
  const AdminContentCategory({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.accessPlan,
    required this.translations,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String icon;
  final int order;
  final bool isActive;
  final String? accessPlan;
  final Map<String, AdminContentTranslation> translations;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    final translatedArabic = translations['ar']?.title ?? '';
    final translatedEnglish = translations['en']?.title ?? '';
    if (translatedArabic.trim().isNotEmpty) {
      return translatedArabic.trim();
    }
    if (titleAr.trim().isNotEmpty) {
      return titleAr.trim();
    }
    if (translatedEnglish.trim().isNotEmpty) {
      return translatedEnglish.trim();
    }
    if (titleEn.trim().isNotEmpty) {
      return titleEn.trim();
    }
    return id;
  }

  factory AdminContentCategory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final translations = _translationsValue(data['translations']);
    final arabicTranslation = translations['ar'];
    final englishTranslation = translations['en'];

    return AdminContentCategory(
      id: document.id,
      titleAr: _stringValue(data['titleAr']) ?? arabicTranslation?.title ?? '',
      titleEn: _stringValue(data['titleEn']) ?? englishTranslation?.title ?? '',
      icon: _stringValue(data['icon']) ?? '',
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      accessPlan: _stringValue(data['accessPlan']),
      translations: translations,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }
}

class AdminContentItem {
  const AdminContentItem({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.textAr,
    required this.textEn,
    required this.repeatCount,
    required this.source,
    required this.order,
    required this.isActive,
    required this.accessPlan,
    required this.translations,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String textAr;
  final String textEn;
  final int? repeatCount;
  final String source;
  final int order;
  final bool isActive;
  final String? accessPlan;
  final Map<String, AdminContentTranslation> translations;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    final translatedArabic = translations['ar'];
    final translatedEnglish = translations['en'];
    if ((translatedArabic?.title ?? '').trim().isNotEmpty) {
      return translatedArabic!.title.trim();
    }
    if (titleAr.trim().isNotEmpty) {
      return titleAr.trim();
    }
    if ((translatedEnglish?.title ?? '').trim().isNotEmpty) {
      return translatedEnglish!.title.trim();
    }
    if (titleEn.trim().isNotEmpty) {
      return titleEn.trim();
    }
    if ((translatedArabic?.text ?? '').trim().isNotEmpty) {
      return translatedArabic!.text.trim();
    }
    if (textAr.trim().isNotEmpty) {
      return textAr.trim();
    }
    if ((translatedEnglish?.text ?? '').trim().isNotEmpty) {
      return translatedEnglish!.text.trim();
    }
    if (textEn.trim().isNotEmpty) {
      return textEn.trim();
    }
    return id;
  }

  factory AdminContentItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final translations = _translationsValue(data['translations']);
    final arabicTranslation = translations['ar'];
    final englishTranslation = translations['en'];

    return AdminContentItem(
      id: document.id,
      titleAr: _stringValue(data['titleAr']) ?? arabicTranslation?.title ?? '',
      titleEn: _stringValue(data['titleEn']) ?? englishTranslation?.title ?? '',
      textAr: _stringValue(data['textAr']) ?? arabicTranslation?.text ?? '',
      textEn: _stringValue(data['textEn']) ?? englishTranslation?.text ?? '',
      repeatCount: _intValue(data['repeatCount']),
      source:
          _stringValue(data['source']) ??
          arabicTranslation?.source ??
          englishTranslation?.source ??
          '',
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      accessPlan: _stringValue(data['accessPlan']),
      translations: translations,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }
}

Map<String, AdminContentTranslation> _translationsValue(dynamic value) {
  if (value is Map) {
    final translations = <String, AdminContentTranslation>{};
    for (final entry in value.entries) {
      final code = '${entry.key}'.trim();
      if (code.isEmpty || entry.value is! Map) {
        continue;
      }
      translations[code] = AdminContentTranslation.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return translations;
  }
  return const <String, AdminContentTranslation>{};
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _intValue(dynamic value) {
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

DateTime? _dateValue(dynamic value) {
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
