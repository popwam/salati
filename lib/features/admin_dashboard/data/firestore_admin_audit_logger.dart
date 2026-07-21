import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAdminAuditLogger {
  FirestoreAdminAuditLogger._();

  static final Object _unsupported = Object();

  static CollectionReference<Map<String, dynamic>> get _logsCollection =>
      FirebaseFirestore.instance.collection('admin_logs');

  static String get _currentAdminId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  static void writeLogInTransaction(
    Transaction transaction, {
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    final logDocument = _logsCollection.doc();
    transaction.set(
      logDocument,
      _buildPayload(
        action: action,
        targetId: targetId,
        before: before,
        after: after,
      ),
    );
  }

  static void addLogToBatch(
    WriteBatch batch, {
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    final logDocument = _logsCollection.doc();
    batch.set(
      logDocument,
      _buildPayload(
        action: action,
        targetId: targetId,
        before: before,
        after: after,
      ),
    );
  }

  static Future<void> writeLog({
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    return _logsCollection.add(
      _buildPayload(
        action: action,
        targetId: targetId,
        before: before,
        after: after,
      ),
    );
  }

  static Map<String, dynamic> mergeState({
    required Map<String, dynamic> before,
    required Map<String, dynamic> updates,
  }) {
    final merged = <String, dynamic>{...before};

    for (final entry in updates.entries) {
      final normalized = _normalizeValue(entry.value);
      if (identical(normalized, _unsupported)) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = normalized;
      }
    }

    return normalizeMap(merged);
  }

  static Map<String, dynamic> normalizeMap(Map<String, dynamic>? source) {
    final data = source ?? const <String, dynamic>{};
    final normalized = <String, dynamic>{};
    final sortedKeys = data.keys.toList()..sort();

    for (final key in sortedKeys) {
      final normalizedValue = _normalizeValue(data[key]);
      if (!identical(normalizedValue, _unsupported)) {
        normalized[key] = normalizedValue;
      }
    }

    return normalized;
  }

  static Map<String, dynamic> _buildPayload({
    required String action,
    required String targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    return {
      'adminId': _currentAdminId,
      'action': action,
      'targetId': targetId,
      'before': normalizeMap(before),
      'after': normalizeMap(after),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value == null ||
        value is String ||
        value is bool ||
        value is num ||
        value is Timestamp ||
        value is GeoPoint) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is Iterable) {
      final normalizedItems = <dynamic>[];
      for (final item in value) {
        final normalizedItem = _normalizeValue(item);
        if (!identical(normalizedItem, _unsupported)) {
          normalizedItems.add(normalizedItem);
        }
      }
      return normalizedItems;
    }

    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((left, right) => '${left.key}'.compareTo('${right.key}'));
      final normalizedMap = <String, dynamic>{};
      for (final entry in entries) {
        final normalizedItem = _normalizeValue(entry.value);
        if (!identical(normalizedItem, _unsupported)) {
          normalizedMap['${entry.key}'] = normalizedItem;
        }
      }
      return normalizedMap;
    }

    return _unsupported;
  }
}
