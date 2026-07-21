import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AiUsageQuota {
  const AiUsageQuota({
    required this.uid,
    required this.planId,
    required this.usedToday,
    required this.dailyLimit,
    required this.resetDate,
    required this.source,
  });

  final String uid;
  final String planId;
  final int usedToday;
  final int dailyLimit;
  final String resetDate;
  final String source;

  int get remainingMessages => max(0, dailyLimit - usedToday);

  bool get canSend => remainingMessages > 0;

  AiUsageQuota copyWith({
    int? usedToday,
    int? dailyLimit,
    String? resetDate,
    String? source,
  }) {
    return AiUsageQuota(
      uid: uid,
      planId: planId,
      usedToday: usedToday ?? this.usedToday,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      resetDate: resetDate ?? this.resetDate,
      source: source ?? this.source,
    );
  }
}

class AiUsageLimitReachedException implements Exception {
  const AiUsageLimitReachedException(this.quota);

  final AiUsageQuota quota;
}

class FirestoreAiUsageRepository {
  FirestoreAiUsageRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<AiUsageQuota> loadQuota({required String uid}) async {
    final normalizedUid = uid.trim();
    if (!_firebaseConfigured || normalizedUid.isEmpty) {
      return _fallbackQuota(uid: normalizedUid);
    }

    final userDocument = _firestore.collection('users').doc(normalizedUid);
    final userSnapshot = await userDocument.get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final planId = _planIdFromUser(userData);

    final usageSnapshot = await userDocument
        .collection('sync')
        .doc('ai_usage')
        .get();
    final planData = await _loadActivePlanData(planId);

    return _quotaFromData(
      uid: normalizedUid,
      userData: userData,
      usageData: usageSnapshot.data() ?? const <String, dynamic>{},
      planId: planId,
      planData: planData,
    );
  }

  Future<AiUsageQuota> recordMessage({
    required String uid,
    AiUsageQuota? resolvedQuota,
  }) async {
    final normalizedUid = uid.trim();
    if (!_firebaseConfigured || normalizedUid.isEmpty) {
      return _fallbackQuota(uid: normalizedUid);
    }

    final userDocument = _firestore.collection('users').doc(normalizedUid);
    final usageDocument = userDocument.collection('sync').doc('ai_usage');

    return _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocument);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final planId = _planIdFromUser(userData);
      final usageSnapshot = await transaction.get(usageDocument);
      final resolvedPlanLimit = resolvedQuota?.planId == planId
          ? resolvedQuota?.dailyLimit
          : null;

      final quota = _quotaFromData(
        uid: normalizedUid,
        userData: userData,
        usageData: usageSnapshot.data() ?? const <String, dynamic>{},
        planId: planId,
        planData: resolvedPlanLimit == null
            ? const <String, dynamic>{}
            : {'aiDailyLimit': resolvedPlanLimit},
      );

      if (!quota.canSend) {
        throw AiUsageLimitReachedException(quota);
      }

      final nextQuota = quota.copyWith(
        usedToday: quota.usedToday + 1,
        resetDate: _todayKey(),
      );

      transaction.set(usageDocument, {
        'recordType': 'ai_usage',
        'usedToday': nextQuota.usedToday,
        'resetDate': nextQuota.resetDate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return nextQuota;
    });
  }

  Future<AiUsageQuota> addRewardedCredits({
    required String uid,
    int amount = 15,
  }) async {
    final normalizedUid = uid.trim();
    final safeAmount = max(1, amount);
    final currentQuota = await loadQuota(uid: normalizedUid);

    if (!_firebaseConfigured || normalizedUid.isEmpty) {
      return currentQuota.copyWith(
        dailyLimit: currentQuota.dailyLimit + safeAmount,
        source: 'rewarded_ad_local',
      );
    }

    final userDocument = _firestore.collection('users').doc(normalizedUid);
    final usageDocument = userDocument.collection('sync').doc('ai_usage');

    return _firestore.runTransaction((transaction) async {
      final usageSnapshot = await transaction.get(usageDocument);
      final usageData = usageSnapshot.data() ?? const <String, dynamic>{};
      final today = _todayKey();
      final resetDate = _dateKeyFromValue(usageData['resetDate']);
      final usedToday = resetDate == today
          ? _intValue(usageData['usedToday']) ?? 0
          : 0;
      final usageLimit = _nonNegativeInt(usageData['dailyLimit']);
      final baseLimit = max(
        currentQuota.dailyLimit,
        usageLimit ?? currentQuota.dailyLimit,
      );
      final nextLimit = max(baseLimit, usedToday) + safeAmount;

      transaction.set(usageDocument, {
        'recordType': 'ai_usage',
        'usedToday': usedToday,
        'dailyLimit': nextLimit,
        'resetDate': today,
        'rewardedCredits': FieldValue.increment(safeAmount),
        'lastRewardedCreditAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return currentQuota.copyWith(
        usedToday: usedToday,
        dailyLimit: nextLimit,
        resetDate: today,
        source: 'rewarded_ad',
      );
    });
  }

  AiUsageQuota _quotaFromData({
    required String uid,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> usageData,
    required String planId,
    required Map<String, dynamic> planData,
  }) {
    final today = _todayKey();
    final resetDate = _dateKeyFromValue(usageData['resetDate']);
    final usedToday = resetDate == today
        ? _intValue(usageData['usedToday']) ?? 0
        : 0;

    final overrideLimit = _nonNegativeInt(userData['aiUsageLimitOverride']);
    if (overrideLimit != null) {
      return AiUsageQuota(
        uid: uid,
        planId: planId,
        usedToday: usedToday,
        dailyLimit: overrideLimit,
        resetDate: today,
        source: 'user_override',
      );
    }

    final usageLimit = _nonNegativeInt(usageData['dailyLimit']);
    if (usageLimit != null) {
      return AiUsageQuota(
        uid: uid,
        planId: planId,
        usedToday: usedToday,
        dailyLimit: usageLimit,
        resetDate: today,
        source: 'usage_override',
      );
    }

    final planLimit = _nonNegativeInt(planData['aiDailyLimit']);
    return AiUsageQuota(
      uid: uid,
      planId: planId,
      usedToday: usedToday,
      dailyLimit: planLimit ?? _fallbackPlanLimit(planId),
      resetDate: today,
      source: planLimit == null ? 'fallback' : 'plan',
    );
  }

  AiUsageQuota _fallbackQuota({required String uid}) {
    return AiUsageQuota(
      uid: uid,
      planId: 'free',
      usedToday: 0,
      dailyLimit: _fallbackPlanLimit('free'),
      resetDate: _todayKey(),
      source: 'fallback',
    );
  }

  Future<Map<String, dynamic>> _loadActivePlanData(String planId) async {
    final snapshot = await _firestore
        .collection('plans')
        .where(FieldPath.documentId, isEqualTo: planId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return {'aiDailyLimit': _fallbackPlanLimit('free')};
    }
    return snapshot.docs.first.data();
  }

  String _planIdFromUser(Map<String, dynamic> userData) {
    return _stringValue(userData['planId']) ??
        _stringValue(userData['plan']) ??
        'free';
  }

  int? _nonNegativeInt(dynamic value) {
    final parsed = _intValue(value);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
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

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _dateKeyFromValue(dynamic value) {
    if (value is Timestamp) {
      return _dateKey(value.toDate());
    }
    if (value is DateTime) {
      return _dateKey(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      final text = value.trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) {
        return text.substring(0, 10);
      }
      final parsed = DateTime.tryParse(text);
      if (parsed != null) {
        return _dateKey(parsed);
      }
    }
    return '';
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  int _fallbackPlanLimit(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'plus':
        return 100;
      case 'pro':
        return 50;
      default:
        return 5;
    }
  }
}
