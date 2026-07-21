import 'package:cloud_firestore/cloud_firestore.dart';

import '../../store/models/store_catalog_item.dart';
import '../models/admin_store_item.dart';
import 'admin_dashboard_functions.dart';

class FirestoreAdminStoreRepository {
  FirestoreAdminStoreRepository({
    required bool firebaseConfigured,
    AdminDashboardFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? AdminDashboardFunctions();

  final bool _firebaseConfigured;
  final AdminDashboardFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _storeCollection =>
      FirebaseFirestore.instance.collection('store_items');

  Stream<List<AdminStoreItem>> watchItems() {
    if (!_firebaseConfigured) {
      return Stream<List<AdminStoreItem>>.value(const []);
    }

    return _storeCollection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(AdminStoreItem.fromDocument)
          .toList(growable: false);
      final sortedItems = [...items]
        ..sort((left, right) {
          final rightUpdatedAt = right.updatedAt;
          final leftUpdatedAt = left.updatedAt;
          if (rightUpdatedAt != null && leftUpdatedAt != null) {
            final updatedAtComparison = rightUpdatedAt.compareTo(leftUpdatedAt);
            if (updatedAtComparison != 0) {
              return updatedAtComparison;
            }
          } else if (rightUpdatedAt != null) {
            return 1;
          } else if (leftUpdatedAt != null) {
            return -1;
          }
          return left.displayTitle.toLowerCase().compareTo(
            right.displayTitle.toLowerCase(),
          );
        });
      return sortedItems;
    });
  }

  Future<void> createItem({required Map<String, dynamic> data}) async {
    _ensureConfigured();
    await _functions.call('saveStoreItem', data: _normalizeStorePayload(data));
  }

  Future<void> updateItem({
    required String itemId,
    required Map<String, dynamic> updates,
  }) async {
    _ensureConfigured();
    if (itemId.trim().isEmpty) {
      throw StateError('itemId is required.');
    }
    if (updates.isEmpty) {
      return;
    }

    await _functions.call(
      'saveStoreItem',
      data: _normalizeStorePayload({'itemId': itemId.trim(), ...updates}),
    );
  }

  Future<void> deleteItem({required String itemId}) async {
    _ensureConfigured();
    throw StateError(
      'حذف عناصر المتجر يحتاج دالة Backend/Admin SDK مخصصة ولم يتم تفعيله في هذه الشريحة.',
    );
  }

  Future<int> seedCommercialDefaults() async {
    _ensureConfigured();
    var savedCount = 0;
    for (final item in StoreCatalogDefaults.items) {
      final payload = _normalizeStorePayload({
        'itemId': item.id,
        ...item.toFirestoreData(),
      });
      if (!_supportedStoreType('${payload['type']}')) {
        continue;
      }
      await _functions.call('saveStoreItem', data: payload);
      savedCount++;
    }
    return savedCount;
  }

  void _ensureConfigured() {
    if (!_firebaseConfigured) {
      throw StateError('Firebase is not configured.');
    }
  }

  Map<String, dynamic> _normalizeStorePayload(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{...data};
    final type = normalized['type'];
    if (type is String) {
      normalized['type'] = switch (type.trim()) {
        'font' => 'quran_font',
        'widget' => 'widget_unlock',
        'adhan' => 'adhan_sound',
        'gift_card' => 'gift',
        'mushaf' => 'mushaf_pack',
        _ => type.trim(),
      };
    }
    return normalized;
  }

  bool _supportedStoreType(String type) {
    return const {
      'gift',
      'adhan_sound',
      'theme',
      'quran_font',
      'mushaf_pack',
      'widget_unlock',
      'other_reward',
    }.contains(type.trim());
  }
}
