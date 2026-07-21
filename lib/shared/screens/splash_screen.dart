import 'package:flutter/material.dart';

import '../../app/navigation/app_router.dart';
import '../../core/services/app_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.isWeb,
    required this.firebaseConfigured,
    required this.services,
  });

  final bool isWeb;
  final bool firebaseConfigured;
  final AppServices services;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    if (!widget.isWeb && widget.firebaseConfigured) {
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

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    final route = widget.isWeb
        ? AppRouter.adminLoginRoute
        : AppRouter.homeRoute;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.55,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icon/app/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text('صلاتي', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                widget.isWeb
                    ? 'إدارة الحساب والمحتوى'
                    : 'مواقيت الصلاة، القرآن، الأذكار، والتنبيهات',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
