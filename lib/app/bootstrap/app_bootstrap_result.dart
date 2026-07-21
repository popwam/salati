import '../../core/services/app_preferences.dart';
import '../navigation/app_router.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.router,
    required this.preferences,
    required this.firebaseConfigured,
    required this.initialRoute,
  });

  final AppRouter router;
  final AppPreferences preferences;
  final bool firebaseConfigured;
  final String initialRoute;
}
