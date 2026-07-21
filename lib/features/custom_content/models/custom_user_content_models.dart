import 'package:cloud_firestore/cloud_firestore.dart';

enum UserCustomContentType { dhikr, dua }

class CustomContentLimitExceededException implements Exception {
  const CustomContentLimitExceededException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomContentPlanLimits {
  const CustomContentPlanLimits({
    required this.planId,
    required this.maxCustomDhikrCategories,
    required this.maxCustomDhikrItemsPerCategory,
    required this.maxCustomDuaCategories,
    required this.maxCustomDuaItemsPerCategory,
  });

  final String planId;
  final int maxCustomDhikrCategories;
  final int maxCustomDhikrItemsPerCategory;
  final int maxCustomDuaCategories;
  final int maxCustomDuaItemsPerCategory;

  factory CustomContentPlanLimits.fallback(String planId) {
    switch (planId) {
      case 'pro':
        return const CustomContentPlanLimits(
          planId: 'pro',
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 10,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 10,
        );
      case 'plus':
        return const CustomContentPlanLimits(
          planId: 'plus',
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 30,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 30,
        );
      default:
        return const CustomContentPlanLimits(
          planId: 'free',
          maxCustomDhikrCategories: 1,
          maxCustomDhikrItemsPerCategory: 2,
          maxCustomDuaCategories: 1,
          maxCustomDuaItemsPerCategory: 2,
        );
    }
  }
}

class UserCustomContentCategory {
  const UserCustomContentCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserCustomContentCategory.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return UserCustomContentCategory(
      id: document.id,
      title: _stringValue(data['title']) ?? '',
      description: _stringValue(data['description']) ?? '',
      icon: _stringValue(data['icon']) ?? '',
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }
}

class UserCustomDhikrItem {
  const UserCustomDhikrItem({
    required this.id,
    required this.text,
    required this.repeatCount,
    required this.source,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final int repeatCount;
  final String source;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserCustomDhikrItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return UserCustomDhikrItem(
      id: document.id,
      text: _stringValue(data['text']) ?? '',
      repeatCount: _intValue(data['repeatCount']) ?? 1,
      source: _stringValue(data['source']) ?? '',
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }
}

class UserCustomDuaItem {
  const UserCustomDuaItem({
    required this.id,
    required this.title,
    required this.text,
    required this.repeatCount,
    required this.source,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String text;
  final int repeatCount;
  final String source;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserCustomDuaItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return UserCustomDuaItem(
      id: document.id,
      title: _stringValue(data['title']) ?? '',
      text: _stringValue(data['text']) ?? '',
      repeatCount: _intValue(data['repeatCount']) ?? 1,
      source: _stringValue(data['source']) ?? '',
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }
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
