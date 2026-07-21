import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_app_config.dart';
import 'admin_dashboard_functions.dart';

class FirestoreAdminAppConfigRepository {
  FirestoreAdminAppConfigRepository({
    required bool firebaseConfigured,
    AdminDashboardFunctions? functions,
  }) : _firebaseConfigured = firebaseConfigured,
       _functions = functions ?? AdminDashboardFunctions();

  final bool _firebaseConfigured;
  final AdminDashboardFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('remote_app_config');

  Stream<AdminAppConfig> watchDraft() {
    if (!_firebaseConfigured) {
      return Stream<AdminAppConfig>.value(AdminAppConfig.fallback);
    }
    return _collection.doc('draft').snapshots().map((snapshot) {
      return AdminAppConfig.fromMap(snapshot.data());
    });
  }

  Stream<AdminAppConfig> watchPublished() {
    if (!_firebaseConfigured) {
      return Stream<AdminAppConfig>.value(
        AdminAppConfig.fallback.copyWith(status: 'published'),
      );
    }
    return _collection.doc('published').snapshots().map((snapshot) {
      return AdminAppConfig.fromMap(
        snapshot.data(),
      ).copyWith(status: 'published');
    });
  }

  Future<void> saveDraft(AdminAppConfig config) async {
    _ensureConfigured();
    await _functions.call(
      'saveAppConfigDraft',
      data: _callableConfigMap(config, statusOverride: 'draft'),
    );
  }

  Future<void> publishDraft(AdminAppConfig config) async {
    _ensureConfigured();
    await _functions.call(
      'saveAppConfigDraft',
      data: _callableConfigMap(config, statusOverride: 'draft'),
    );
    await _functions.call('publishAppConfig');
  }

  Future<void> rollbackToPreviousPublished() async {
    _ensureConfigured();
    throw StateError(
      'الرجوع إلى نسخة سابقة يحتاج دالة Backend/Admin SDK مخصصة ولم يتم تفعيله في هذه الشريحة.',
    );
  }

  void _ensureConfigured() {
    if (!_firebaseConfigured) {
      throw StateError('Firebase is not configured.');
    }
  }

  Map<String, dynamic> _callableConfigMap(
    AdminAppConfig config, {
    required String statusOverride,
  }) {
    final data = config.toMap(statusOverride: statusOverride);
    data.remove('updatedAt');
    return data;
  }
}
