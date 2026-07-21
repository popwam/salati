import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/session/session_cache_service.dart';
import '../../core/services/app_preferences.dart';
import '../../core/services/app_services.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/firebase_analytics_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/user_data_sync_service.dart';
import '../../features/adhkar/data/local_adhkar_progress_repository.dart';
import '../../features/adhkar/data/local_adhkar_repository.dart';
import '../../features/admin/data/firestore_app_config_repository.dart';
import '../../features/auth/data/firebase_auth_service.dart';
import '../../features/prayer/data/firestore_prayer_reflection_repository.dart';
import '../../features/prayer/data/local_prayer_settings_repository.dart';
import '../../features/quran/data/local_quran_progress_repository.dart';
import '../../features/subscriptions/data/firestore_entitlement_repository.dart';
import '../../features/subscriptions/data/firestore_plan_feature_repository.dart';
import '../../features/subscriptions/data/firestore_plan_repository.dart';
import '../../features/subscriptions/data/firestore_user_profile_repository.dart';
import '../../features/subscriptions/data/billing_service.dart';
import '../../features/subscriptions/data/purchase_verification_service.dart';
import '../../features/subscriptions/data/user_media_repository.dart';
import '../../features/subscriptions/domain/entitlement_checker.dart';
import '../navigation/app_router.dart';
import 'app_bootstrap_result.dart';
import 'firebase_bootstrap.dart';
import 'startup_coordinator.dart';

class AppBootstrap {
  static Future<AppBootstrapResult> initialize({
    required void Function(String message) onStatusChanged,
  }) async {
    onStatusChanged('جاري تجهيز التطبيق...');

    final sharedPreferences = await SharedPreferences.getInstance();
    final appPreferences = AppPreferences(sharedPreferences);
    final sessionCacheService = SessionCacheService(sharedPreferences);
    final prayerSettingsRepository = LocalPrayerSettingsRepository(
      appPreferences,
    );
    final adhkarRepository = const LocalAdhkarRepository();
    final adhkarProgressRepository = LocalAdhkarProgressRepository(
      appPreferences,
    );
    final quranProgressRepository = LocalQuranProgressRepository(
      appPreferences,
    );

    final firebaseStatus = await FirebaseBootstrap.initialize();

    final analyticsService = FirebaseAnalyticsService(
      firebaseConfigured: firebaseStatus.isConfigured,
    );
    final crashReportingService = CrashReportingService(
      firebaseConfigured: firebaseStatus.isConfigured,
    );
    await crashReportingService.initialize();
    final notificationService = LocalNotificationService();
    await notificationService.initialize();

    final appConfigRepository = FirestoreAppConfigRepository(
      firebaseConfigured: firebaseStatus.isConfigured,
    );
    onStatusChanged('جاري تحميل الإعدادات...');

    final planRepository = FirestorePlanRepository(
      firebaseConfigured: firebaseStatus.isConfigured,
    );
    final authService = FirebaseAuthService(
      firebaseConfigured: firebaseStatus.isConfigured,
      sessionCacheService: sessionCacheService,
    );
    final userProfileRepository = FirestoreUserProfileRepository(
      firebaseConfigured: firebaseStatus.isConfigured,
    );

    final services = AppServices(
      firebaseConfigured: firebaseStatus.isConfigured,
      authService: authService,
      appConfigRepository: appConfigRepository,
      planRepository: planRepository,
      planFeatureRepository: FirestorePlanFeatureRepository(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
      entitlementRepository: FirestoreEntitlementRepository(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
      userProfileRepository: userProfileRepository,
      entitlementChecker: const EntitlementChecker(),
      analyticsService: analyticsService,
      crashReportingService: crashReportingService,
      notificationService: notificationService,
      prayerReflectionRepository: FirestorePrayerReflectionRepository(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
      userMediaRepository: FirebaseUserMediaRepository(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
      userDataSyncService: UserDataSyncService(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
      billingService: InAppPurchaseBillingService(),
      purchaseVerificationService: PurchaseVerificationService(
        firebaseConfigured: firebaseStatus.isConfigured,
      ),
    );

    final startupCoordinator = StartupCoordinator(
      authService: services.authService,
      appConfigRepository: services.appConfigRepository,
      userProfileRepository: services.userProfileRepository,
      sessionCacheService: sessionCacheService,
    );
    await startupCoordinator.prepareInitialSession(
      isWeb: kIsWeb,
      onStatusChanged: onStatusChanged,
    );

    await crashReportingService.setUserId(
      services.authService.currentSession?.uid,
    );
    await analyticsService.trackEvent('app_open');

    final router = AppRouter(
      preferences: appPreferences,
      services: services,
      firebaseConfigured: firebaseStatus.isConfigured,
      prayerSettingsRepository: prayerSettingsRepository,
      adhkarRepository: adhkarRepository,
      adhkarProgressRepository: adhkarProgressRepository,
      quranProgressRepository: quranProgressRepository,
    );

    final hasDashboardSession =
        sessionCacheService.currentSession?.hasDashboardAccess == true;

    final webInitialRoute = _webInitialRoute(
      hasDashboardSession: hasDashboardSession,
    );

    return AppBootstrapResult(
      router: router,
      preferences: appPreferences,
      firebaseConfigured: firebaseStatus.isConfigured,
      initialRoute: kIsWeb
          ? webInitialRoute
          : appPreferences.onboardingCompleted
          ? AppRouter.homeRoute
          : AppRouter.onboardingRoute,
    );
  }

  static String _webInitialRoute({required bool hasDashboardSession}) {
    final requestedRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final normalizedRoute = _normalizeWebRoute(requestedRoute);
    if (normalizedRoute != null) {
      return normalizedRoute;
    }

    return hasDashboardSession
        ? AppRouter.adminDashboardHomeRoute
        : AppRouter.adminLoginRoute;
  }

  static String? _normalizeWebRoute(String route) {
    final cleanRoute = route.split('?').first.split('#').first.trim();
    if (cleanRoute == AppRouter.adminRoute ||
        cleanRoute == AppRouter.adminLoginRoute ||
        cleanRoute == AppRouter.adminDashboardHomeRoute ||
        cleanRoute.startsWith('${AppRouter.adminDashboardHomeRoute}/')) {
      return cleanRoute;
    }
    return null;
  }
}
