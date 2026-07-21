import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureEntitlement {
  const FeatureEntitlement({
    required this.featureKey,
    required this.enabled,
    required this.source,
    this.title,
    this.description,
    this.assetKind,
    this.assetUrl,
    this.unlockKey,
    this.metadata = const <String, dynamic>{},
    this.endsAt,
  });

  final String featureKey;
  final bool enabled;
  final String source;
  final String? title;
  final String? description;
  final String? assetKind;
  final String? assetUrl;
  final String? unlockKey;
  final Map<String, dynamic> metadata;
  final DateTime? endsAt;

  bool get isActive =>
      enabled && (endsAt == null || endsAt!.isAfter(DateTime.now()));

  factory FeatureEntitlement.fromMap(Map<String, dynamic> map) {
    return FeatureEntitlement(
      featureKey: map['featureKey'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? false,
      source: map['source'] as String? ?? 'plan',
      title: map['title'] as String?,
      description: map['description'] as String?,
      assetKind: map['assetKind'] as String?,
      assetUrl: map['assetUrl'] as String?,
      unlockKey: map['unlockKey'] as String?,
      metadata: _mapFromValue(map['metadata']),
      endsAt: _dateFromValue(map['endsAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'featureKey': featureKey,
      'enabled': enabled,
      'source': source,
      'title': title,
      'description': description,
      'assetKind': assetKind,
      'assetUrl': assetUrl,
      'unlockKey': unlockKey,
      'metadata': metadata,
      'endsAt': endsAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _mapFromValue(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
