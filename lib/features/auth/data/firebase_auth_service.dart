import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/session/session_cache_service.dart';
import '../models/auth_session.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required bool firebaseConfigured,
    SessionCacheService? sessionCacheService,
  }) : _firebaseConfigured = firebaseConfigured,
       _sessionCacheService = sessionCacheService;

  final bool _firebaseConfigured;
  final SessionCacheService? _sessionCacheService;
  bool _googleInitialized = false;

  ConfirmationResult? _webPhoneConfirmation;
  String? _phoneVerificationId;

  FirebaseAuth? get _auth => _firebaseConfigured ? FirebaseAuth.instance : null;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Auth] $message');
    }
  }

  @override
  AuthSession? get currentSession {
    final user = _auth?.currentUser;
    if (user == null) {
      return null;
    }

    return AuthSession(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
    );
  }

  @override
  Stream<AuthSession?> authStateChanges() {
    final auth = _auth;
    if (auth == null) {
      _logSession(null);
      return Stream<AuthSession?>.value(null);
    }

    return auth.authStateChanges().map((user) {
      final session = _mapUser(user);
      _logSession(session);
      return session;
    });
  }

  @override
  Future<void> ensureMobileUserSession({bool allowAnonymous = true}) async {
    final auth = _auth;
    final currentUser = auth?.currentUser;
    _log(
      'currentUser before anonymous sign-in: '
      'uid=${currentUser?.uid ?? 'none'} '
      'isAnonymous=${currentUser?.isAnonymous ?? false}',
    );

    if (auth == null || kIsWeb) {
      return;
    }

    if (!allowAnonymous) {
      _log('anonymous sign-in blocked by app config');
      return;
    }

    if (auth.currentUser != null) {
      _log('anonymous sign-in skipped because a session already exists');
      return;
    }

    _log('anonymous sign-in started');
    try {
      final credential = await auth.signInAnonymously();
      _logSession(_mapUser(credential.user ?? auth.currentUser));
    } on FirebaseAuthException catch (error) {
      _log('anonymous sign-in failed error=$error');
      if (error.code == 'operation-not-allowed') {
        throw FirebaseAuthException(
          code: 'anonymous-auth-disabled',
          message: 'تسجيل الدخول المؤقت غير مفعل',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> signInAdmin({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() async {
    final auth = _requireAuth();
    if (kIsWeb) {
      await auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final credential = await _buildGoogleCredential();
    await auth.signInWithCredential(credential);
  }

  @override
  Future<void> linkWithGoogle() async {
    final auth = _requireAuth();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'missing-session',
        message: 'لا توجد جلسة مستخدم صالحة لربط الحساب.',
      );
    }

    if (!currentUser.isAnonymous) {
      return;
    }

    AuthCredential? credential;
    try {
      if (kIsWeb) {
        await currentUser.linkWithPopup(GoogleAuthProvider());
        return;
      }

      credential = await _buildGoogleCredential();
      await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        return;
      }
      if (_shouldSignInExistingCredential(error.code)) {
        if (kIsWeb) {
          await auth.signInWithPopup(GoogleAuthProvider());
          return;
        }

        await auth.signInWithCredential(
          credential ?? await _buildGoogleCredential(),
        );
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> startPhoneSignIn(
    String phoneNumber, {
    bool linkIfAnonymous = false,
  }) async {
    final auth = _requireAuth();

    if (kIsWeb) {
      _webPhoneConfirmation = await auth.signInWithPhoneNumber(phoneNumber);
      return;
    }

    final completer = Completer<void>();
    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _completePhoneCredential(
          credential,
          linkIfAnonymous: linkIfAnonymous,
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        _phoneVerificationId = verificationId;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneVerificationId = verificationId;
      },
    );
    await completer.future;
  }

  @override
  Future<void> confirmPhoneCode(
    String smsCode, {
    bool linkIfAnonymous = false,
  }) async {
    _requireAuth();

    if (kIsWeb) {
      final confirmation = _webPhoneConfirmation;
      if (confirmation == null) {
        throw FirebaseAuthException(
          code: 'missing-phone-flow',
          message: 'ابدأ طلب رمز الهاتف أولاً.',
        );
      }
      await confirmation.confirm(smsCode);
      return;
    }

    if (_phoneVerificationId == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'لم يتم إرسال رمز التحقق بعد.',
      );
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _phoneVerificationId!,
      smsCode: smsCode,
    );
    await _completePhoneCredential(
      credential,
      linkIfAnonymous: linkIfAnonymous,
    );
  }

  @override
  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      await _sessionCacheService?.clearSession();
      return;
    }

    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore provider-specific sign-out failures and continue with Firebase.
      }
    }

    await auth.signOut();
    _webPhoneConfirmation = null;
    _phoneVerificationId = null;
    await _sessionCacheService?.clearSession();
  }

  Future<AuthCredential> _buildGoogleCredential() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }

    final account = await GoogleSignIn.instance.authenticate();
    final authentication = account.authentication;
    return GoogleAuthProvider.credential(idToken: authentication.idToken);
  }

  Future<void> _completePhoneCredential(
    PhoneAuthCredential credential, {
    required bool linkIfAnonymous,
  }) async {
    final auth = _requireAuth();
    final currentUser = auth.currentUser;

    if (linkIfAnonymous && currentUser != null && currentUser.isAnonymous) {
      try {
        await currentUser.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'provider-already-linked') {
          return;
        }
        if (_shouldSignInExistingCredential(error.code)) {
          await auth.signInWithCredential(credential);
          return;
        }
        rethrow;
      }
    }

    await auth.signInWithCredential(credential);
  }

  bool _shouldSignInExistingCredential(String code) {
    return code == 'credential-already-in-use' ||
        code == 'email-already-in-use' ||
        code == 'account-exists-with-credential' ||
        code == 'account-exists-with-different-credential';
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseAuthException(
        code: 'firebase-not-configured',
        message: 'Firebase غير مهيأ بعد. أكمل الإعداد ثم أعد المحاولة.',
      );
    }
    return auth;
  }

  AuthSession? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthSession(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      email: user.email,
    );
  }

  void _logSession(AuthSession? session) {
    _log(
      'uid=${session?.uid ?? 'none'} '
      'isAnonymous=${session?.isAnonymous ?? false}',
    );
  }
}
