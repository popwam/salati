import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreDebugLogger {
  static void attempt({required String path, required String operation}) {
    _log(path: path, operation: operation, result: 'attempt');
  }

  static void success({required String path, required String operation}) {
    _log(path: path, operation: operation, result: 'success');
  }

  static void denied({
    required String path,
    required String operation,
    Object? error,
  }) {
    _log(path: path, operation: operation, result: 'denied', error: error);
  }

  static void failure({
    required String path,
    required String operation,
    Object? error,
  }) {
    _log(path: path, operation: operation, result: 'error', error: error);
  }

  static void _log({
    required String path,
    required String operation,
    required String result,
    Object? error,
  }) {
    if (!kDebugMode) {
      return;
    }

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    final uid = user?.uid ?? 'none';
    final isAnonymous = user?.isAnonymous ?? false;
    final suffix = error == null ? '' : ' error=$error';

    debugPrint(
      '[Firestore] uid=$uid isAnonymous=$isAnonymous op=$operation path=$path result=$result$suffix',
    );
  }
}
