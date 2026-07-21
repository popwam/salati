import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/session/session_cache_service.dart';
import '../../features/admin/data/app_config_repository.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/subscriptions/data/user_profile_repository.dart';

class StartupCoordinator {
  const StartupCoordinator({
    required this.authService,
    required this.appConfigRepository,
    required this.userProfileRepository,
    this.sessionCacheService,
  });

  final AuthService authService;
  final AppConfigRepository appConfigRepository;
  final UserProfileRepository userProfileRepository;
  final SessionCacheService? sessionCacheService;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Startup] $message');
    }
  }

  Future<void> prepareInitialSession({
    required bool isWeb,
    required void Function(String message) onStatusChanged,
  }) async {
    onStatusChanged('جاري تحميل الإعدادات...');

    if (isWeb && authService.currentSession == null) {
      await sessionCacheService?.clearSession();
      _log('web startup skipped protected config reads before admin login');
      return;
    }

    final config = await appConfigRepository.loadOperationalConfig();

    onStatusChanged('جاري تجهيز حسابك...');
    if (!isWeb) {
      await authService.ensureMobileUserSession(
        allowAnonymous: config.authAvailability.anonymousEnabled,
      );
    }

    final session = authService.currentSession;
    if (session == null) {
      await sessionCacheService?.clearSession();
      _log('session is still missing after startup preparation');
      throw FirebaseException(
        plugin: 'salati',
        code: 'anonymous-auth-disabled',
        message: 'تسجيل الدخول المؤقت غير مفعل',
      );
    }

    _log('ensureUserProfile started uid=${session.uid}');
    try {
      await userProfileRepository.ensureUserProfile(
        uid: session.uid,
        email: session.email,
        defaultPlanId: config.defaultUserPlanId,
      );
      await sessionCacheService?.syncCurrentSession(
        authService: authService,
        userProfileRepository: userProfileRepository,
        defaultPlanId: config.defaultUserPlanId,
      );
      _log('ensureUserProfile success');
    } on FirebaseException catch (error) {
      _log('ensureUserProfile failed error=$error');
      throw FirebaseException(
        plugin: error.plugin,
        code: 'user-profile-setup-failed',
        message: 'تعذر تجهيز حسابك المجاني',
      );
    } catch (error) {
      _log('ensureUserProfile failed error=$error');
      throw FirebaseException(
        plugin: 'salati',
        code: 'user-profile-setup-failed',
        message: 'تعذر تجهيز حسابك المجاني',
      );
    }
  }
}
