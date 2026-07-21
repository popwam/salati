import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_status.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  static const String _webRecaptchaSiteKey =
      '6LdNPvAsAAAAABaj3zHg1qrP0c441M9jteX9TAK1';

  static Future<FirebaseStatus> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      await _activateAppCheck();
    } on UnsupportedError catch (error) {
      return FirebaseStatus(
        isConfigured: false,
        missingItems: const ['firebase_options_ios'],
        message: error.message,
      );
    } on FirebaseException catch (error) {
      return FirebaseStatus(
        isConfigured: false,
        missingItems: const ['firebase_initialization'],
        message: error.message,
      );
    }

    return const FirebaseStatus(
      isConfigured: true,
      message: 'تم تهيئة Firebase بنجاح.',
    );
  }

  static Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_webRecaptchaSiteKey),
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Firebase App Check activation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
