import '../models/daily_prayer_times.dart';
import '../models/prayer_settings.dart';

abstract class PrayerTimesService {
  Future<DailyPrayerTimes> getTodayPrayerTimes({
    required PrayerSettings settings,
  });

  Future<DailyPrayerTimes> getPrayerTimesForDate({
    required PrayerSettings settings,
    required DateTime date,
  });
}
