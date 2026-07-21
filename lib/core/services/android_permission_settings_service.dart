import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

class AndroidPermissionSettingsService {
  const AndroidPermissionSettingsService();

  static const _packageName = 'com.popwam.salati';

  Future<void> openAppSettings() {
    return _launch(
      const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_packageName',
      ),
    );
  }

  Future<void> openNotificationSettings() {
    return _launch(
      const AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: {'android.provider.extra.APP_PACKAGE': _packageName},
      ),
    );
  }

  Future<void> openBatteryOptimizationSettings() {
    return _launch(
      const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ),
    );
  }

  Future<void> _launch(AndroidIntent intent) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await intent.launch();
    } catch (_) {
      await const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_packageName',
      ).launch();
    }
  }
}
