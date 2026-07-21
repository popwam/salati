import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/app_preferences.dart';
import '../../core/services/app_services.dart';
import '../../features/adhkar/data/local_adhkar_progress_repository.dart';
import '../../features/adhkar/data/local_adhkar_repository.dart';
import '../../features/adhkar/presentation/adhkar_screen.dart';
import '../../features/admin_dashboard/data/firestore_admin_dashboard_access_repository.dart';
import '../../features/admin_dashboard/models/admin_dashboard_access.dart';
import '../../features/admin_dashboard/presentation/admin_content_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_ai_usage_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_app_customization_screen.dart';
import '../../features/admin_dashboard/presentation/admin_dashboard_home_screen.dart';
import '../../features/admin_dashboard/presentation/admin_dashboard_figma_screen.dart';
import '../../features/admin_dashboard/presentation/admin_languages_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_permissions_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_store_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_subscriptions_management_screen.dart';
import '../../features/admin_dashboard/presentation/admin_users_management_screen.dart';
import '../../features/admin/presentation/features_management_screen.dart';
import '../../features/admin/presentation/content_management_screen.dart';
import '../../features/admin/presentation/operational_settings_screen.dart';
import '../../features/admin/presentation/plans_management_screen.dart';
import '../../features/admin/presentation/users_subscriptions_screen.dart';
import '../../features/auth/models/auth_session.dart';
import '../../features/auth/presentation/admin_login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/islamic_ai/presentation/islamic_chat_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/prayer/data/prayer_settings_repository.dart';
import '../../features/prayer/presentation/prayer_screen.dart';
import '../../features/prayer/presentation/prayer_settings_screen.dart';
import '../../features/quran/data/local_quran_progress_repository.dart';
import '../../features/quran/presentation/quran_ai_placeholder_screen.dart';
import '../../features/quran/presentation/quran_ayah_reader_screen.dart';
import '../../features/quran/presentation/quran_page_reader_screen.dart';
import '../../features/quran/presentation/quran_screen.dart';
import '../../features/quran/presentation/quran_word_reader_screen.dart';
import '../../features/store/presentation/store_screen.dart';
import '../../features/subscriptions/presentation/subscription_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/screens/feedback_screen.dart';
import '../../shared/screens/legal_document_screen.dart';

class AppRouter {
  AppRouter({
    required AppPreferences preferences,
    required AppServices services,
    required bool firebaseConfigured,
    required PrayerSettingsRepository prayerSettingsRepository,
    required LocalAdhkarRepository adhkarRepository,
    required LocalAdhkarProgressRepository adhkarProgressRepository,
    required LocalQuranProgressRepository quranProgressRepository,
  }) : _preferences = preferences,
       _services = services,
       _firebaseConfigured = firebaseConfigured,
       _prayerSettingsRepository = prayerSettingsRepository,
       _adhkarRepository = adhkarRepository,
       _adhkarProgressRepository = adhkarProgressRepository,
       _quranProgressRepository = quranProgressRepository;

  static const splashRoute = '/';
  static const onboardingRoute = '/onboarding';
  static const homeRoute = '/home';
  static const prayerRoute = '/prayer';
  static const adhkarRoute = '/adhkar';
  static const quranRoute = '/quran';
  static const quranPageReaderRoute = '/quran/page-reader';
  static const quranAyahReaderRoute = '/quran/ayah-reader';
  static const quranWordReaderRoute = '/quran/word-reader';
  static const quranAiRoute = '/quran/ai';
  static const islamicAiRoute = '/islamic-ai';
  static const prayerSettingsRoute = '/prayer/settings';
  static const subscriptionsRoute = '/subscriptions';
  static const storeRoute = '/store';
  static const privacyPolicyRoute = '/legal/privacy';
  static const termsRoute = '/legal/terms';
  static const childSafetyRoute = '/legal/child-safety';
  static const accountDeletionRoute = '/legal/account-deletion';
  static const feedbackRoute = '/support/feedback';
  static const adminRoute = '/admin';
  static const adminLoginRoute = '/admin/login';
  static const adminDashboardHomeRoute = '/admin/dashboard';
  static const adminDashboardUsersRoute = '/admin/dashboard/users';
  static const adminDashboardPermissionsRoute = '/admin/dashboard/permissions';
  static const adminDashboardSubscriptionsRoute =
      '/admin/dashboard/subscriptions';
  static const adminDashboardLanguagesRoute = '/admin/dashboard/languages';
  static const adminDashboardAzkarRoute = '/admin/dashboard/azkar';
  static const adminDashboardDuasRoute = '/admin/dashboard/duas';
  static const adminDashboardMoshafRoute = '/admin/dashboard/moshaf';
  static const adminDashboardHadithRoute = '/admin/dashboard/hadith';
  static const adminDashboardAdhanRoute = '/admin/dashboard/adhan';
  static const adminDashboardRecitersRoute = '/admin/dashboard/reciters';
  static const adminDashboardLessonsRoute = '/admin/dashboard/lessons';
  static const adminDashboardNasheedsRoute = '/admin/dashboard/nasheeds';
  static const adminDashboardThemesRoute = '/admin/dashboard/themes';
  static const adminDashboardStoreRoute = '/admin/dashboard/store';
  static const adminDashboardSharedRoute = '/admin/dashboard/shared';
  static const adminDashboardGeneralSettingsRoute =
      '/admin/dashboard/general-settings';
  static const adminDashboardAiUsageRoute = '/admin/dashboard/ai-usage';
  static const adminDashboardAppConfigRoute = '/admin/dashboard/app-config';
  static const adminDashboardMaintenanceRoute = '/admin/dashboard/maintenance';
  static const adminDashboardSecurityRoute = '/admin/dashboard/security';
  static const adminDashboardDocsRoute = '/admin/dashboard/docs';
  static const adminDashboardSupportRoute = '/admin/dashboard/support';
  static const adminDashboardStreamRoute = '/admin/dashboard/stream';
  static const adminSettingsRoute = '/admin/settings';
  static const adminPlansRoute = '/admin/plans';
  static const adminFeaturesRoute = '/admin/features';
  static const adminUsersRoute = '/admin/users';
  static const adminContentRoute = '/admin/content';

  final AppPreferences _preferences;
  final AppServices _services;
  final bool _firebaseConfigured;
  final PrayerSettingsRepository _prayerSettingsRepository;
  final LocalAdhkarRepository _adhkarRepository;
  final LocalAdhkarProgressRepository _adhkarProgressRepository;
  final LocalQuranProgressRepository _quranProgressRepository;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? splashRoute;

    switch (routeName) {
      case splashRoute:
        return _buildRoute(
          SplashScreen(
            isWeb: kIsWeb,
            firebaseConfigured: _firebaseConfigured,
            services: _services,
          ),
          settings,
        );
      case onboardingRoute:
        return _buildRoute(
          OnboardingScreen(preferences: _preferences, services: _services),
          settings,
        );
      case homeRoute:
        return _buildRoute(
          HomeScreen(
            preferences: _preferences,
            services: _services,
            prayerSettingsRepository: _prayerSettingsRepository,
            adhkarRepository: _adhkarRepository,
            adhkarProgressRepository: _adhkarProgressRepository,
            quranProgressRepository: _quranProgressRepository,
          ),
          settings,
        );
      case prayerRoute:
        return _buildRoute(
          PrayerScreen(
            repository: _prayerSettingsRepository,
            preferences: _preferences,
            services: _services,
          ),
          settings,
        );
      case prayerSettingsRoute:
        return _buildRoute(
          PrayerSettingsScreen(
            repository: _prayerSettingsRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case adhkarRoute:
        return _buildRoute(
          AdhkarScreen(
            repository: _adhkarRepository,
            progressRepository: _adhkarProgressRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case quranRoute:
        return _buildRoute(
          QuranHubScreen(
            repository: _quranProgressRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case quranPageReaderRoute:
        return _buildRoute(
          QuranPageReaderScreen(
            repository: _quranProgressRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case quranAyahReaderRoute:
        return _buildRoute(
          QuranAyahReaderScreen(
            repository: _quranProgressRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case quranWordReaderRoute:
        return _buildRoute(
          QuranWordReaderScreen(
            repository: _quranProgressRepository,
            services: _services,
            preferences: _preferences,
          ),
          settings,
        );
      case quranAiRoute:
        return _buildRoute(
          QuranAiPlaceholderScreen(services: _services),
          settings,
        );
      case islamicAiRoute:
        return _buildRoute(IslamicChatScreen(services: _services), settings);
      case subscriptionsRoute:
        return _buildRoute(SubscriptionScreen(services: _services), settings);
      case storeRoute:
        return _buildRoute(
          StoreScreen(services: _services, preferences: _preferences),
          settings,
        );
      case privacyPolicyRoute:
        return _buildRoute(
          const LegalDocumentScreen(type: LegalDocumentType.privacy),
          settings,
        );
      case termsRoute:
        return _buildRoute(
          const LegalDocumentScreen(type: LegalDocumentType.terms),
          settings,
        );
      case childSafetyRoute:
        return _buildRoute(
          const LegalDocumentScreen(type: LegalDocumentType.childSafety),
          settings,
        );
      case accountDeletionRoute:
        return _buildRoute(
          const LegalDocumentScreen(type: LegalDocumentType.accountDeletion),
          settings,
        );
      case feedbackRoute:
        return _buildRoute(const FeedbackScreen(), settings);
      case adminRoute:
        return _buildAdminRoute(
          _AdminEntryScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminLoginRoute:
        return _buildAdminRoute(
          AdminLoginScreen(
            authService: _services.authService,
            userProfileRepository: _services.userProfileRepository,
            appConfigRepository: _services.appConfigRepository,
            planRepository: _services.planRepository,
            firebaseConfigured: _firebaseConfigured,
            initialMessage: settings.arguments is String
                ? settings.arguments! as String
                : null,
          ),
          settings,
        );
      case adminDashboardHomeRoute:
        return _buildAdminRoute(
          AdminDashboardHomeScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardUsersRoute:
        return _buildAdminRoute(
          AdminUsersManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardPermissionsRoute:
        return _buildAdminRoute(
          AdminPermissionsManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardSubscriptionsRoute:
        return _buildAdminRoute(
          AdminSubscriptionsManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardLanguagesRoute:
        return _buildAdminRoute(
          AdminLanguagesManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardAzkarRoute:
        return _buildAdminRoute(
          AdminContentManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
            config: const AdminContentManagementConfig(
              title: 'إدارة الأذكار',
              currentRoute: adminDashboardAzkarRoute,
              requiredPermission: AdminDashboardPermission.dashboardView,
              collectionPath: 'content/adhkar/categories',
              categoryLabel: 'القسم',
              itemLabel: 'الذكر',
              itemTitleEnabled: false,
              repeatCountEnabled: true,
            ),
          ),
          settings,
        );
      case adminDashboardDuasRoute:
        return _buildAdminRoute(
          AdminContentManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
            config: const AdminContentManagementConfig(
              title: 'إدارة الأدعية',
              currentRoute: adminDashboardDuasRoute,
              requiredPermission: AdminDashboardPermission.dashboardView,
              collectionPath: 'content/dua/categories',
              categoryLabel: 'القسم',
              itemLabel: 'الدعاء',
              itemTitleEnabled: false,
              repeatCountEnabled: true,
            ),
          ),
          settings,
        );
      case adminDashboardMoshafRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.quranAssets(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardHadithRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.hadith(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardAdhanRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.adhanSounds(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardRecitersRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.reciters(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardLessonsRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.lessons(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardNasheedsRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.nasheeds(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardThemesRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.themes(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardStoreRoute:
        return _buildAdminRoute(
          AdminStoreManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardSharedRoute:
        return _buildAdminRoute(
          AdminAppCustomizationScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardGeneralSettingsRoute:
        return _buildAdminRoute(
          AdminAppCustomizationScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardAiUsageRoute:
        return _buildAdminRoute(
          AdminAiUsageManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardMaintenanceRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.maintenance(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardSecurityRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.security(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardDocsRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.docs(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardSupportRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.support(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardStreamRoute:
        return _buildAdminRoute(
          AdminDashboardFigmaScreen.stream(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminDashboardAppConfigRoute:
        return _buildAdminRoute(
          AdminAppCustomizationScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminSettingsRoute:
        return _buildRoute(
          OperationalSettingsScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminPlansRoute:
        return _buildRoute(
          PlansManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminFeaturesRoute:
        return _buildRoute(
          FeaturesManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminUsersRoute:
        return _buildRoute(
          UsersSubscriptionsScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      case adminContentRoute:
        return _buildRoute(
          ContentManagementScreen(
            services: _services,
            firebaseConfigured: _firebaseConfigured,
          ),
          settings,
        );
      default:
        return _buildRoute(
          HomeScreen(
            preferences: _preferences,
            services: _services,
            prayerSettingsRepository: _prayerSettingsRepository,
            adhkarRepository: _adhkarRepository,
            adhkarProgressRepository: _adhkarProgressRepository,
            quranProgressRepository: _quranProgressRepository,
          ),
          settings,
        );
    }
  }

  MaterialPageRoute<dynamic> _buildRoute(Widget child, RouteSettings settings) {
    return MaterialPageRoute<void>(builder: (_) => child, settings: settings);
  }

  Route<dynamic> _buildAdminRoute(Widget child, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(fadeAnimation);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }
}

class _AdminEntryScreen extends StatelessWidget {
  const _AdminEntryScreen({
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  Widget build(BuildContext context) {
    if (!firebaseConfigured) {
      return const _AdminRouteRedirect(
        routeName: AppRouter.adminLoginRoute,
        message:
            'تعذر تحميل إعدادات Firebase. يمكنك فتح صفحة تسجيل الدخول والمحاولة مجددًا.',
      );
    }

    return StreamBuilder<AuthSession?>(
      stream: services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return const _AdminRouteRedirect(
            routeName: AppRouter.adminLoginRoute,
            message:
                'تعذر التحقق من جلسة الدخول. افتح صفحة تسجيل الدخول وحاول مرة أخرى.',
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AdminRoutingLoadingView();
        }

        final session = authSnapshot.data;
        if (session == null) {
          return const _AdminRouteRedirect(
            routeName: AppRouter.adminLoginRoute,
          );
        }

        return StreamBuilder<AdminDashboardAccess?>(
          stream: FirestoreAdminDashboardAccessRepository(
            authService: services.authService,
            firebaseConfigured: firebaseConfigured,
          ).watchCurrentAccess(),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return const _AdminRouteRedirect(
                routeName: AppRouter.adminLoginRoute,
                message:
                    'تعذر تحميل صلاحيات الإدارة. يمكنك تسجيل الدخول مجددًا.',
              );
            }

            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const _AdminRoutingLoadingView();
            }

            final access = accessSnapshot.data;
            if (access != null && access.canOpenDashboardHome) {
              return const _AdminRouteRedirect(
                routeName: AppRouter.adminDashboardHomeRoute,
              );
            }

            return const _AdminNoPermissionView();
          },
        );
      },
    );
  }
}

class _AdminRouteRedirect extends StatefulWidget {
  const _AdminRouteRedirect({required this.routeName, this.message});

  final String routeName;
  final String? message;

  @override
  State<_AdminRouteRedirect> createState() => _AdminRouteRedirectState();
}

class _AdminRouteRedirectState extends State<_AdminRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushReplacementNamed(widget.routeName, arguments: widget.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _AdminRoutingLoadingView();
  }
}

class _AdminRoutingLoadingView extends StatelessWidget {
  const _AdminRoutingLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AdminNoPermissionView extends StatelessWidget {
  const _AdminNoPermissionView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'هذا الحساب لا يملك صلاحية دخول لوحة الإدارة.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
