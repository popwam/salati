import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/custom_user_content_models.dart';

class FirestoreUserCustomContentRepository {
  FirestoreUserCustomContentRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Future<CustomContentPlanLimits> loadPlanLimitsForUser({
    required String uid,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return CustomContentPlanLimits.fallback('free');
    }

    final userSnapshot = await _usersCollection.doc(uid).get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final planId =
        _stringValue(userData['planId']) ??
        _stringValue(userData['plan']) ??
        'free';
    final fallback = CustomContentPlanLimits.fallback(planId);

    final planSnapshot = await FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .get();
    final planData = planSnapshot.data() ?? const <String, dynamic>{};

    return CustomContentPlanLimits(
      planId: planId,
      maxCustomDhikrCategories:
          _positiveIntValue(
            planData['maxCustomDhikrCategories'],
            fallback.maxCustomDhikrCategories,
          ) ??
          fallback.maxCustomDhikrCategories,
      maxCustomDhikrItemsPerCategory:
          _positiveIntValue(
            planData['maxCustomDhikrItemsPerCategory'],
            fallback.maxCustomDhikrItemsPerCategory,
          ) ??
          fallback.maxCustomDhikrItemsPerCategory,
      maxCustomDuaCategories:
          _positiveIntValue(
            planData['maxCustomDuaCategories'],
            fallback.maxCustomDuaCategories,
          ) ??
          fallback.maxCustomDuaCategories,
      maxCustomDuaItemsPerCategory:
          _positiveIntValue(
            planData['maxCustomDuaItemsPerCategory'],
            fallback.maxCustomDuaItemsPerCategory,
          ) ??
          fallback.maxCustomDuaItemsPerCategory,
    );
  }

  Stream<List<UserCustomContentCategory>> watchCategories({
    required String uid,
    required UserCustomContentType type,
  }) {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return Stream<List<UserCustomContentCategory>>.value(const []);
    }

    return _categoriesCollection(uid: uid, type: type).snapshots().map((
      snapshot,
    ) {
      final categories = snapshot.docs
          .map(UserCustomContentCategory.fromDocument)
          .toList(growable: false);
      final sortedCategories = [...categories]
        ..sort((left, right) {
          final orderComparison = left.order.compareTo(right.order);
          if (orderComparison != 0) {
            return orderComparison;
          }
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        });
      return sortedCategories;
    });
  }

  Stream<List<UserCustomDhikrItem>> watchDhikrItems({
    required String uid,
    required String categoryId,
  }) {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty) {
      return Stream<List<UserCustomDhikrItem>>.value(const []);
    }

    return _itemsCollection(
      uid: uid,
      type: UserCustomContentType.dhikr,
      categoryId: categoryId,
    ).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(UserCustomDhikrItem.fromDocument)
          .toList(growable: false);
      final sortedItems = [...items]
        ..sort((left, right) => left.order.compareTo(right.order));
      return sortedItems;
    });
  }

  Stream<List<UserCustomDuaItem>> watchDuaItems({
    required String uid,
    required String categoryId,
  }) {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty) {
      return Stream<List<UserCustomDuaItem>>.value(const []);
    }

    return _itemsCollection(
      uid: uid,
      type: UserCustomContentType.dua,
      categoryId: categoryId,
    ).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(UserCustomDuaItem.fromDocument)
          .toList(growable: false);
      final sortedItems = [...items]
        ..sort((left, right) => left.order.compareTo(right.order));
      return sortedItems;
    });
  }

  Future<void> createCategory({
    required String uid,
    required UserCustomContentType type,
    required Map<String, dynamic> data,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final limits = await loadPlanLimitsForUser(uid: uid);
    final categoriesSnapshot = await _categoriesCollection(
      uid: uid,
      type: type,
    ).get();
    final categoriesLimit = type == UserCustomContentType.dhikr
        ? limits.maxCustomDhikrCategories
        : limits.maxCustomDuaCategories;

    if (categoriesSnapshot.docs.length >= categoriesLimit) {
      throw CustomContentLimitExceededException(
        'تم الوصول إلى الحد الأقصى للأقسام في باقتك الحالية. الرجاء الترقية لإضافة المزيد.',
      );
    }

    await _categoriesCollection(uid: uid, type: type).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory({
    required String uid,
    required UserCustomContentType type,
    required String categoryId,
    required Map<String, dynamic> updates,
  }) async {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو المعرفات غير صالحة.');
    }
    if (updates.isEmpty) {
      return;
    }

    await _categoriesCollection(uid: uid, type: type).doc(categoryId).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory({
    required String uid,
    required UserCustomContentType type,
    required String categoryId,
  }) async {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو المعرفات غير صالحة.');
    }

    final categoryReference = _categoriesCollection(
      uid: uid,
      type: type,
    ).doc(categoryId);
    final itemsSnapshot = await categoryReference.collection('items').get();

    var index = 0;
    while (index < itemsSnapshot.docs.length) {
      final batch = FirebaseFirestore.instance.batch();
      final end = index + 400 < itemsSnapshot.docs.length
          ? index + 400
          : itemsSnapshot.docs.length;
      for (final document in itemsSnapshot.docs.sublist(index, end)) {
        batch.delete(document.reference);
      }
      await batch.commit();
      index = end;
    }

    await categoryReference.delete();
  }

  Future<void> createDhikrItem({
    required String uid,
    required String categoryId,
    required Map<String, dynamic> data,
  }) {
    return _createItem(
      uid: uid,
      categoryId: categoryId,
      type: UserCustomContentType.dhikr,
      data: data,
    );
  }

  Future<void> createDuaItem({
    required String uid,
    required String categoryId,
    required Map<String, dynamic> data,
  }) {
    return _createItem(
      uid: uid,
      categoryId: categoryId,
      type: UserCustomContentType.dua,
      data: data,
    );
  }

  Future<void> updateItem({
    required String uid,
    required UserCustomContentType type,
    required String categoryId,
    required String itemId,
    required Map<String, dynamic> updates,
  }) async {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty ||
        itemId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو المعرفات غير صالحة.');
    }
    if (updates.isEmpty) {
      return;
    }

    await _itemsCollection(uid: uid, type: type, categoryId: categoryId)
        .doc(itemId)
        .update({...updates, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteItem({
    required String uid,
    required UserCustomContentType type,
    required String categoryId,
    required String itemId,
  }) async {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty ||
        itemId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو المعرفات غير صالحة.');
    }

    await _itemsCollection(
      uid: uid,
      type: type,
      categoryId: categoryId,
    ).doc(itemId).delete();
  }

  CollectionReference<Map<String, dynamic>> _categoriesCollection({
    required String uid,
    required UserCustomContentType type,
  }) {
    return _usersCollection
        .doc(uid)
        .collection(
          type == UserCustomContentType.dhikr
              ? 'custom_dhikr_categories'
              : 'custom_dua_categories',
        );
  }

  CollectionReference<Map<String, dynamic>> _itemsCollection({
    required String uid,
    required UserCustomContentType type,
    required String categoryId,
  }) {
    return _categoriesCollection(
      uid: uid,
      type: type,
    ).doc(categoryId).collection('items');
  }

  Future<void> _createItem({
    required String uid,
    required String categoryId,
    required UserCustomContentType type,
    required Map<String, dynamic> data,
  }) async {
    if (!_firebaseConfigured ||
        uid.trim().isEmpty ||
        categoryId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو المعرفات غير صالحة.');
    }

    final limits = await loadPlanLimitsForUser(uid: uid);
    final itemsSnapshot = await _itemsCollection(
      uid: uid,
      type: type,
      categoryId: categoryId,
    ).get();
    final itemsLimit = type == UserCustomContentType.dhikr
        ? limits.maxCustomDhikrItemsPerCategory
        : limits.maxCustomDuaItemsPerCategory;

    if (itemsSnapshot.docs.length >= itemsLimit) {
      throw CustomContentLimitExceededException(
        'تم الوصول إلى الحد الأقصى للعناصر في هذا القسم ضمن باقتك الحالية. الرجاء الترقية لإضافة المزيد.',
      );
    }

    await _itemsCollection(uid: uid, type: type, categoryId: categoryId).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  int? _positiveIntValue(dynamic value, int fallback) {
    final parsed = _intValue(value);
    if (parsed == null) {
      return null;
    }
    return parsed > 0 ? parsed : fallback;
  }
}
