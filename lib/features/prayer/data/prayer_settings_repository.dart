import '../models/prayer_settings.dart';

abstract class PrayerSettingsRepository {
  Future<PrayerSettings> load();

  Future<void> save(PrayerSettings settings);
}
