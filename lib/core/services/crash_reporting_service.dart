import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  CrashReportingService({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_firebaseConfigured || kIsWeb) {
      return;
    }

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(recordError(error, stackTrace, fatal: true));
      return true;
    };

    _initialized = true;
  }

  Future<void> setUserId(String? uid) async {
    if (!_initialized) {
      return;
    }

    await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
  }

  Future<void> log(String message) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[Crashlytics fallback] $message');
      }
      return;
    }

    await FirebaseCrashlytics.instance.log(message);
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[Crashlytics fallback] error=$error');
      }
      return;
    }

    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: fatal,
    );
  }
}
