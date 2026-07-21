import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_content_models.dart';
import 'admin_dashboard_functions.dart';

class FirestoreAdminContentRepository {
  FirestoreAdminContentRepository({
    required bool firebaseConfigured,
    AdminDashboardFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? AdminDashboardFunctions();

  final bool _firebaseConfigured;
  final AdminDashboardFunctions _functions;

  Stream<List<AdminContentCategory>> watchCategories({
    required String collectionPath,
  }) {
    if (!_firebaseConfigured) {
      return Stream<List<AdminContentCategory>>.value(const []);
    }

    final collection = _collection(collectionPath);
    debugPrint('Admin dashboard reading categories from $collectionPath');
    return collection.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map(AdminContentCategory.fromDocument)
          .toList(growable: false);
      final sortedCategories = [...categories]
        ..sort((left, right) {
          final orderComparison = left.order.compareTo(right.order);
          if (orderComparison != 0) {
            return orderComparison;
          }
          return left.displayTitle.toLowerCase().compareTo(
            right.displayTitle.toLowerCase(),
          );
        });
      return sortedCategories;
    });
  }

  Stream<List<AdminContentItem>> watchItems({
    required String collectionPath,
    required String categoryId,
  }) {
    if (!_firebaseConfigured || categoryId.isEmpty) {
      return Stream<List<AdminContentItem>>.value(const []);
    }

    final collection = _collection(collectionPath);
    debugPrint(
      'Admin dashboard reading items from $collectionPath/$categoryId/items',
    );
    return collection.doc(categoryId).collection('items').snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(AdminContentItem.fromDocument)
          .toList(growable: false);
      final sortedItems = [...items]
        ..sort((left, right) {
          final orderComparison = left.order.compareTo(right.order);
          if (orderComparison != 0) {
            return orderComparison;
          }
          return left.displayTitle.toLowerCase().compareTo(
            right.displayTitle.toLowerCase(),
          );
        });
      return sortedItems;
    });
  }

  Future<void> createCategory({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    _ensureConfigured();
    await _functions.call(
      _categoryFunctionName(collectionPath),
      data: _functionPayload(data),
    );
  }

  Future<void> updateCategory({
    required String collectionPath,
    required String categoryId,
    required Map<String, dynamic> updates,
  }) async {
    _ensureConfigured();
    if (categoryId.trim().isEmpty) {
      throw StateError('categoryId is required.');
    }
    if (updates.isEmpty) {
      return;
    }

    await _functions.call(
      _categoryFunctionName(collectionPath),
      data: _functionPayload({'categoryId': categoryId.trim(), ...updates}),
    );
  }

  Future<void> deleteCategory({
    required String collectionPath,
    required String categoryId,
  }) async {
    _ensureConfigured();
    throw StateError(
      'حذف المحتوى يحتاج دالة Backend/Admin SDK مخصصة ولم يتم تفعيله في هذه الشريحة.',
    );
  }

  Future<void> createItem({
    required String collectionPath,
    required String categoryId,
    required Map<String, dynamic> data,
  }) async {
    _ensureConfigured();
    if (categoryId.trim().isEmpty) {
      throw StateError('categoryId is required.');
    }

    await _functions.call(
      _itemFunctionName(collectionPath),
      data: _functionPayload({'categoryId': categoryId.trim(), ...data}),
    );
  }

  Future<void> updateItem({
    required String collectionPath,
    required String categoryId,
    required String itemId,
    required Map<String, dynamic> updates,
  }) async {
    _ensureConfigured();
    if (categoryId.trim().isEmpty || itemId.trim().isEmpty) {
      throw StateError('categoryId and itemId are required.');
    }
    if (updates.isEmpty) {
      return;
    }

    await _functions.call(
      _itemFunctionName(collectionPath),
      data: _functionPayload({
        'categoryId': categoryId.trim(),
        'itemId': itemId.trim(),
        ...updates,
      }),
    );
  }

  Future<void> deleteItem({
    required String collectionPath,
    required String categoryId,
    required String itemId,
  }) async {
    _ensureConfigured();
    throw StateError(
      'حذف المحتوى يحتاج دالة Backend/Admin SDK مخصصة ولم يتم تفعيله في هذه الشريحة.',
    );
  }

  void _ensureConfigured() {
    if (!_firebaseConfigured) {
      throw StateError('Firebase is not configured.');
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String path) {
    final cleanPath = path.trim();
    final segments = cleanPath.split('/').where((part) => part.isNotEmpty);
    if (segments.length.isEven) {
      throw ArgumentError.value(
        path,
        'path',
        'Admin content collection paths must have an odd number of segments.',
      );
    }
    return FirebaseFirestore.instance.collection(cleanPath);
  }

  String _categoryFunctionName(String collectionPath) {
    switch (collectionPath) {
      case 'content/adhkar/categories':
        return 'saveAdhkarCategory';
      case 'content/dua/categories':
        return 'saveDuaCategory';
      default:
        throw StateError(
          'Unsupported content collection path: $collectionPath',
        );
    }
  }

  String _itemFunctionName(String collectionPath) {
    switch (collectionPath) {
      case 'content/adhkar/categories':
        return 'saveAdhkarItem';
      case 'content/dua/categories':
        return 'saveDuaItem';
      default:
        throw StateError(
          'Unsupported content collection path: $collectionPath',
        );
    }
  }

  Map<String, dynamic> _functionPayload(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _cleanFunctionValue(value)))
      ..removeWhere((key, value) => value == null);
  }

  dynamic _cleanFunctionValue(dynamic value) {
    if (value is FieldValue) {
      return null;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry('$key', _cleanFunctionValue(item)),
      )..removeWhere((key, item) => item == null);
    }
    if (value is List) {
      return value
          .map(_cleanFunctionValue)
          .where((item) => item != null)
          .toList();
    }
    return value;
  }
}
