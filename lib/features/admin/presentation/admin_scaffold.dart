import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.child,
    required this.services,
    required this.firebaseConfigured,
  });

  final String title;
  final String currentRoute;
  final Widget child;
  final AppServices services;
  final bool firebaseConfigured;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      _AdminDestination(
        label: 'التشغيل',
        route: AppRouter.adminSettingsRoute,
        icon: Icons.settings_suggest_outlined,
      ),
      _AdminDestination(
        label: 'الخطط',
        route: AppRouter.adminPlansRoute,
        icon: Icons.view_list_rounded,
      ),
      _AdminDestination(
        label: 'الميزات',
        route: AppRouter.adminFeaturesRoute,
        icon: Icons.tune_rounded,
      ),
      _AdminDestination(
        label: 'المستخدمون',
        route: AppRouter.adminUsersRoute,
        icon: Icons.groups_rounded,
      ),
      _AdminDestination(
        label: 'المحتوى',
        route: AppRouter.adminContentRoute,
        icon: Icons.library_books_outlined,
      ),
    ];

    final selectedIndex = destinations.indexWhere(
      (item) => item.route == currentRoute,
    );

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              final destination = destinations[index];
              if (destination.route != currentRoute) {
                Navigator.of(context).pushReplacementNamed(destination.route);
              }
            },
            destinations: destinations
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  if (firebaseConfigured)
                    TextButton(
                      onPressed: () async {
                        await services.authService.signOut();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRouter.adminLoginRoute);
                        }
                      },
                      child: const Text('خروج'),
                    ),
                ],
              ),
              body: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}
