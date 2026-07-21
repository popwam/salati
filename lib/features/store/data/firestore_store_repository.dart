import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/store_catalog_item.dart';

class StorePurchaseResult {
  const StorePurchaseResult({
    required this.success,
    required this.message,
    this.remainingPoints,
  });

  final bool success;
  final String message;
  final int? remainingPoints;
}

class FirestoreStoreRepository {
  FirestoreStoreRepository({
    required bool firebaseConfigured,
    FirebaseFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? FirebaseFunctions.instance;

  final bool _firebaseConfigured;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _storeCollection =>
      FirebaseFirestore.instance.collection('store_items');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Stream<List<StoreCatalogItem>> watchActiveItems() {
    if (!_firebaseConfigured) {
      return Stream<List<StoreCatalogItem>>.value(StoreCatalogDefaults.items);
    }

    return _storeCollection.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(StoreCatalogItem.fromDocument)
          .where((item) => item.value.trim().isNotEmpty)
          .toList(growable: false);
      if (items.isEmpty) {
        return StoreCatalogDefaults.items;
      }
      return _sortItems(items);
    });
  }

  Future<StorePurchaseResult> purchaseWithPoints({
    required String uid,
    required StoreCatalogItem item,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return const StorePurchaseResult(
        success: false,
        message: 'Store requires Firebase and a valid user session.',
      );
    }

    if (item.pricePoints <= 0) {
      return const StorePurchaseResult(
        success: true,
        message: 'العنصر المجاني متاح بالفعل.',
      );
    }

    try {
      final callable = _functions.httpsCallable('redeemStoreItemWithPoints');
      final response = await callable.call<Map<String, dynamic>>({
        'itemId': item.id,
      });
      final data = Map<String, dynamic>.from(response.data);
      return StorePurchaseResult(
        success: data['success'] == true,
        message: _stringValue(data['message']) ?? 'تم شراء العنصر بالنقاط.',
        remainingPoints: _intValue(data['remainingPoints']),
      );
    } on FirebaseFunctionsException catch (error) {
      return StorePurchaseResult(
        success: false,
        message: error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'تعذر شراء العنصر بالنقاط.',
      );
    } catch (error) {
      return StorePurchaseResult(
        success: false,
        message: 'تعذر شراء العنصر بالنقاط: $error',
      );
    }
  }

  Future<StorePurchaseResult> spendPoints({
    required String uid,
    required int amount,
    required String reason,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return const StorePurchaseResult(
        success: false,
        message: 'النقاط تحتاج اتصال Firebase وحساب مستخدم صالح.',
      );
    }
    if (amount <= 0) {
      return const StorePurchaseResult(
        success: true,
        message: 'لا توجد نقاط مطلوبة.',
      );
    }

    final userRef = _usersCollection.doc(uid);
    final transactionRef = userRef.collection('points_ledger').doc();

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final currentPoints = (_intValue(userData['points']) ?? 0)
          .clamp(0, 1 << 31)
          .toInt();
      if (currentPoints < amount) {
        return StorePurchaseResult(
          success: false,
          message: 'رصيدك $currentPoints نقطة، والعملية تحتاج $amount نقطة.',
          remainingPoints: currentPoints,
        );
      }

      final remainingPoints = (currentPoints - amount)
          .clamp(0, 1 << 31)
          .toInt();
      transaction.set(userRef, {
        'points': remainingPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(transactionRef, {
        'type': 'spend',
        'amount': amount,
        'reason': reason,
        'before': currentPoints,
        'after': remainingPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return StorePurchaseResult(
        success: true,
        message: 'تم خصم $amount نقطة.',
        remainingPoints: remainingPoints,
      );
    });
  }

  Future<StorePurchaseResult> grantProTrialByAds({required String uid}) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return const StorePurchaseResult(
        success: false,
        message: 'Pro trial requires Firebase and a valid user session.',
      );
    }

    return const StorePurchaseResult(
      success: false,
      message:
          'Pro trial entitlement grants require trusted backend verification.',
    );
  }

  Future<int> recordProTrialRewardedAd({required String uid}) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return 0;
    }

    final userRef = _usersCollection.doc(uid);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final current = (_intValue(data['proTrialRewardedAdsWatched']) ?? 0)
          .clamp(0, 5)
          .toInt();
      final next = (current + 1).clamp(0, 5).toInt();
      transaction.set(userRef, {
        'proTrialRewardedAdsWatched': next,
        'proTrialLastRewardedAdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return next;
    });
  }

  static List<StoreCatalogItem> _sortItems(List<StoreCatalogItem> items) {
    final order = {
      'theme': 0,
      'font': 1,
      'quran_font': 2,
      'mushaf': 3,
      'widget': 4,
      'adhan': 5,
      'calendar': 6,
      'gift_card': 7,
      'paid_feature': 8,
      'pro_trial': 9,
    };
    final sorted = [...items]
      ..sort((left, right) {
        final leftOrder = order[left.type] ?? 99;
        final rightOrder = order[right.type] ?? 99;
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        if (left.pricePoints != right.pricePoints) {
          return left.pricePoints.compareTo(right.pricePoints);
        }
        return left.displayTitle.compareTo(right.displayTitle);
      });
    return sorted;
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

  static String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
