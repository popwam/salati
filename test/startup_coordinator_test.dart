import 'package:flutter_test/flutter_test.dart';
import 'package:salati/app/bootstrap/startup_coordinator.dart';
import 'package:salati/core/models/app_user.dart';
import 'package:salati/core/models/operational_config.dart';
import 'package:salati/core/session/user_session_profile.dart';
import 'package:salati/features/admin/data/app_config_repository.dart';
import 'package:salati/features/auth/data/auth_service.dart';
import 'package:salati/features/auth/models/auth_session.dart';
import 'package:salati/features/subscriptions/data/user_profile_repository.dart';

void main() {
  test(
    'prepares anonymous mobile session and ensures default free user',
    () async {
      final authService = _FakeAuthService(
        session: const AuthSession(
          uid: 'user_123',
          isAnonymous: true,
          email: null,
        ),
      );
      final configRepository = _FakeAppConfigRepository(
        config: OperationalConfig.defaults(),
      );
      final userRepository = _FakeUserProfileRepository();
      final messages = <String>[];

      final coordinator = StartupCoordinator(
        authService: authService,
        appConfigRepository: configRepository,
        userProfileRepository: userRepository,
      );

      await coordinator.prepareInitialSession(
        isWeb: false,
        onStatusChanged: messages.add,
      );

      expect(messages, ['جاري تحميل الإعدادات...', 'جاري تجهيز حسابك...']);
      expect(authService.lastAllowAnonymous, isTrue);
      expect(authService.ensureCalls, 1);
      expect(userRepository.lastEnsuredUid, 'user_123');
      expect(userRepository.lastEnsuredDefaultPlanId, 'free');
    },
  );

  test('does not create anonymous session on web admin startup', () async {
    final authService = _FakeAuthService();
    final configRepository = _FakeAppConfigRepository(
      config: OperationalConfig.defaults(),
    );
    final userRepository = _FakeUserProfileRepository();
    final messages = <String>[];

    final coordinator = StartupCoordinator(
      authService: authService,
      appConfigRepository: configRepository,
      userProfileRepository: userRepository,
    );

    await coordinator.prepareInitialSession(
      isWeb: true,
      onStatusChanged: messages.add,
    );

    expect(messages, ['جاري تحميل الإعدادات...']);
    expect(authService.ensureCalls, 0);
    expect(userRepository.lastEnsuredUid, isNull);
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.session});

  AuthSession? session;
  int ensureCalls = 0;
  bool? lastAllowAnonymous;

  @override
  AuthSession? get currentSession => session;

  @override
  Stream<AuthSession?> authStateChanges() =>
      Stream<AuthSession?>.value(session);

  @override
  Future<void> confirmPhoneCode(
    String smsCode, {
    bool linkIfAnonymous = false,
  }) async {}

  @override
  Future<void> ensureMobileUserSession({bool allowAnonymous = true}) async {
    ensureCalls += 1;
    lastAllowAnonymous = allowAnonymous;
  }

  @override
  Future<void> linkWithGoogle() async {}

  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> startPhoneSignIn(
    String phoneNumber, {
    bool linkIfAnonymous = false,
  }) async {}
}

class _FakeAppConfigRepository implements AppConfigRepository {
  _FakeAppConfigRepository({required this.config});

  final OperationalConfig config;

  @override
  Future<void> ensureDefaults() async {}

  @override
  Future<OperationalConfig> loadOperationalConfig() async => config;

  @override
  Future<void> saveOperationalConfig(OperationalConfig config) async {}

  @override
  Stream<OperationalConfig> watchOperationalConfig() =>
      Stream<OperationalConfig>.value(config);
}

class _FakeUserProfileRepository implements UserProfileRepository {
  String? lastEnsuredUid;
  String? lastEnsuredDefaultPlanId;

  @override
  Future<AppUser> ensureUserProfile({
    required String uid,
    required String defaultPlanId,
    String? email,
    String? name,
  }) async {
    lastEnsuredUid = uid;
    lastEnsuredDefaultPlanId = defaultPlanId;
    return AppUser(
      uid: uid,
      name: name ?? 'مستخدم جديد',
      email: email,
      planId: defaultPlanId,
      subscriptionStatus: 'active',
      isAdmin: false,
      createdAt: DateTime(2026, 4, 25),
      updatedAt: DateTime(2026, 4, 25),
    );
  }

  @override
  Future<UserSessionProfile?> loadUserSessionProfile({
    required String uid,
    required String defaultPlanId,
    String? fallbackEmail,
  }) async {
    return UserSessionProfile(
      uid: uid,
      email: fallbackEmail,
      role: 'user',
      planId: defaultPlanId,
      permissions: const <String>{},
    );
  }

  @override
  Stream<AppUser?> watchCurrentUser(String uid) => Stream<AppUser?>.empty();

  @override
  Stream<List<AppUser>> watchUsers() => Stream<List<AppUser>>.value(const []);

  @override
  Future<void> updateUserAdminSettings({
    required String uid,
    String? planId,
    int? points,
    bool? isBlocked,
    int? aiUsageLimitOverride,
    bool clearAiUsageLimitOverride = false,
  }) async {}

  @override
  Future<void> updateOwnProfile({
    required String uid,
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {}

  @override
  Future<void> adjustUserPoints({
    required String uid,
    required int delta,
  }) async {}
}
