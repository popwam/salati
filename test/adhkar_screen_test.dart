import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salati/core/services/app_preferences.dart';
import 'package:salati/core/services/app_services.dart';
import 'package:salati/core/services/crash_reporting_service.dart';
import 'package:salati/core/services/firebase_analytics_service.dart';
import 'package:salati/core/services/local_notification_service.dart';
import 'package:salati/core/services/user_data_sync_service.dart';
import 'package:salati/features/adhkar/data/local_adhkar_progress_repository.dart';
import 'package:salati/features/adhkar/data/local_adhkar_repository.dart';
import 'package:salati/features/adhkar/presentation/adhkar_screen.dart';
import 'package:salati/features/admin/data/firestore_app_config_repository.dart';
import 'package:salati/features/auth/data/firebase_auth_service.dart';
import 'package:salati/features/prayer/data/firestore_prayer_reflection_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_entitlement_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_plan_feature_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_plan_repository.dart';
import 'package:salati/features/subscriptions/data/firestore_user_profile_repository.dart';
import 'package:salati/features/subscriptions/data/billing_service.dart';
import 'package:salati/features/subscriptions/data/purchase_verification_service.dart';
import 'package:salati/features/subscriptions/data/user_media_repository.dart';
import 'package:salati/features/subscriptions/domain/entitlement_checker.dart';

void main() {
  testWidgets('tapping an adhkar category opens its details page', (
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
      MaterialApp(
        home: AdhkarScreen(
          repository: const LocalAdhkarRepository(),
          progressRepository: LocalAdhkarProgressRepository(preferences),
          services: services,
          preferences: preferences,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('أذكار الصباح'));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });
}
