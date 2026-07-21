import 'package:cloud_firestore/cloud_firestore.dart';

enum UserPlanType { free, pro, plus }

UserPlanType userPlanTypeFromId(String? value) {
  return UserPlanType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => UserPlanType.free,
  );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.planId,
    required this.subscriptionStatus,
    required this.isAdmin,
    this.avatarUrl,
    this.photoUrl,
    this.points = 0,
    this.isBlocked = false,
    this.aiUsageLimitOverride,
    this.proTrialRewardedAdsWatched = 0,
    this.proTrialEndsAt,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String? email;
  final String planId;
  final String subscriptionStatus;
  final bool isAdmin;
  final String? avatarUrl;
  final String? photoUrl;
  final int points;
  final bool isBlocked;
  final int? aiUsageLimitOverride;
  final int proTrialRewardedAdsWatched;
  final DateTime? proTrialEndsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isProTrialExpired =>
      subscriptionStatus == 'trial' &&
      proTrialEndsAt != null &&
      !proTrialEndsAt!.isAfter(DateTime.now());

  String get effectivePlanId => isProTrialExpired ? 'free' : planId;

  UserPlanType get plan => userPlanTypeFromId(effectivePlanId);

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final resolvedRole = _stringFromValue(map['role']);

    return AppUser(
      uid: _stringFromValue(map['uid']) ?? '',
      name: _stringFromValue(map['name']) ?? '',
      email: _stringFromValue(map['email']),
      planId:
          _stringFromValue(map['planId']) ??
          _stringFromValue(map['plan']) ??
          'free',
      subscriptionStatus:
          _stringFromValue(map['subscriptionStatus']) ?? 'active',
      isAdmin:
          map['isAdmin'] as bool? ??
          (resolvedRole != null && resolvedRole != 'user'),
      avatarUrl: _stringFromValue(map['avatarUrl']),
      photoUrl: _stringFromValue(map['photoUrl']),
      points: (_intFromValue(map['points']) ?? 0).clamp(0, 1 << 31).toInt(),
      isBlocked: map['isBlocked'] as bool? ?? false,
      aiUsageLimitOverride: _intFromValue(map['aiUsageLimitOverride']),
      proTrialRewardedAdsWatched:
          (_intFromValue(map['proTrialRewardedAdsWatched']) ?? 0)
              .clamp(0, 5)
              .toInt(),
      proTrialEndsAt: _dateFromValue(map['proTrialEndsAt']),
      createdAt: _dateFromValue(map['createdAt']),
      updatedAt: _dateFromValue(map['updatedAt']),
    );
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? planId,
    String? subscriptionStatus,
    bool? isAdmin,
    String? avatarUrl,
    String? photoUrl,
    int? points,
    bool? isBlocked,
    int? aiUsageLimitOverride,
    int? proTrialRewardedAdsWatched,
    DateTime? proTrialEndsAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      planId: planId ?? this.planId,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      isAdmin: isAdmin ?? this.isAdmin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      points: points ?? this.points,
      isBlocked: isBlocked ?? this.isBlocked,
      aiUsageLimitOverride: aiUsageLimitOverride ?? this.aiUsageLimitOverride,
      proTrialRewardedAdsWatched:
          proTrialRewardedAdsWatched ?? this.proTrialRewardedAdsWatched,
      proTrialEndsAt: proTrialEndsAt ?? this.proTrialEndsAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'planId': planId,
      'subscriptionStatus': subscriptionStatus,
      'isAdmin': isAdmin,
      'avatarUrl': avatarUrl,
      'photoUrl': photoUrl,
      'points': points,
      'isBlocked': isBlocked,
      'aiUsageLimitOverride': aiUsageLimitOverride,
      'proTrialRewardedAdsWatched': proTrialRewardedAdsWatched,
      'proTrialEndsAt': proTrialEndsAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static int? _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  static String? _stringFromValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
