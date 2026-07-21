import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_scaffold.dart';

class AdminDashboardPlaceholderScreen extends StatefulWidget {
  const AdminDashboardPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.currentRoute,
    required this.requiredPermission,
    required this.services,
    required this.firebaseConfigured,
  });

  final String title;
  final String description;
  final String currentRoute;
  final String requiredPermission;
  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminDashboardPlaceholderScreen> createState() =>
      _AdminDashboardPlaceholderScreenState();
}

class _AdminDashboardPlaceholderScreenState
    extends State<AdminDashboardPlaceholderScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminDashboardGuard(
      accessRepository: _accessRepository,
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
      requiredPermission: widget.requiredPermission,
      builder: (context, access) {
        return AdminDashboardScaffold(
          title: widget.title,
          currentRoute: widget.currentRoute,
          access: access,
          services: widget.services,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.description),
                      const SizedBox(height: 20),
                      Text(
                        'هذه الصفحة مرتبطة الآن بالـ routing والـ permission guard، وسيتم تنفيذ وظائفها الكاملة في الخطوة التالية.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
