abstract class NotificationService {
  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<void> cancelPrayerNotifications();

  Future<void> showOngoingPrayerStatus({
    required String title,
    required String body,
    String? nextPrayerName,
    DateTime? nextPrayerTime,
    Duration? remaining,
  });

  Future<void> schedulePrayerReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? androidSound,
    String? payload,
    bool useAlarmAudio = true,
  });
}
