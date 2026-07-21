import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salati/app/app.dart';
import 'package:salati/app/navigation/app_router.dart';
import 'package:salati/core/services/app_preferences.dart';
import 'package:salati/core/services/app_services.dart';
import 'package:salati/core/services/crash_reporting_service.dart';
import 'package:salati/core/services/firebase_analytics_service.dart';
import 'package:salati/core/services/local_notification_service.dart';
import 'package:salati/core/services/user_data_sync_service.dart';
import 'package:salati/features/adhkar/data/local_adhkar_progress_repository.dart';
import 'package:salati/features/adhkar/data/local_adhkar_repository.dart';
import 'package:salati/features/admin/data/firestore_app_config_repository.dart';
import 'package:salati/features/auth/data/firebase_auth_service.dart';
import 'package:salati/features/prayer/data/firestore_prayer_reflection_repository.dart';
import 'package:salati/features/prayer/data/local_prayer_settings_repository.dart';
import 'package:salati/features/quran/data/local_quran_progress_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_entitlement_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_plan_feature_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_plan_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_user_profile_repository.dart';
import 'package:salati/features/subscriptions/data/billing_service.dart';
import 'package:salati/features/subscriptions/data/purchase_verification_service.dart';
import 'package:salati/features/subscriptions/data/user_media_repository.dart';
import 'package:salati/features/subscriptions/domain/entitlement_checker.dart';

void main() {
  testWidgets('renders main navigation with the centered Salati tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final services = AppServices(
      firebaseConfigured: false,
      authService: FirebaseAuthService(firebaseConfigured: false),
      appConfigRepository: FirestoreAppConfigRepository(
        firebaseConfigured: false,
      ),
      planRepository: FirestorePlanRepository(firebaseConfigured: false),
      planFeatureRepository: FirestorePlanFeatureRepository(
        firebaseConfigured: false,
      ),
      entitlementRepository: FirestoreEntitlementRepository(
        firebaseConfigured: false,
      ),
      userProfileRepository: FirestoreUserProfileRepository(
        firebaseConfigured: false,
      ),
      entitlementChecker: const EntitlementChecker(),
      analyticsService: FirebaseAnalyticsService(firebaseConfigured: false),
      crashReportingService: CrashReportingService(firebaseConfigured: false),
      notificationService: LocalNotificationService(),
      prayerReflectionRepository: FirestorePrayerReflectionRepository(
        firebaseConfigured: false,
      ),
      userMediaRepository: FirebaseUserMediaRepository(
        firebaseConfigured: false,
      ),
      userDataSyncService: UserDataSyncService(firebaseConfigured: false),
      billingService: InAppPurchaseBillingService(),
      purchaseVerificationService: PurchaseVerificationService(
        firebaseConfigured: false,
      ),
    );

    await tester.pumpWidget(
      SalatiApp(
        router: AppRouter(
          preferences: preferences,
          services: services,
          firebaseConfigured: false,
          prayerSettingsRepository: LocalPrayerSettingsRepository(preferences),
          adhkarRepository: const LocalAdhkarRepository(),
          adhkarProgressRepository: LocalAdhkarProgressRepository(preferences),
          quranProgressRepository: LocalQuranProgressRepository(preferences),
        ),
        preferences: preferences,
        firebaseConfigured: false,
        initialRoute: AppRouter.homeRoute,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('صلاتي'), findsWidgets);
    expect(find.text('الأذكار'), findsWidgets);
    expect(find.text('القرآن'), findsWidgets);
    expect(find.text('الأدعية'), findsWidgets);
    expect(find.text('الملف'), findsWidgets);
  });
}
