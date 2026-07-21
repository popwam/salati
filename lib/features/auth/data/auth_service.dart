import '../models/auth_session.dart';

abstract class AuthService {
  Stream<AuthSession?> authStateChanges();

  AuthSession? get currentSession;

  Future<void> ensureMobileUserSession({bool allowAnonymous = true});

  Future<void> signInAdmin({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> linkWithGoogle();

  Future<void> startPhoneSignIn(
    String phoneNumber, {
    bool linkIfAnonymous = false,
  });

  Future<void> confirmPhoneCode(String smsCode, {bool linkIfAnonymous = false});

  Future<void> signOut();
}
