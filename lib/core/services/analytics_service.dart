abstract class AnalyticsService {
  Future<void> trackEvent(String name, {Map<String, Object>? parameters});
}
