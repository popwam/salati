import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/subscriptions/data/user_profile_repository.dart';

class CachedSessionData {
  const CachedSessionData({
    required this.uid,
    required this.email,
    required this.role,
    required this.planId,
    required this.permissions,
    required this.lastLoginAt,
  });

  final String uid;
  final String? email;
  final String role;
  final String planId;
  final Set<String> permissions;
  final DateTime lastLoginAt;

  bool get hasDashboardAccess {
    return role == 'superAdmin' ||
        role == 'super_admin' ||
        role == 'admin' ||
        permissions.contains('dashboard.view');
  }
}

class SessionCacheService {
  SessionCacheService(this._sharedPreferences);

  static const _uidKey = 'session.uid';
  static const _emailKey = 'session.email';
  static const _roleKey = 'session.role';
  static const _planIdKey = 'session.plan_id';
  static const _permissionsKey = 'session.permissions';
  static const _lastLoginAtKey = 'session.last_login_at';

  final SharedPreferences _sharedPreferences;

  CachedSessionData? get currentSession {
    final uid = _sharedPreferences.getString(_uidKey);
    if (uid == null || uid.trim().isEmpty) {
      return null;
    }

    final rawLastLoginAt = _sharedPreferences.getString(_lastLoginAtKey);
    final lastLoginAt = rawLastLoginAt == null
        ? null
        : DateTime.tryParse(rawLastLoginAt);
    final permissions =
        _sharedPreferences.getStringList(_permissionsKey) ?? const <String>[];

    return CachedSessionData(
      uid: uid,
      email: _sharedPreferences.getString(_emailKey),
      role: _sharedPreferences.getString(_roleKey) ?? 'user',
      planId: _sharedPreferences.getString(_planIdKey) ?? 'free',
      permissions: permissions.toSet(),
      lastLoginAt: lastLoginAt ?? DateTime.now(),
    );
  }

  Future<void> saveSession({
    required String uid,
    String? email,
    required String role,
    required String planId,
    required Set<String> permissions,
    DateTime? lastLoginAt,
  }) async {
    final sortedPermissions = permissions.toList()..sort();

    await _sharedPreferences.setString(_uidKey, uid);
    if (email == null || email.trim().isEmpty) {
      await _sharedPreferences.remove(_emailKey);
    } else {
      await _sharedPreferences.setString(_emailKey, email.trim());
    }
    await _sharedPreferences.setString(_roleKey, role);
    await _sharedPreferences.setString(_planIdKey, planId);
    await _sharedPreferences.setStringList(_permissionsKey, sortedPermissions);
    await _sharedPreferences.setString(
      _lastLoginAtKey,
      (lastLoginAt ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<void> clearSession() async {
    await _sharedPreferences.remove(_uidKey);
    await _sharedPreferences.remove(_emailKey);
    await _sharedPreferences.remove(_roleKey);
    await _sharedPreferences.remove(_planIdKey);
    await _sharedPreferences.remove(_permissionsKey);
    await _sharedPreferences.remove(_lastLoginAtKey);
  }

  Future<void> syncCurrentSession({
    required AuthService authService,
    required UserProfileRepository userProfileRepository,
    required String defaultPlanId,
  }) async {
    final session = authService.currentSession;
    if (session == null || session.uid.isEmpty) {
      await clearSession();
      return;
    }

    try {
      final profile = await userProfileRepository.loadUserSessionProfile(
        uid: session.uid,
        fallbackEmail: session.email,
        defaultPlanId: defaultPlanId,
      );

      await saveSession(
        uid: session.uid,
        email: profile?.email ?? session.email,
        role: profile?.role ?? 'user',
        planId: profile?.planId ?? defaultPlanId,
        permissions: profile?.permissions ?? const <String>{},
      );
    } catch (_) {
      await saveSession(
        uid: session.uid,
        email: session.email,
        role: 'user',
        planId: defaultPlanId,
        permissions: const <String>{},
      );
    }
  }
}
