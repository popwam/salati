import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SalatiHomeWidgetService {
  const SalatiHomeWidgetService._();

  static const _channel = MethodChannel('salati/home_widget');

  static bool get _supportsNativeWidgets =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> createQuranWidget({
    required String widgetId,
    required String title,
    required String body,
    required String reference,
    required String name,
    Duration expiry = const Duration(days: 365),
  }) async {
    return updateQuranWidget(
      widgetId: widgetId,
      title: title,
      body: body,
      reference: reference,
      name: name,
      expiry: expiry,
    );
  }

  static Future<bool> updateQuranWidget({
    required String widgetId,
    required String title,
    required String body,
    required String reference,
    required String name,
    Duration expiry = const Duration(days: 365),
  }) async {
    if (!_supportsNativeWidgets) {
      return false;
    }

    final expiresAt = DateTime.now().add(expiry).millisecondsSinceEpoch;

    try {
      final updated = await _channel.invokeMethod<bool>('updateQuranWidget', {
        'widgetId': widgetId,
        'title': title,
        'body': body,
        'reference': reference,
        'name': name,
        'expiresAt': expiresAt,
      });
      return updated ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> deleteQuranWidget(String widgetId) async {
    if (!_supportsNativeWidgets) {
      return false;
    }

    try {
      final deleted = await _channel.invokeMethod<bool>('deleteQuranWidget', {
        'widgetId': widgetId,
      });
      return deleted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
