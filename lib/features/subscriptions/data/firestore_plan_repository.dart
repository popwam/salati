import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firestore_debug_logger.dart';
import '../../../core/models/plan.dart';
import 'plan_repository.dart';

class FirestorePlanRepository implements PlanRepository {
  FirestorePlanRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  CollectionReference<Map<String, dynamic>> get _plansCollection =>
      FirebaseFirestore.instance.collection('plans');

  @override
  Future<void> ensureDefaults() async {
    if (!_firebaseConfigured) {
      return;
    }

    await _ensurePlan(
      const Plan(
        id: 'free',
        name: 'مجاني',
        priceLabel: '0',
        isActive: true,
        sortOrder: 1,
        description: 'الوصول الأساسي للتطبيق.',
        aiDailyLimit: 5,
        maxFavorites: 10,
        maxReflections: 10,
        allowQuranAyahMode: false,
        allowQuranWordMode: false,
        allowQuranAi: false,
        allowPremiumThemes: false,
        maxCustomDhikrCategories: 2,
        maxCustomDhikrItemsPerCategory: 10,
        maxCustomDuaCategories: 2,
        maxCustomDuaItemsPerCategory: 10,
      ),
    );
    await _ensurePlan(
      const Plan(
        id: 'pro',
        name: 'برو',
        priceLabel: 'قريباً',
        isActive: true,
        sortOrder: 2,
        description: 'مزايا إضافية للمزامنة والتنبيهات.',
        aiDailyLimit: 30,
        maxFavorites: 50,
        maxReflections: 50,
        allowQuranAyahMode: true,
        allowQuranWordMode: true,
        allowQuranAi: false,
        allowPremiumThemes: false,
        maxCustomDhikrCategories: 10,
        maxCustomDhikrItemsPerCategory: 50,
        maxCustomDuaCategories: 10,
        maxCustomDuaItemsPerCategory: 50,
      ),
    );
    await _ensurePlan(
      const Plan(
        id: 'plus',
        name: 'بلس',
        priceLabel: 'قريباً',
        isActive: false,
        sortOrder: 3,
        description: 'مزايا موسعة للأسرة والتخصيص.',
        aiDailyLimit: 100,
        maxFavorites: 150,
        maxReflections: 150,
        allowQuranAyahMode: true,
        allowQuranWordMode: true,
        allowQuranAi: true,
        allowPremiumThemes: true,
        maxCustomDhikrCategories: 50,
        maxCustomDhikrItemsPerCategory: 200,
        maxCustomDuaCategories: 50,
        maxCustomDuaItemsPerCategory: 200,
      ),
    );

    await _ensureFeature(
      planId: 'free',
      featureKey: 'basic_prayer_access',
      data: const {
        'title': 'الوصول الأساسي للمواقيت',
        'description': 'عرض مواقيت اليوم والإعدادات الأساسية.',
        'enabled': true,
        'source': 'plan:free',
      },
    );
    await _ensureFeature(
      planId: 'free',
      featureKey: 'basic_adhkar_access',
      data: const {
        'title': 'الوصول الأساسي للأذكار',
        'description': 'الوصول إلى أذكار الصباح والمساء.',
        'enabled': true,
        'source': 'plan:free',
      },
    );
    await _ensureFeature(
      planId: 'pro',
      featureKey: 'advanced_adhkar',
      data: const {
        'title': 'مفضلة الأذكار والفلاتر',
        'description': 'تفعيل الفلاتر والمفضلة المتقدمة.',
        'enabled': true,
        'source': 'plan:pro',
      },
    );
    await _ensureFeature(
      planId: 'pro',
      featureKey: 'prayer_notifications',
      data: const {
        'title': 'تنبيهات المواقيت',
        'description': 'تفعيل التنبيهات المحلية للمواقيت.',
        'enabled': true,
        'source': 'plan:pro',
      },
    );
    await _ensureFeature(
      planId: 'pro',
      featureKey: 'quran_modes',
      data: const {
        'title': 'المصحف آيات وكلمات',
        'description': 'فتح أوضاع القراءة بالآيات والكلمات ضمن مركز القرآن.',
        'enabled': true,
        'source': 'plan:pro',
      },
    );
    await _ensureFeature(
      planId: 'plus',
      featureKey: 'quran_modes',
      data: const {
        'title': 'المصحف آيات وكلمات',
        'description': 'فتح أوضاع القراءة بالآيات والكلمات ضمن مركز القرآن.',
        'enabled': true,
        'source': 'plan:plus',
      },
    );
    await _ensureFeature(
      planId: 'plus',
      featureKey: 'quran_progress_sync',
      data: const {
        'title': 'مزامنة تقدم القرآن',
        'description': 'تمهيد لمزامنة التقدم والنسخ الاحتياطي.',
        'enabled': true,
        'source': 'plan:plus',
      },
    );
    await _ensureFeature(
      planId: 'plus',
      featureKey: 'quran_ai',
      data: const {
        'title': 'Quran AI',
        'description':
            'وصول تمهيدي لمساحة البحث الذكي في القرآن والتفسير عند الإطلاق.',
        'enabled': true,
        'source': 'plan:plus',
      },
    );
  }

  @override
  Stream<List<Plan>> watchPlans({bool includeInactive = false}) {
    if (!_firebaseConfigured) {
      return Stream<List<Plan>>.value(const []);
    }

    final path = includeInactive ? 'plans' : 'plans[isActive=true]';
    FirestoreDebugLogger.attempt(path: path, operation: 'listen');

    final query = includeInactive
        ? _plansCollection
        : _plansCollection.where('isActive', isEqualTo: true);

    return query
        .snapshots()
        .handleError((error) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            FirestoreDebugLogger.denied(
              path: path,
              operation: 'listen',
              error: error,
            );
            return;
          }
          FirestoreDebugLogger.failure(
            path: path,
            operation: 'listen',
            error: error,
          );
        })
        .map((snapshot) {
          FirestoreDebugLogger.success(path: path, operation: 'listen');
          final plans = snapshot.docs
              .map((doc) => Plan.fromMap({'id': doc.id, ...doc.data()}))
              .toList();
          plans.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return plans;
        });
  }

  @override
  Future<void> updatePlanStatus({
    required String planId,
    required bool isActive,
  }) async {
    if (!_firebaseConfigured || planId.isEmpty) {
      throw StateError('Firebase غير مهيأ أو planId غير صالح.');
    }
    final path = 'plans/$planId';
    FirestoreDebugLogger.attempt(path: path, operation: 'update');

    try {
      await _plansCollection.doc(planId).update({'isActive': isActive});
      FirestoreDebugLogger.success(path: path, operation: 'update');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'update',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'update',
          error: error,
        );
      }
      rethrow;
    }
  }

  Future<void> _ensurePlan(Plan plan) async {
    final doc = _plansCollection.doc(plan.id);
    final path = 'plans/${plan.id}';
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await doc.get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      if (!snapshot.exists) {
        FirestoreDebugLogger.attempt(path: path, operation: 'set');
        await doc.set(plan.toMap());
        FirestoreDebugLogger.success(path: path, operation: 'set');
        return;
      }

      final existing = snapshot.data() ?? const <String, dynamic>{};
      final missingFields = <String, dynamic>{};
      final incoming = plan.toMap();
      for (final entry in incoming.entries) {
        if (!existing.containsKey(entry.key)) {
          missingFields[entry.key] = entry.value;
        }
      }

      if (missingFields.isNotEmpty) {
        FirestoreDebugLogger.attempt(path: path, operation: 'set(merge)');
        await doc.set(missingFields, SetOptions(merge: true));
        FirestoreDebugLogger.success(path: path, operation: 'set(merge)');
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'get/set',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'get/set',
          error: error,
        );
      }
      rethrow;
    }
  }

  Future<void> _ensureFeature({
    required String planId,
    required String featureKey,
    required Map<String, dynamic> data,
  }) async {
    final doc = _plansCollection
        .doc(planId)
        .collection('features')
        .doc(featureKey);
    final path = 'plans/$planId/features/$featureKey';
    FirestoreDebugLogger.attempt(path: path, operation: 'get');
    try {
      final snapshot = await doc.get();
      FirestoreDebugLogger.success(path: path, operation: 'get');
      if (!snapshot.exists) {
        FirestoreDebugLogger.attempt(path: path, operation: 'set');
        await doc.set({'featureKey': featureKey, ...data});
        FirestoreDebugLogger.success(path: path, operation: 'set');
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        FirestoreDebugLogger.denied(
          path: path,
          operation: 'get/set',
          error: error,
        );
      } else {
        FirestoreDebugLogger.failure(
          path: path,
          operation: 'get/set',
          error: error,
        );
      }
      rethrow;
    }
  }
}
