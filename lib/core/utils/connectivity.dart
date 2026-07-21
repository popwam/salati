import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityUtils {
  ConnectivityUtils._();

  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isOffline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOffline(results);
  }

  static Stream<bool> get offlineStream {
    return _connectivity.onConnectivityChanged.map(_isOffline).distinct();
  }

  static bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
  }
}
