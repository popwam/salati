import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuditLogEntry {
  const AdminAuditLogEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetId,
    required this.createdAt,
  });

  final String id;
  final String adminId;
  final String action;
  final String targetId;
  final DateTime? createdAt;

  factory AdminAuditLogEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return AdminAuditLogEntry(
      id: document.id,
      adminId: _stringValue(data['adminId']) ?? 'unknown',
      action: _stringValue(data['action']) ?? 'unknown',
      targetId: _stringValue(data['targetId']) ?? '',
      createdAt: _dateValue(data['createdAt']),
    );
  }
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
