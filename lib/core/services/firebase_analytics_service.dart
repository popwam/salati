import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  @override
  Future<void> trackEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_firebaseConfigured) {
      if (kDebugMode) {
        debugPrint('Analytics fallback: $name ${parameters ?? {}}');
      }
      return;
    }

    await FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}
