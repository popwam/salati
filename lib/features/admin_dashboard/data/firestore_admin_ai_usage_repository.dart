import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_admin_audit_logger.dart';
import '../models/admin_ai_usage_entry.dart';
import '../models/admin_dashboard_access.dart';

class FirestoreAdminAiUsageRepository {
  FirestoreAdminAiUsageRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> get _plansCollection =>
      FirebaseFirestore.instance.collection('plans');

  Stream<List<AdminAiUsageEntry>> watchEntries() {
    if (!_firebaseConfigured) {
      return Stream<List<AdminAiUsageEntry>>.value(const []);
    }

    return Stream<List<AdminAiUsageEntry>>.multi((controller) {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs = const [];
      List<QueryDocumentSnapshot<Map<String, dynamic>>> usageDocs = const [];
      List<QueryDocumentSnapshot<Map<String, dynamic>>> planDocs = const [];

      void emitIfReady() {
        final planLimits = <String, int>{};
        for (final planDocument in planDocs) {
          final planData = planDocument.data();
          planLimits[planDocument.id] =
              AdminAiUsageEntry.intValue(planData['aiDailyLimit']) ??
              _fallbackPlanLimit(planDocument.id);
        }

        final usageByUserId = <String, Map<String, dynamic>>{};
        for (final usageDocument in usageDocs) {
          if (usageDocument.id != 'ai') {
            continue;
          }
          final userId = usageDocument.reference.parent.parent?.id;
          if (userId == null || userId.isEmpty) {
            continue;
          }
          usageByUserId[userId] = usageDocument.data();
        }

        final entries = userDocs
            .map((userDocument) {
              final userData = userDocument.data();
              final usageData = usageByUserId[userDocument.id];
              final legacyIsAdmin = userData['isAdmin'] == true;
              final role = adminDashboardRoleFromValue(
                AdminAiUsageEntry.stringValue(userData['role']),
                fallbackIsAdmin: legacyIsAdmin,
              );
              final planId =
                  AdminAiUsageEntry.stringValue(userData['planId']) ??
                  AdminAiUsageEntry.stringValue(userData['plan']) ??
                  'free';

              return AdminAiUsageEntry(
                uid: userDocument.id,
                name: AdminAiUsageEntry.stringValue(userData['name']) ?? '',
                email: AdminAiUsageEntry.stringValue(userData['email']),
                planId: planId,
                role: role,
                isBlocked: userData['isBlocked'] == true,
                aiUsageLimitOverride: AdminAiUsageEntry.intValue(
                  userData['aiUsageLimitOverride'],
                ),
                usedToday:
                    AdminAiUsageEntry.intValue(usageData?['usedToday']) ?? 0,
                usageDailyLimit: AdminAiUsageEntry.intValue(
                  usageData?['dailyLimit'],
                ),
                planDailyLimit:
                    planLimits[planId] ?? _fallbackPlanLimit(planId),
                resetDate: AdminAiUsageEntry.stringValue(
                  usageData?['resetDate'],
                ),
                userUpdatedAt: AdminAiUsageEntry.dateValue(
                  userData['updatedAt'],
                ),
                usageUpdatedAt: AdminAiUsageEntry.dateValue(
                  usageData?['updatedAt'],
                ),
              );
            })
            .toList(growable: false);

        final sortedEntries = [...entries]
          ..sort((left, right) {
            if (left.role != right.role) {
              return right.role.index.compareTo(left.role.index);
            }
            if (right.usedToday != left.usedToday) {
              return right.usedToday.compareTo(left.usedToday);
            }
            return left.displayName.toLowerCase().compareTo(
              right.displayName.toLowerCase(),
            );
          });

        controller.add(sortedEntries);
      }

      final usersSubscription = _usersCollection.snapshots().listen((snapshot) {
        userDocs = snapshot.docs;
        emitIfReady();
      }, onError: controller.addError);

      final usageSubscription = FirebaseFirestore.instance
          .collectionGroup('usage')
          .snapshots()
          .listen((snapshot) {
            usageDocs = snapshot.docs;
            emitIfReady();
          }, onError: controller.addError);

      final plansSubscription = _plansCollection.snapshots().listen((snapshot) {
        planDocs = snapshot.docs;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await usersSubscription.cancel();
        await usageSubscription.cancel();
        await plansSubscription.cancel();
      };
    });
  }

  Future<void> updateEntry({
    required String uid,
    int? aiUsageLimitOverride,
    bool clearAiUsageLimitOverride = false,
    int? usedToday,
    int? dailyLimit,
    String? resetDate,
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو uid غير صالح.');
    }

    final userDocument = _usersCollection.doc(uid);
    final usageDocument = userDocument.collection('usage').doc('ai');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocument);
      if (!userSnapshot.exists) {
        throw StateError('تعذر العثور على المستخدم المطلوب.');
      }

      final usageSnapshot = await transaction.get(usageDocument);
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final usageData = usageSnapshot.data() ?? const <String, dynamic>{};

      final beforeData = <String, dynamic>{
        'aiUsageLimitOverride': AdminAiUsageEntry.intValue(
          userData['aiUsageLimitOverride'],
        ),
        'usedToday': AdminAiUsageEntry.intValue(usageData['usedToday']) ?? 0,
        'dailyLimit': AdminAiUsageEntry.intValue(usageData['dailyLimit']),
        'resetDate': AdminAiUsageEntry.stringValue(usageData['resetDate']),
      };

      final userUpdates = <String, dynamic>{};
      if (clearAiUsageLimitOverride) {
        userUpdates['aiUsageLimitOverride'] = FieldValue.delete();
      } else if (aiUsageLimitOverride != null) {
        userUpdates['aiUsageLimitOverride'] = aiUsageLimitOverride;
      }

      if (userUpdates.isNotEmpty) {
        transaction.update(userDocument, {
          ...userUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final usageUpdates = <String, dynamic>{};
      if (usedToday != null) {
        usageUpdates['usedToday'] = usedToday;
      }
      if (dailyLimit != null) {
        usageUpdates['dailyLimit'] = dailyLimit;
      }
      if (resetDate != null) {
        usageUpdates['resetDate'] = resetDate;
      }

      if (usageUpdates.isNotEmpty) {
        transaction.set(usageDocument, {
          ...usageUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (userUpdates.isEmpty && usageUpdates.isEmpty) {
        return;
      }

      final afterData = <String, dynamic>{
        'aiUsageLimitOverride': clearAiUsageLimitOverride
            ? null
            : aiUsageLimitOverride ?? beforeData['aiUsageLimitOverride'],
        'usedToday': usedToday ?? beforeData['usedToday'],
        'dailyLimit': dailyLimit ?? beforeData['dailyLimit'],
        'resetDate': resetDate ?? beforeData['resetDate'],
      };

      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'update_ai_usage',
        targetId: uid,
        before: beforeData,
        after: afterData,
      );
    });
  }

  Future<void> resetUsage({required String uid, String? resetDate}) {
    final nextResetDate = resetDate ?? DateTime.now().toIso8601String();
    return updateEntry(uid: uid, usedToday: 0, resetDate: nextResetDate);
  }

  static int _fallbackPlanLimit(String planId) {
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
