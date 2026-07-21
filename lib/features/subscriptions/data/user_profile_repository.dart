import '../../../core/models/app_user.dart';
import '../../../core/session/user_session_profile.dart';

abstract class UserProfileRepository {
  Stream<AppUser?> watchCurrentUser(String uid);

  Stream<List<AppUser>> watchUsers();

  Future<AppUser> ensureUserProfile({
    required String uid,
    required String defaultPlanId,
    String? email,
    String? name,
  });

  Future<UserSessionProfile?> loadUserSessionProfile({
    required String uid,
    required String defaultPlanId,
    String? fallbackEmail,
  });

  Future<void> updateUserAdminSettings({
    required String uid,
    String? planId,
    int? points,
    bool? isBlocked,
    int? aiUsageLimitOverride,
    bool clearAiUsageLimitOverride = false,
  });

  Future<void> updateOwnProfile({
    required String uid,
    String? name,
    String? avatarUrl,
    bool clearAvatar = false,
  });

  Future<void> adjustUserPoints({required String uid, required int delta});
}
