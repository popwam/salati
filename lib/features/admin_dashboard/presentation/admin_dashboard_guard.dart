import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/models/auth_session.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../models/admin_dashboard_access.dart';

class AdminDashboardGuard extends StatelessWidget {
  const AdminDashboardGuard({
    super.key,
    required this.accessRepository,
    required this.authService,
    required this.firebaseConfigured,
    required this.requiredPermission,
    required this.builder,
  });

  final FirestoreAdminDashboardAccessRepository accessRepository;
  final AuthService authService;
  final bool firebaseConfigured;
  final String requiredPermission;
  final Widget Function(BuildContext context, AdminDashboardAccess access)
  builder;

  @override
  Widget build(BuildContext context) {
    if (!firebaseConfigured) {
      return const _AdminDashboardLoginRedirect(
        message:
            'تعذر تحميل إعدادات Firebase. يمكنك فتح صفحة تسجيل الدخول والمحاولة مجددًا.',
      );
    }

    return StreamBuilder<AuthSession?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _AdminDashboardLoginRedirect(
            message: mapAppErrorToArabic(authSnapshot.error!),
          );
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AdminDashboardLoadingView(
            label: 'جاري التحقق من جلسة الدخول...',
          );
        }

        if (authSnapshot.data == null) {
          return const _AdminDashboardLoginRedirect();
        }

        return StreamBuilder<AdminDashboardAccess?>(
          stream: accessRepository.watchCurrentAccess(),
          builder: (context, accessSnapshot) {
            final access = accessSnapshot.data;
            final requiresDashboardEntry =
                requiredPermission == AdminDashboardPermission.dashboardView;
            final hasRequiredAccess =
                access != null &&
                access.isPrivileged &&
                (requiresDashboardEntry
                    ? access.canOpenDashboardHome
                    : access.can(requiredPermission));

            if (hasRequiredAccess) {
              return builder(context, access);
            }

            if (accessSnapshot.hasError) {
              return _AdminDashboardStateView(
                title: 'تعذر تحميل صلاحيات الإدارة',
                message: mapAppErrorToArabic(accessSnapshot.error!),
              );
            }

            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const _AdminDashboardLoadingView(
                label: 'جاري التحقق من صلاحيات لوحة الإدارة...',
              );
            }

            return _AdminDashboardStateView(
              title: 'لا توجد صلاحية دخول',
              message: 'هذا الحساب لا يملك صلاحية دخول لوحة الإدارة.',
              actionLabel: 'تسجيل الخروج',
              onAction: () async {
                await authService.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.adminLoginRoute,
                  (route) => false,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminDashboardLoginRedirect extends StatefulWidget {
  const _AdminDashboardLoginRedirect({this.message});

  final String? message;

  @override
  State<_AdminDashboardLoginRedirect> createState() =>
      _AdminDashboardLoginRedirectState();
}

class _AdminDashboardLoginRedirectState
    extends State<_AdminDashboardLoginRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        AppRouter.adminLoginRoute,
        arguments: widget.message,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _AdminDashboardLoadingView(
      label: 'جاري فتح صفحة تسجيل الدخول...',
    );
  }
}

class _AdminDashboardLoadingView extends StatelessWidget {
  const _AdminDashboardLoadingView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardStateView extends StatelessWidget {
  const _AdminDashboardStateView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(message),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
