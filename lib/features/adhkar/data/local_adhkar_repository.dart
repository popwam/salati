import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/adhkar_category.dart';
import '../models/adhkar_item.dart';

class LocalAdhkarRepository {
  const LocalAdhkarRepository();

  static const _assetPath = 'assets/data/adhkar.json';
  static Future<_LocalAdhkarPayload>? _assetPayloadFuture;

  Future<List<AdhkarCategory>> getCategories() async {
    final payload = await _loadAssetPayload();
    return payload.categories.isNotEmpty
        ? payload.categories
        : _defaultCategories;
  }

  Future<List<AdhkarItem>> getFallbackItems(String categoryId) async {
    final payload = await _loadAssetPayload();
    return payload.itemsByCategory[categoryId] ??
        _itemsByCategory[categoryId] ??
        const [];
  }

  Future<List<AdhkarItem>> getAllFallbackItems() async {
    final payload = await _loadAssetPayload();
    final source = payload.itemsByCategory.isNotEmpty
        ? payload.itemsByCategory
        : _itemsByCategory;
    return source.values.expand((items) => items).toList();
  }

  Future<_LocalAdhkarPayload> _loadAssetPayload() {
    _assetPayloadFuture ??= _readAssetPayload();
    return _assetPayloadFuture!;
  }

  static Future<_LocalAdhkarPayload> _readAssetPayload() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _fallbackPayload;
      }

      final categories = (decoded['categories'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_categoryFromMap)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);

      final itemsByCategory = <String, List<AdhkarItem>>{};
      for (final entry
          in (decoded['items'] as List<dynamic>? ?? const []).indexed) {
        if (entry.$2 is! Map) {
          continue;
        }
        final item = _itemFromMap(
          Map<String, dynamic>.from(entry.$2 as Map),
          entry.$1,
        );
        if (item == null || !item.isActive || item.text.trim().isEmpty) {
          continue;
        }
        itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
      }

      for (final items in itemsByCategory.values) {
        items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }

      return _LocalAdhkarPayload(
        categories: categories,
        itemsByCategory: itemsByCategory,
      );
    } catch (_) {
      return _fallbackPayload;
    }
  }

  static AdhkarCategory _categoryFromMap(Map<String, dynamic> map) {
    return AdhkarCategory(
      id: _stringValue(map['id']) ?? '',
      title: _stringValue(map['title']) ?? '',
      subtitle: _stringValue(map['subtitle']) ?? '',
      isPremium: _boolValue(map['isPremium']) ?? false,
    );
  }

  static AdhkarItem? _itemFromMap(Map<String, dynamic> map, int index) {
    final categoryId = _stringValue(map['categoryId']);
    final text = _stringValue(map['text']);
    if (categoryId == null || text == null) {
      return null;
    }

    return AdhkarItem(
      id: _stringValue(map['id']) ?? '${categoryId}_${index + 1}',
      categoryId: categoryId,
      title: _stringValue(map['title']),
      text: text,
      source: _stringValue(map['source']),
      requiredCount:
          _intValue(map['requiredCount']) ?? _intValue(map['count']) ?? 1,
      isActive: _boolValue(map['isActive']) ?? true,
      sortOrder: _intValue(map['sortOrder']) ?? index,
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
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return bool.tryParse(value.trim());
    }
    return null;
  }
}

class _LocalAdhkarPayload {
  const _LocalAdhkarPayload({
    required this.categories,
    required this.itemsByCategory,
  });

  final List<AdhkarCategory> categories;
  final Map<String, List<AdhkarItem>> itemsByCategory;
}

const _fallbackPayload = _LocalAdhkarPayload(
  categories: _defaultCategories,
  itemsByCategory: _itemsByCategory,
);

const _defaultCategories = [
  AdhkarCategory(
    id: 'favorites',
    title: 'المفضلة',
    subtitle: 'أذكارك المحفوظة للوصول السريع',
    isPremium: true,
  ),
  AdhkarCategory(
    id: 'morning',
    title: 'أذكار الصباح',
    subtitle: 'بداية مطمئنة ليومك',
  ),
  AdhkarCategory(
    id: 'evening',
    title: 'أذكار المساء',
    subtitle: 'ختام هادئ ليومك',
  ),
  AdhkarCategory(
    id: 'travel',
    title: 'أذكار السفر',
    subtitle: 'رفقة ذكر ودعاء في الطريق',
  ),
  AdhkarCategory(
    id: 'sleep',
    title: 'أذكار النوم',
    subtitle: 'أذكار ما قبل الراحة والنوم',
  ),
  AdhkarCategory(
    id: 'post_prayer',
    title: 'أذكار بعد الصلاة',
    subtitle: 'تسبيح واستغفار بعد الفريضة',
  ),
  AdhkarCategory(
    id: 'waking',
    title: 'أذكار الاستيقاظ',
    subtitle: 'افتتاح اليوم بذكر الله',
  ),
];

const Map<String, List<AdhkarItem>> _itemsByCategory = {
  'morning': [
    AdhkarItem(
      id: 'morning_1',
      categoryId: 'morning',
      text:
          'أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.',
      source: 'رواه مسلم',
      requiredCount: 1,
      sortOrder: 1,
    ),
    AdhkarItem(
      id: 'morning_2',
      categoryId: 'morning',
      text: 'اللهم بك أصبحنا وبك أمسينا وبك نحيا وبك نموت وإليك النشور.',
      source: 'رواه الترمذي',
      requiredCount: 1,
      sortOrder: 2,
    ),
    AdhkarItem(
      id: 'morning_3',
      categoryId: 'morning',
      text:
          'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم.',
      source: 'رواه أبو داود والترمذي',
      requiredCount: 3,
      sortOrder: 3,
    ),
  ],
  'evening': [
    AdhkarItem(
      id: 'evening_1',
      categoryId: 'evening',
      text:
          'أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.',
      source: 'رواه مسلم',
      requiredCount: 1,
      sortOrder: 1,
    ),
    AdhkarItem(
      id: 'evening_2',
      categoryId: 'evening',
      text: 'اللهم بك أمسينا وبك أصبحنا وبك نحيا وبك نموت وإليك المصير.',
      source: 'رواه الترمذي',
      requiredCount: 1,
      sortOrder: 2,
    ),
    AdhkarItem(
      id: 'evening_3',
      categoryId: 'evening',
      text: 'أعوذ بكلمات الله التامات من شر ما خلق.',
      source: 'رواه مسلم',
      requiredCount: 3,
      sortOrder: 3,
    ),
  ],
  'travel': [
    AdhkarItem(
      id: 'travel_1',
      categoryId: 'travel',
      text: 'سبحان الذي سخر لنا هذا وما كنا له مقرنين وإنا إلى ربنا لمنقلبون.',
      source: 'دعاء الركوب',
      requiredCount: 1,
      sortOrder: 1,
    ),
    AdhkarItem(
      id: 'travel_2',
      categoryId: 'travel',
      text: 'اللهم إنا نسألك في سفرنا هذا البر والتقوى ومن العمل ما ترضى.',
      source: 'رواه مسلم',
      requiredCount: 1,
      sortOrder: 2,
    ),
  ],
  'sleep': [
    AdhkarItem(
      id: 'sleep_1',
      categoryId: 'sleep',
      text: 'باسمك اللهم أموت وأحيا.',
      source: 'رواه البخاري',
      requiredCount: 1,
      sortOrder: 1,
    ),
    AdhkarItem(
      id: 'sleep_2',
      categoryId: 'sleep',
      text: 'اللهم قني عذابك يوم تبعث عبادك.',
      source: 'رواه أبو داود',
      requiredCount: 3,
      sortOrder: 2,
    ),
  ],
  'post_prayer': [
    AdhkarItem(
      id: 'post_prayer_1',
      categoryId: 'post_prayer',
      text: 'أستغفر الله، أستغفر الله، أستغفر الله.',
      source: 'رواه مسلم',
      requiredCount: 3,
      sortOrder: 1,
    ),
    AdhkarItem(
      id: 'post_prayer_2',
      categoryId: 'post_prayer',
      text: 'اللهم أنت السلام ومنك السلام تباركت يا ذا الجلال والإكرام.',
      source: 'رواه مسلم',
      requiredCount: 1,
      sortOrder: 2,
    ),
    AdhkarItem(
      id: 'post_prayer_3',
      categoryId: 'post_prayer',
      text: 'سبحان الله، والحمد لله، والله أكبر.',
      source: 'رواه مسلم',
      requiredCount: 33,
      sortOrder: 3,
    ),
  ],
  'waking': [
    AdhkarItem(
      id: 'waking_1',
      categoryId: 'waking',
      text: 'الحمد لله الذي أحيانا بعدما أماتنا وإليه النشور.',
      source: 'رواه البخاري',
      requiredCount: 1,
      sortOrder: 1,
    ),
  ],
};
