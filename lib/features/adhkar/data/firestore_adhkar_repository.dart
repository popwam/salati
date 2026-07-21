import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/localization/content_locale_fallback.dart';
import '../models/adhkar_category.dart';
import '../models/adhkar_item.dart';

class FirestoreAdhkarRepository {
  FirestoreAdhkarRepository({
    required bool firebaseConfigured,
    required String localeCode,
  }) : _firebaseConfigured = firebaseConfigured,
       _localeCode = localeCode;

  final bool _firebaseConfigured;
  final String _localeCode;

  Future<List<AdhkarCategory>> loadCategories() async {
    if (!_firebaseConfigured) {
      return const [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('content')
        .doc('adhkar')
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get()
        .timeout(const Duration(seconds: 3));

    return snapshot.docs
        .map((doc) => _mapCategory(doc.id, doc.data()))
        .where((category) => category.title.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<AdhkarItem>> loadItemsForCategory(String categoryId) async {
    if (!_firebaseConfigured || categoryId.isEmpty) {
      return const [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('content')
        .doc('adhkar')
        .collection('categories')
        .doc(categoryId)
        .collection('items')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get()
        .timeout(const Duration(seconds: 3));

    return snapshot.docs
        .map((doc) => _mapItem(doc.id, categoryId, doc.data()))
        .where((item) => item.isActive && item.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  AdhkarCategory _mapCategory(String categoryId, Map<String, dynamic> data) {
    final translations = _translationsValue(data['translations']);
    final title = ContentLocaleFallback.resolve(
      localeCode: _localeCode,
      ar:
          _stringValue(data['titleAr']) ??
          _stringValue(translations['ar']?['title']),
      en:
          _stringValue(data['titleEn']) ??
          _stringValue(translations['en']?['title']),
      fr:
          _stringValue(data['titleFr']) ??
          _stringValue(translations['fr']?['title']),
      readableFallbacks: [_stringValue(data['title'])],
    );
    final subtitle = ContentLocaleFallback.resolve(
      localeCode: _localeCode,
      ar:
          _stringValue(data['descriptionAr']) ??
          _stringValue(data['subtitleAr']) ??
          _stringValue(translations['ar']?['description']),
      en:
          _stringValue(data['descriptionEn']) ??
          _stringValue(data['subtitleEn']) ??
          _stringValue(translations['en']?['description']),
      fr:
          _stringValue(data['descriptionFr']) ??
          _stringValue(data['subtitleFr']) ??
          _stringValue(translations['fr']?['description']),
      readableFallbacks: [_stringValue(data['description'])],
    );
    final accessPlan = _stringValue(data['accessPlan'])?.toLowerCase();

    return AdhkarCategory(
      id: categoryId,
      title: title,
      subtitle: subtitle,
      isPremium: accessPlan != null && accessPlan != 'free',
    );
  }

  AdhkarItem _mapItem(
    String itemId,
    String categoryId,
    Map<String, dynamic> data,
  ) {
    final translations = _translationsValue(data['translations']);
    final text = ContentLocaleFallback.resolve(
      localeCode: _localeCode,
      ar:
          _stringValue(data['textAr']) ??
          _stringValue(translations['ar']?['text']),
      en:
          _stringValue(data['textEn']) ??
          _stringValue(translations['en']?['text']),
      fr:
          _stringValue(data['textFr']) ??
          _stringValue(translations['fr']?['text']),
      readableFallbacks: [_stringValue(data['text'])],
    );
    final title = ContentLocaleFallback.resolve(
      localeCode: _localeCode,
      ar:
          _stringValue(data['titleAr']) ??
          _stringValue(translations['ar']?['title']),
      en:
          _stringValue(data['titleEn']) ??
          _stringValue(translations['en']?['title']),
      fr:
          _stringValue(data['titleFr']) ??
          _stringValue(translations['fr']?['title']),
      readableFallbacks: [_stringValue(data['title'])],
    );
    final source = ContentLocaleFallback.resolve(
      localeCode: _localeCode,
      ar:
          _stringValue(data['sourceAr']) ??
          _stringValue(translations['ar']?['source']),
      en:
          _stringValue(data['sourceEn']) ??
          _stringValue(translations['en']?['source']),
      fr:
          _stringValue(data['sourceFr']) ??
          _stringValue(translations['fr']?['source']),
      readableFallbacks: [_stringValue(data['source'])],
    );

    return AdhkarItem(
      id: itemId,
      categoryId: categoryId,
      title: title.isEmpty ? null : title,
      text: text,
      source: source.isEmpty ? null : source,
      requiredCount: _intValue(data['repeatCount']) ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: _intValue(data['order']) ?? 0,
    );
  }

  Map<String, Map<String, dynamic>> _translationsValue(dynamic value) {
    if (value is Map) {
      final translations = <String, Map<String, dynamic>>{};
      for (final entry in value.entries) {
        if (entry.value is Map) {
          translations['${entry.key}'] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
      return translations;
    }
    return const <String, Map<String, dynamic>>{};
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
}
