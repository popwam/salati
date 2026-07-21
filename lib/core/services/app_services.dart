import '../../features/admin/data/app_config_repository.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/prayer/data/prayer_reflection_repository.dart';
import '../../features/subscriptions/data/entitlement_repository.dart';
import '../../features/subscriptions/data/billing_service.dart';
import '../../features/subscriptions/data/plan_feature_repository.dart';
import '../../features/subscriptions/data/plan_repository.dart';
import '../../features/subscriptions/data/purchase_verification_service.dart';
import '../../features/subscriptions/data/user_media_repository.dart';
import '../../features/subscriptions/data/user_profile_repository.dart';
import '../../features/subscriptions/domain/entitlement_checker.dart';
import 'analytics_service.dart';
import 'crash_reporting_service.dart';
import 'notification_service.dart';
import 'user_data_sync_service.dart';

class AppServices {
  const AppServices({
    required this.firebaseConfigured,
    required this.authService,
    required this.appConfigRepository,
    required this.planRepository,
    required this.planFeatureRepository,
    required this.entitlementRepository,
    required this.userProfileRepository,
    required this.entitlementChecker,
    required this.analyticsService,
    required this.crashReportingService,
    required this.notificationService,
    required this.prayerReflectionRepository,
    required this.userMediaRepository,
    required this.userDataSyncService,
    required this.billingService,
    required this.purchaseVerificationService,
  });

  final bool firebaseConfigured;
  final AuthService authService;
  final AppConfigRepository appConfigRepository;
  final PlanRepository planRepository;
  final PlanFeatureRepository planFeatureRepository;
  final EntitlementRepository entitlementRepository;
  final UserProfileRepository userProfileRepository;
  final EntitlementChecker entitlementChecker;
  final AnalyticsService analyticsService;
  final CrashReportingService crashReportingService;
  final NotificationService notificationService;
  final PrayerReflectionRepository prayerReflectionRepository;
  final UserMediaRepository userMediaRepository;
  final UserDataSyncService userDataSyncService;
  final BillingService billingService;
  final PurchaseVerificationService purchaseVerificationService;
}
