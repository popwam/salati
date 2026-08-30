import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/localization/salati_localizations.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/models/nav_item.dart';
import '../../account/presentation/account_screen.dart';
import '../../adhkar/data/local_adhkar_progress_repository.dart';
import '../../adhkar/data/local_adhkar_repository.dart';
import '../../adhkar/presentation/adhkar_screen.dart';
import '../../auth/models/auth_session.dart';
import '../../dua/presentation/dua_screen.dart';
import '../../prayer/data/prayer_settings_repository.dart';
import '../../prayer/presentation/prayer_screen.dart';
import '../../prayer/services/prayer_notification_scheduler.dart';
import '../../quran/data/local_quran_progress_repository.dart';
import '../../quran/presentation/quran_reader_support.dart';
import '../data/islamic_content_provider.dart';
import 'islamic_provider_screen.dart';
import 'salati_dashboard_screen.dart';

const _supportedLocaleCodes = <String>[
  'ar',
  'en',
  'fr',
  'es',
  'de',
  'id',
  'tr',
  'ur',
];

String _localeLabel(String code) {
  return switch (code) {
    'en' => 'English',
    'fr' => 'Français',
    'es' => 'Español',
    'de' => 'Deutsch',
    'id' => 'Indonesia',
    'tr' => 'Türkçe',
    'ur' => 'اردو',
    _ => 'العربية',
  };
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.preferences,
    required this.services,
    required this.prayerSettingsRepository,
    required this.adhkarRepository,
    required this.adhkarProgressRepository,
    required this.quranProgressRepository,
  });

  final AppPreferences preferences;
  final AppServices services;
  final PrayerSettingsRepository prayerSettingsRepository;
  final LocalAdhkarRepository adhkarRepository;
  final LocalAdhkarProgressRepository adhkarProgressRepository;
  final LocalQuranProgressRepository quranProgressRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _rootIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _exitHint = 'اضغط مرة أخرى للخروج';
  late int _currentIndex;
  DateTime? _lastBackPressedAt;
  int? _drawerAccountReturnIndex;
  StreamSubscription<String>? _notificationPayloadSub;

  static List<NavItem> _items(SalatiLocalizations l10n) => [
    NavItem(
      label: l10n.text('salati'),
      icon: Icons.mosque_outlined,
      activeIcon: Icons.mosque_rounded,
    ),
    NavItem(
      label: 'الصلاة',
      icon: Icons.mosque_outlined,
      activeIcon: Icons.mosque_rounded,
    ),
    NavItem(
      label: l10n.text('adhkar'),
      icon: Icons.spa_outlined,
      activeIcon: Icons.spa_rounded,
    ),
    NavItem(
      label: l10n.text('duas'),
      icon: Icons.volunteer_activism_outlined,
      activeIcon: Icons.volunteer_activism_rounded,
    ),
    NavItem(
      label: 'الحلقات',
      icon: Icons.podcasts_outlined,
      activeIcon: Icons.podcasts_rounded,
    ),
    NavItem(
      label: 'المزيد',
      icon: Icons.more_vert_rounded,
      activeIcon: Icons.more_vert_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _rootIndex;
    widget.preferences.setSelectedUserTab(_rootIndex);
    _notificationPayloadSub = LocalNotificationService.notificationPayloads
        .listen((payload) => unawaited(_handleNotificationPayload(payload)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_requestInitialPermissionsOnce());
        final pendingPayload = LocalNotificationService.takePendingPayload();
        if (pendingPayload != null) {
          unawaited(_handleNotificationPayload(pendingPayload));
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationPayloadSub?.cancel();
    super.dispose();
  }

  Future<void> _requestInitialPermissionsOnce() async {
    if (widget.preferences.initialPermissionsRequested) {
      await _refreshPrayerNotifications();
      return;
    }
    await widget.preferences.setInitialPermissionsRequested(true);
    try {
      await widget.services.notificationService.requestPermissions();
    } catch (error) {
      debugPrint('[Home] notification permission request failed: $error');
    }
    if (kIsWeb) {
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      debugPrint('[Home] location permission state: $permission');
    } catch (error) {
      debugPrint('[Home] location permission request failed: $error');
    }

    await _refreshPrayerNotifications(forceEnablePrayerNotifications: true);
  }

  Future<void> _refreshPrayerNotifications({
    bool forceEnablePrayerNotifications = false,
    bool requestPermissions = false,
  }) async {
    await PrayerNotificationScheduler.scheduleFromSavedSettings(
      services: widget.services,
      preferences: widget.preferences,
      repository: widget.prayerSettingsRepository,
      forceEnablePrayerNotifications: forceEnablePrayerNotifications,
      requestPermissions: requestPermissions,
    );
  }

  Future<void> _handleNotificationPayload(String payload) async {
    if (!mounted) {
      return;
    }

    final parts = payload.split(':');
    if (parts.length < 2 || parts.first != 'quran_surah') {
      return;
    }

    final parsedSurah = int.tryParse(parts[1]);
    if (parsedSurah == null) {
      return;
    }
    final surah = parsedSurah.clamp(1, 114).toInt();

    await _openSurahFromNotification(surah);
  }

  Future<void> _openSurahFromNotification(int surah) async {
    final position = QuranReadingPosition(surah: surah, ayah: 1);
    final wird = QuranWird(
      id: 'notification_surah_$surah',
      name: _surahNotificationName(surah),
      position: position,
    );
    final savedWirds = loadSavedQuranWirds(
      widget.quranProgressRepository,
    ).where((item) => item.id != wird.id).toList(growable: false);
    await saveQuranWirds(widget.quranProgressRepository, [...savedWirds, wird]);
    await activateQuranWird(widget.quranProgressRepository, wird);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(AppRouter.quranAyahReaderRoute);
  }

  String _surahNotificationName(int surah) {
    return switch (surah) {
      18 => 'سورة الكهف',
      67 => 'سورة الملك',
      _ => 'سورة $surah',
    };
  }

  Future<void> _selectTab(
    int index, {
    bool preserveDrawerReturn = false,
  }) async {
    if (_currentIndex == index) {
      return;
    }

    _lastBackPressedAt = null;
    if (!preserveDrawerReturn) {
      _drawerAccountReturnIndex = null;
    }
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() {
      _currentIndex = index;
    });
    await widget.preferences.setSelectedUserTab(index);
  }

  void _logBack(String action) {
    debugPrint('[Back] selectedTab=$_currentIndex action=$action');
  }

  Future<void> _handleRootBack() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _logBack('close_drawer');
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }

    if (_currentIndex == 5 && _drawerAccountReturnIndex != null) {
      final returnIndex = _drawerAccountReturnIndex!;
      _drawerAccountReturnIndex = null;
      _logBack('return_previous_tab');
      await _selectTab(returnIndex);
      return;
    }

    if (_currentIndex != _rootIndex) {
      _logBack('go_to_salati');
      await _selectTab(_rootIndex);
      return;
    }

    final now = DateTime.now();
    final pressedRecently =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (pressedRecently) {
      _logBack('exit_app');
      await SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    _logBack('show_exit_hint');
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(_exitHint)));
    }
  }

  Future<void> _openRoute(String route) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed(route);
  }

  Future<void> _logoutToFreeSession() async {
    try {
      await widget.services.authService.signOut();
      if (!kIsWeb) {
        final config = await widget.services.appConfigRepository
            .loadOperationalConfig();
        await widget.services.authService.ensureMobileUserSession(
          allowAnonymous: config.authAvailability.anonymousEnabled,
        );
        final session = widget.services.authService.currentSession;
        if (session != null) {
          await widget.services.userProfileRepository.ensureUserProfile(
            uid: session.uid,
            email: session.email,
            defaultPlanId: config.defaultUserPlanId,
          );
        }
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الخروج والعودة إلى الحساب المجاني'),
        ),
      );
      await _selectTab(_rootIndex);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SalatiDashboardScreen(
        onOpenQuran: () =>
            Navigator.of(context).pushNamed(AppRouter.quranRoute),
        onOpenPrayer: () => unawaited(_selectTab(1)),
        onOpenAdhkar: () => unawaited(_selectTab(2)),
        onOpenDuas: () => unawaited(_selectTab(3)),
        onOpenAi: () =>
            Navigator.of(context).pushNamed(AppRouter.islamicAiRoute),
        onOpenStore: () =>
            Navigator.of(context).pushNamed(AppRouter.storeRoute),
        onUnavailable: (feature) {
          final kind = switch (feature) {
            'القبلة' => IslamicProviderKind.qibla,
            'المساجد' => IslamicProviderKind.mosques,
            'الحديث' => IslamicProviderKind.hadith,
            'القراء' => IslamicProviderKind.reciters,
            'الدروس' || 'الحلقات' => IslamicProviderKind.lessons,
            _ => null,
          };
          if (kind == null) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => IslamicProviderScreen(kind: kind),
            ),
          );
        },
      ),
      PrayerScreen(
        repository: widget.prayerSettingsRepository,
        preferences: widget.preferences,
        services: widget.services,
      ),
      AdhkarScreen(
        repository: widget.adhkarRepository,
        progressRepository: widget.adhkarProgressRepository,
        services: widget.services,
        preferences: widget.preferences,
      ),
      DuaScreen(services: widget.services, preferences: widget.preferences),
      const IslamicProviderScreen(kind: IslamicProviderKind.lessons),
      AccountScreen(services: widget.services, preferences: widget.preferences),
    ];

    final l10n = SalatiLocalizations.of(context);
    final navItems = _items(l10n);

    return StreamBuilder<AuthSession?>(
      stream: widget.services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              return;
            }
            await _handleRootBack();
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFF7F8FB),
            extendBody: true,
            drawerEnableOpenDragGesture: false,
            drawer: _MainDrawer(
              preferences: widget.preferences,
              services: widget.services,
              session: session,
              onOpenSubscription: () =>
                  _openRoute(AppRouter.subscriptionsRoute),
              onOpenStore: () => _openRoute(AppRouter.storeRoute),
              onOpenSettings: () => _openRoute(AppRouter.prayerSettingsRoute),
              onOpenAccount: () async {
                final previousIndex = _currentIndex;
                Navigator.of(context).pop();
                _drawerAccountReturnIndex = previousIndex == 5
                    ? null
                    : previousIndex;
                await _selectTab(
                  5,
                  preserveDrawerReturn: _drawerAccountReturnIndex != null,
                );
              },
              onLocaleChanged: widget.preferences.setLocaleCode,
              onThemeChanged: (enabled) {
                return widget.preferences.setThemeMode(
                  enabled ? ThemeMode.dark : ThemeMode.light,
                );
              },
              onLogout: _logoutToFreeSession,
            ),
            body: SafeArea(
              bottom: false,
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
            bottomNavigationBar: _MainBottomNavigation(
              items: navItems,
              currentIndex: _currentIndex,
              onSelected: (index) {
                if (index == 5) {
                  _scaffoldKey.currentState?.openDrawer();
                  return;
                }
                unawaited(_selectTab(index));
              },
            ),
          ),
        );
      },
    );
  }
}

class _MainDrawer extends StatelessWidget {
  const _MainDrawer({
    required this.preferences,
    required this.services,
    required this.session,
    required this.onOpenSubscription,
    required this.onOpenStore,
    required this.onOpenSettings,
    required this.onOpenAccount,
    required this.onLocaleChanged,
    required this.onThemeChanged,
    required this.onLogout,
  });

  final AppPreferences preferences;
  final AppServices services;
  final AuthSession? session;
  final Future<void> Function() onOpenSubscription;
  final Future<void> Function() onOpenStore;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenAccount;
  final Future<void> Function(String localeCode) onLocaleChanged;
  final Future<void> Function(bool enabled) onThemeChanged;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = SalatiLocalizations.of(context);
    final isDarkMode = preferences.themeMode == ThemeMode.dark;
    final isAnonymous = session?.isAnonymous ?? true;

    final userStream = session == null
        ? Stream<AppUser?>.value(null)
        : services.userProfileRepository.watchCurrentUser(session!.uid);

    return Drawer(
      child: StreamBuilder<AppUser?>(
        stream: userStream,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final planStatus = user?.effectivePlanId ?? 'free';
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.82),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      l10n.text('appName'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAnonymous
                          ? 'تجربة مجانية بدون تسجيل يدوي'
                          : 'حسابك مرتبط وجاهز للاستعادة',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(l10n.text('subscription')),
                subtitle: Text(planStatus),
                onTap: onOpenSubscription,
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(l10n.text('store')),
                onTap: onOpenStore,
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.text('prayerSettings')),
                onTap: onOpenSettings,
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(l10n.text('profile')),
                subtitle: Text(l10n.text('appearanceFonts')),
                onTap: onOpenAccount,
              ),
              const Divider(height: 24),
              SwitchListTile.adaptive(
                value: isDarkMode,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.text('darkMode')),
                subtitle: Text(l10n.text('darkModeSubtitle')),
                onChanged: onThemeChanged,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
                child: Text(
                  l10n.text('language'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _supportedLocaleCodes.contains(preferences.localeCode)
                      ? preferences.localeCode
                      : 'ar',
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.translate_rounded),
                    labelText: l10n.text('languagePickerLabel'),
                  ),
                  items: _supportedLocaleCodes
                      .map(
                        (code) => DropdownMenuItem<String>(
                          value: code,
                          child: Text(_localeLabel(code)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      onLocaleChanged(value);
                    }
                  },
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(
                  isAnonymous ? Icons.login_rounded : Icons.logout_rounded,
                ),
                title: Text(
                  isAnonymous ? l10n.text('loginOrLink') : l10n.text('logout'),
                ),
                onTap: isAnonymous ? onOpenAccount : onLogout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainBottomNavigation extends StatelessWidget {
  const _MainBottomNavigation({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFF0EFED))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2937).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelected(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        color: selected
                            ? const Color(0xFF1677FF)
                            : const Color(0xFF333333),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1677FF)
                              : const Color(0xFF333333),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
