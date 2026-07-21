import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_admin_audit_logger.dart';
import '../models/admin_language.dart';

class FirestoreAdminLanguagesRepository {
  FirestoreAdminLanguagesRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _languagesCollection =>
      FirebaseFirestore.instance.collection('languages');

  Future<void> ensureDefaults() async {
    if (!_firebaseConfigured) {
      return;
    }

    for (final language in _defaultLanguages) {
      final document = _languagesCollection.doc(language.code);
      final snapshot = await document.get();
      if (!snapshot.exists) {
        await document.set({
          ...language.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        continue;
      }

      final existing = snapshot.data() ?? const <String, dynamic>{};
      final missingFields = <String, dynamic>{};
      final incoming = language.toMap();
      for (final entry in incoming.entries) {
        if (!existing.containsKey(entry.key)) {
          missingFields[entry.key] = entry.value;
        }
      }
      if (missingFields.isNotEmpty) {
        await document.set({
          ...missingFields,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Stream<List<AdminLanguage>> watchLanguages({bool activeOnly = false}) {
    if (!_firebaseConfigured) {
      return Stream<List<AdminLanguage>>.value(const []);
    }

    final query = activeOnly
        ? _languagesCollection.where('isActive', isEqualTo: true)
        : _languagesCollection;

    return query.snapshots().map((snapshot) {
      final languages = snapshot.docs
          .map(AdminLanguage.fromDocument)
          .toList(growable: false);
      final sortedLanguages = [...languages]
        ..sort((left, right) {
          final orderComparison = left.order.compareTo(right.order);
          if (orderComparison != 0) {
            return orderComparison;
          }
          return left.code.compareTo(right.code);
        });
      return sortedLanguages;
    });
  }

  Future<void> createLanguage({
    required String code,
    required Map<String, dynamic> data,
  }) async {
    if (!_firebaseConfigured) {
      throw StateError('Firebase غير مهيأ.');
    }
    if (code.trim().isEmpty) {
      throw StateError('كود اللغة مطلوب.');
    }

    final normalizedCode = code.trim().toLowerCase();
    final languageDocument = _languagesCollection.doc(normalizedCode);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(languageDocument);
      if (existing.exists) {
        throw StateError('هذه اللغة موجودة بالفعل.');
      }

      if (data['isDefault'] == true) {
        final currentDefault = await _languagesCollection
            .where('isDefault', isEqualTo: true)
            .get();
        for (final document in currentDefault.docs) {
          transaction.update(document.reference, {
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final createData = {
        ...data,
        'code': normalizedCode,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(languageDocument, createData);
      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'create_language',
        targetId: normalizedCode,
        before: const <String, dynamic>{},
        after: FirestoreAdminAuditLogger.normalizeMap(createData),
      );
    });
  }

  Future<void> updateLanguage({
    required String languageId,
    required Map<String, dynamic> updates,
  }) async {
    if (!_firebaseConfigured || languageId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو languageId غير صالح.');
    }
    if (updates.isEmpty) {
      return;
    }

    final languageDocument = _languagesCollection.doc(languageId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(languageDocument);
      if (!snapshot.exists) {
        throw StateError('تعذر العثور على اللغة المطلوبة.');
      }

      final beforeData = FirestoreAdminAuditLogger.normalizeMap(
        snapshot.data(),
      );
      final shouldBeDefault = updates['isDefault'] == true;

      if (shouldBeDefault) {
        final currentDefault = await _languagesCollection
            .where('isDefault', isEqualTo: true)
            .get();
        for (final document in currentDefault.docs) {
          if (document.id == languageId) {
            continue;
          }
          transaction.update(document.reference, {
            'isDefault': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final updatePayload = {
        ...updates,
        if (shouldBeDefault) 'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final afterData = FirestoreAdminAuditLogger.mergeState(
        before: beforeData,
        updates: updatePayload,
      );

      transaction.update(languageDocument, updatePayload);
      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'update_language',
        targetId: languageId,
        before: beforeData,
        after: afterData,
      );
    });
  }

  Future<void> setDefaultLanguage({required String languageId}) async {
    if (!_firebaseConfigured || languageId.trim().isEmpty) {
      throw StateError('Firebase غير مهيأ أو languageId غير صالح.');
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final languageDocument = _languagesCollection.doc(languageId);
      final targetSnapshot = await transaction.get(languageDocument);
      if (!targetSnapshot.exists) {
        throw StateError('تعذر العثور على اللغة المطلوبة.');
      }

      final currentDefault = await _languagesCollection
          .where('isDefault', isEqualTo: true)
          .get();
      for (final document in currentDefault.docs) {
        if (document.id == languageId) {
          continue;
        }
        transaction.update(document.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final beforeData = FirestoreAdminAuditLogger.normalizeMap(
        targetSnapshot.data(),
      );
      final afterData = FirestoreAdminAuditLogger.mergeState(
        before: beforeData,
        updates: const {'isDefault': true, 'isActive': true},
      );

      transaction.update(languageDocument, {
        'isDefault': true,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      FirestoreAdminAuditLogger.writeLogInTransaction(
        transaction,
        action: 'set_default_language',
        targetId: languageId,
        before: beforeData,
        after: afterData,
      );
    });
  }

  static const _defaultLanguages = <_SeedLanguage>[
    _SeedLanguage(
      code: 'ar',
      nameNative: 'العربية',
      nameEnglish: 'Arabic',
      direction: 'rtl',
      order: 0,
      isActive: true,
      isDefault: true,
    ),
    _SeedLanguage(
      code: 'en',
      nameNative: 'الإنجليزية',
      nameEnglish: 'English',
      direction: 'ltr',
      order: 1,
      isActive: true,
      isDefault: false,
    ),
    _SeedLanguage(
      code: 'fr',
      nameNative: 'الفرنسية',
      nameEnglish: 'French',
      direction: 'ltr',
      order: 2,
      isActive: true,
      isDefault: false,
    ),
  ];
}

class _SeedLanguage {
  const _SeedLanguage({
    required this.code,
    required this.nameNative,
    required this.nameEnglish,
    required this.direction,
    required this.order,
    required this.isActive,
    required this.isDefault,
  });

  final String code;
  final String nameNative;
  final String nameEnglish;
  final String direction;
  final int order;
  final bool isActive;
  final bool isDefault;

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'nameNative': nameNative,
      'nameEnglish': nameEnglish,
      'direction': direction,
      'order': order,
      'isActive': isActive,
      'isDefault': isDefault,
    };
  }
}
