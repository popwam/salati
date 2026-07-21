import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../models/admin_dashboard_access.dart';
import 'admin_dashboard_localization.dart';

class AdminDashboardDestination {
  const AdminDashboardDestination({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.permission,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final String permission;
}

void navigateToAdminDashboardRoute(
  BuildContext context, {
  required String currentRoute,
  required String targetRoute,
  bool closeDrawerFirst = false,
}) {
  if (currentRoute == targetRoute) {
    return;
  }
  final navigator = Navigator.of(context);
  if (closeDrawerFirst && navigator.canPop()) {
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushNamed(targetRoute);
    });
    return;
  }
  navigator.pushNamed(targetRoute);
}

List<AdminDashboardDestination> buildAdminDashboardDestinations(
  BuildContext context,
  AdminDashboardAccess access,
) {
  final localizer = AdminDashboardLocalizer.of(context);

  AdminDashboardDestination destination(String route, IconData icon) {
    return AdminDashboardDestination(
      title: localizer.routeTitle(route),
      subtitle: localizer.routeSubtitle(route),
      route: route,
      icon: icon,
      permission: AdminDashboardPermission.dashboardView,
    );
  }

  final destinations = [
    destination(AppRouter.adminDashboardHomeRoute, Icons.dashboard_outlined),
    destination(
      AppRouter.adminDashboardAzkarRoute,
      Icons.auto_stories_outlined,
    ),
    destination(AppRouter.adminDashboardDuasRoute, Icons.menu_book_outlined),
    destination(
      AppRouter.adminDashboardMoshafRoute,
      Icons.chrome_reader_mode_outlined,
    ),
    destination(
      AppRouter.adminDashboardHadithRoute,
      Icons.history_edu_outlined,
    ),
    destination(AppRouter.adminDashboardAdhanRoute, Icons.volume_up_outlined),
    destination(
      AppRouter.adminDashboardRecitersRoute,
      Icons.record_voice_over_outlined,
    ),
    destination(AppRouter.adminDashboardLessonsRoute, Icons.school_outlined),
    destination(
      AppRouter.adminDashboardNasheedsRoute,
      Icons.library_music_outlined,
    ),
    destination(AppRouter.adminDashboardThemesRoute, Icons.palette_outlined),
    destination(
      AppRouter.adminDashboardGeneralSettingsRoute,
      Icons.settings_outlined,
    ),
    destination(AppRouter.adminDashboardUsersRoute, Icons.people_alt_outlined),
    destination(AppRouter.adminDashboardStreamRoute, Icons.graphic_eq_outlined),
  ];

  final allowed = access.isLocalMode
      ? destinations
            .where((item) => item.route == AppRouter.adminDashboardHomeRoute)
            .toList(growable: false)
      : destinations;

  return allowed
      .where(
        (item) => item.route == AppRouter.adminDashboardHomeRoute
            ? access.canOpenDashboardHome
            : access.can(item.permission),
      )
      .toList(growable: false);
}

class AdminDashboardScaffold extends StatelessWidget {
  const AdminDashboardScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.access,
    required this.services,
    required this.child,
  });

  final String title;
  final String currentRoute;
  final AdminDashboardAccess access;
  final AppServices services;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final localizer = AdminDashboardLocalizer.of(context);
    final destinations = buildAdminDashboardDestinations(context, access);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1040;
    final resolvedTitle = localizer.routeTitle(currentRoute);
    final padding = width < 600 ? 12.0 : 20.0;

    return Directionality(
      textDirection: localizer.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF9),
        drawer: isWide
            ? null
            : Drawer(
                child: _DashboardSidebar(
                  currentRoute: currentRoute,
                  destinations: destinations,
                  access: access,
                  services: services,
                  closeDrawerFirst: true,
                ),
              ),
        appBar: AppBar(
          title: Text(resolvedTitle.isEmpty ? title : resolvedTitle),
          elevation: 0,
          backgroundColor: const Color(0xFFF8FAF9),
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: localizer.text(
                ar: 'تسجيل الخروج',
                en: 'Sign out',
                fr: 'Déconnexion',
              ),
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWide) ...[
                  SizedBox(
                    width: 80,
                    child: _DashboardSidebar(
                      currentRoute: currentRoute,
                      destinations: destinations,
                      access: access,
                      services: services,
                      closeDrawerFirst: false,
                    ),
                  ),
                  const SizedBox(width: 18),
                ],
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE6E8EC)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: KeyedSubtree(
                          key: ValueKey(currentRoute),
                          child: access.isLocalMode
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const _LocalAdminModeBanner(),
                                    const SizedBox(height: 12),
                                    Expanded(child: child),
                                  ],
                                )
                              : child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await services.authService.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.adminLoginRoute, (route) => false);
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.currentRoute,
    required this.destinations,
    required this.access,
    required this.services,
    required this.closeDrawerFirst,
  });

  final String currentRoute;
  final List<AdminDashboardDestination> destinations;
  final AdminDashboardAccess access;
  final AppServices services;
  final bool closeDrawerFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizer = AdminDashboardLocalizer.of(context);

    if (!closeDrawerFirst) {
      return _DashboardRail(
        currentRoute: currentRoute,
        destinations: destinations,
        access: access,
        services: services,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.mosque_outlined,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Salati',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(adminDashboardRoleLabel(access.role))),
                    if (access.email != null) Chip(label: Text(access.email!)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final item = destinations[index];
                final selected = item.route == currentRoute;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0xFFE8F5F1),
                    leading: Icon(
                      item.icon,
                      color: selected ? const Color(0xFF0F766E) : null,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () => navigateToAdminDashboardRoute(
                      context,
                      currentRoute: currentRoute,
                      targetRoute: item.route,
                      closeDrawerFirst: closeDrawerFirst,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () async {
                await services.authService.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.adminLoginRoute,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                localizer.text(
                  ar: 'تسجيل الخروج',
                  en: 'Sign out',
                  fr: 'Déconnexion',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardRail extends StatelessWidget {
  const _DashboardRail({
    required this.currentRoute,
    required this.destinations,
    required this.access,
    required this.services,
  });

  final String currentRoute;
  final List<AdminDashboardDestination> destinations;
  final AdminDashboardAccess access;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6E8EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.mosque_outlined, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: destinations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = destinations[index];
                return _RailIconButton(
                  tooltip: item.title,
                  icon: item.icon,
                  selected: item.route == currentRoute,
                  onTap: () => navigateToAdminDashboardRoute(
                    context,
                    currentRoute: currentRoute,
                    targetRoute: item.route,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _RailAvatar(access: access),
                const SizedBox(height: 8),
                _RailIconButton(
                  tooltip: 'Sign out',
                  icon: Icons.logout_rounded,
                  selected: false,
                  onTap: () async {
                    await services.authService.signOut();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.adminLoginRoute,
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF23262F);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: Center(
        child: Material(
          color: selected ? const Color(0xFFE8E7FF) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: foreground, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailAvatar extends StatelessWidget {
  const _RailAvatar({required this.access});

  final AdminDashboardAccess access;

  @override
  Widget build(BuildContext context) {
    final initial = access.name.trim().isEmpty
        ? 'S'
        : access.name.trim().characters.first.toUpperCase();
    return Tooltip(
      message: access.email ?? adminDashboardRoleLabel(access.role),
      child: CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFFFC044),
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LocalAdminModeBanner extends StatelessWidget {
  const _LocalAdminModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1D99A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.developer_mode_rounded, color: Color(0xFF8B5E00)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'وضع إدارة محلي للتطوير. الحفظ السحابي يحتاج Backend/Admin SDK.',
            ),
          ),
        ],
      ),
    );
  }
}
