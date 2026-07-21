import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_audit_log_entry.dart';

class FirestoreAdminAuditLogRepository {
  FirestoreAdminAuditLogRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('admin_audit_logs');

  Stream<List<AdminAuditLogEntry>> watchRecentLogs({int limit = 20}) {
    if (!_firebaseConfigured || kDebugMode) {
      return Stream<List<AdminAuditLogEntry>>.value(const []);
    }
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAuditLogEntry.fromDocument)
              .toList(growable: false),
        );
  }
}
