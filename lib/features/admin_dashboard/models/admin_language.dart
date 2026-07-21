import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminLanguageDirection { rtl, ltr }

AdminLanguageDirection adminLanguageDirectionFromValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'ltr':
      return AdminLanguageDirection.ltr;
    default:
      return AdminLanguageDirection.rtl;
  }
}

String adminLanguageDirectionValue(AdminLanguageDirection direction) {
  switch (direction) {
    case AdminLanguageDirection.rtl:
      return 'rtl';
    case AdminLanguageDirection.ltr:
      return 'ltr';
  }
}

String adminLanguageDirectionLabel(AdminLanguageDirection direction) {
  switch (direction) {
    case AdminLanguageDirection.rtl:
      return 'RTL';
    case AdminLanguageDirection.ltr:
      return 'LTR';
  }
}

class AdminLanguage {
  const AdminLanguage({
    required this.id,
    required this.code,
    required this.nameNative,
    required this.nameEnglish,
    required this.direction,
    required this.order,
    required this.isActive,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String nameNative;
  final String nameEnglish;
  final AdminLanguageDirection direction;
  final int order;
  final bool isActive;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    if (nameNative.trim().isNotEmpty) {
      return nameNative.trim();
    }
    if (nameEnglish.trim().isNotEmpty) {
      return nameEnglish.trim();
    }
    return code;
  }

  factory AdminLanguage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final code = _stringValue(data['code']) ?? document.id;

    return AdminLanguage(
      id: document.id,
      code: code,
      nameNative: _stringValue(data['nameNative']) ?? '',
      nameEnglish: _stringValue(data['nameEnglish']) ?? '',
      direction: adminLanguageDirectionFromValue(
        _stringValue(data['direction']),
      ),
      order: _intValue(data['order']) ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      isDefault: data['isDefault'] as bool? ?? false,
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
}
