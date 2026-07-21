import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/operational_config.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../data/prayer_settings_repository.dart';
import '../models/prayer_settings.dart';
import 'local_prayer_times_service.dart';

class PrayerNotificationScheduler {
  const PrayerNotificationScheduler._();

  static const morningAdhkarNotificationId = 920001;
  static const eveningAdhkarNotificationId = 920002;
  static const fridayKahfNotificationId = 920003;
  static const mulkNotificationId = 920004;

  static const _obligatoryPrayerKeys = {
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  };

  static Future<bool> scheduleFromSavedSettings({
    required AppServices services,
    required AppPreferences preferences,
    required PrayerSettingsRepository repository,
    bool forceEnablePrayerNotifications = false,
    bool requestPermissions = true,
  }) async {
    if (kIsWeb) {
      return false;
    }

    try {
      final config = await services.appConfigRepository.loadOperationalConfig();
      var settings = _applyOperationalDefaults(await repository.load(), config);
      if (forceEnablePrayerNotifications && !settings.notificationsEnabled) {
        settings = settings.copyWith(notificationsEnabled: true);
        await preferences.setPrayerNotificationsEnabled(true);
      }

      final hasContentReminders =
          preferences.morningAdhkarReminderEnabled ||
          preferences.eveningAdhkarReminderEnabled ||
          preferences.fridayKahfReminderEnabled ||
          preferences.mulkReminderEnabled;

      if (!settings.notificationsEnabled && !hasContentReminders) {
        return false;
      }

      if (requestPermissions) {
        final granted = await services.notificationService.requestPermissions();
        if (!granted) {
          return false;
        }
      }

      await services.notificationService.cancelPrayerNotifications();

      final now = await _trustedNow(services);
      final prayerTimesService = LocalPrayerTimesService(
        operationalConfig: config,
      );

      if (settings.notificationsEnabled) {
        final dates = [now, now.add(const Duration(days: 1))];
        for (final date in dates) {
          final times = await prayerTimesService.getPrayerTimesForDate(
            settings: settings,
            date: date,
          );
          for (var index = 0; index < times.entries.length; index++) {
            final entry = times.entries[index];
            if (!_obligatoryPrayerKeys.contains(entry.key) ||
                !preferences.isAdhanEnabledForPrayer(entry.key)) {
              continue;
            }

            await services.notificationService.schedulePrayerReminder(
              id: _notificationIdFor(date, index),
              title: 'حان وقت الصلاة',
              body: 'صلاة ${entry.label} الآن',
              scheduledAt: entry.time,
              androidSound: _androidSoundForPrayer(preferences, entry.key),
              payload: 'prayer:${entry.key}',
            );
          }
        }
      }

      await _scheduleContentReminders(
        services: services,
        preferences: preferences,
        now: now,
      );
      return true;
    } catch (error) {
      debugPrint('[PrayerNotificationScheduler] schedule failed: $error');
      return false;
    }
  }

  static Future<void> _scheduleContentReminders({
    required AppServices services,
    required AppPreferences preferences,
    required DateTime now,
  }) async {
    if (preferences.morningAdhkarReminderEnabled) {
      await services.notificationService.schedulePrayerReminder(
        id: morningAdhkarNotificationId,
        title: 'أذكار الصباح',
        body: 'ابدأ ورد الصباح بهدوء وذكر.',
        scheduledAt: _nextDailyTime(
          preferences.morningAdhkarReminderMinutes,
          now,
        ),
        androidSound: _rawAzkarSound(preferences.selectedMorningAzkarSoundKey),
        payload: 'adhkar:morning',
      );
    }

    if (preferences.eveningAdhkarReminderEnabled) {
      await services.notificationService.schedulePrayerReminder(
        id: eveningAdhkarNotificationId,
        title: 'أذكار المساء',
        body: 'وقت ورد المساء وطمأنينة نهاية اليوم.',
        scheduledAt: _nextDailyTime(
          preferences.eveningAdhkarReminderMinutes,
          now,
        ),
        androidSound: _rawAzkarSound(preferences.selectedEveningAzkarSoundKey),
        payload: 'adhkar:evening',
      );
    }

    if (preferences.fridayKahfReminderEnabled) {
      await services.notificationService.schedulePrayerReminder(
        id: fridayKahfNotificationId,
        title: 'سورة الكهف',
        body: 'تذكير الجمعة لقراءة سورة الكهف.',
        scheduledAt: _nextWeekdayTime(
          DateTime.friday,
          preferences.fridayKahfReminderMinutes,
          now,
        ),
        payload: 'quran_surah:18',
        useAlarmAudio: false,
      );
    }

    if (preferences.mulkReminderEnabled) {
      await services.notificationService.schedulePrayerReminder(
        id: mulkNotificationId,
        title: 'سورة الملك',
        body: 'وقت قراءة سورة الملك حسب اختيارك.',
        scheduledAt: _nextDailyTime(preferences.mulkReminderMinutes, now),
        payload: 'quran_surah:67',
        useAlarmAudio: false,
      );
    }
  }

  static PrayerSettings _applyOperationalDefaults(
    PrayerSettings settings,
    OperationalConfig config,
  ) {
    return settings.copyWith(
      country: settings.country.isEmpty
          ? config.prayerProvider.defaultCountry
          : settings.country,
      city: settings.city.isEmpty
          ? config.prayerProvider.defaultCity
          : settings.city,
      calculationMethod: settings.calculationMethod.isEmpty
          ? config.prayerProvider.calculationMethod
          : settings.calculationMethod,
      latitude: settings.latitude ?? config.prayerProvider.defaultLatitude,
      longitude: settings.longitude ?? config.prayerProvider.defaultLongitude,
    );
  }

  static Future<DateTime> _trustedNow(AppServices services) async {
    if (!services.firebaseConfigured) {
      return DateTime.now();
    }
    final session = services.authService.currentSession;
    if (session == null) {
      return DateTime.now();
    }
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(session.uid);
      await ref.set({
        'clientClockProbeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final snapshot = await ref.get(const GetOptions(source: Source.server));
      final value = snapshot.data()?['clientClockProbeAt'];
      if (value is Timestamp) {
        return value.toDate();
      }
    } catch (error) {
      debugPrint('[PrayerNotificationScheduler] server clock failed: $error');
    }
    return DateTime.now();
  }

  static int _notificationIdFor(DateTime date, int index) {
    return date.year * 100000 + date.month * 1000 + date.day * 10 + index;
  }

  static String _androidSoundForPrayer(
    AppPreferences preferences,
    String prayerKey,
  ) {
    if (prayerKey == 'fajr') {
      return _rawAdhanSound(preferences.selectedFajrAdhanKey);
    }
    return _rawAdhanSound(preferences.selectedAdhanKey);
  }

  static String _rawAdhanSound(String key) {
    switch (key.trim().toLowerCase()) {
      case 'fajr_default_adhan':
      case 'adhan_fajr_default':
        return 'adhan_fajr_default';
      case 'default_adhan':
      case 'adhan_default':
      default:
        return 'adhan_default';
    }
  }

  static String _rawAzkarSound(String key) {
    switch (key.trim().toLowerCase()) {
      case 'azkar_morning':
      case 'morning_default':
        return 'azkar_morning';
      case 'azkar_evening':
      case 'evening_default':
      default:
        return 'azkar_evening';
    }
  }

  static DateTime _nextDailyTime(int minutesFromMidnight, DateTime now) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );
    if (target.isAfter(now)) {
      return target;
    }
    return target.add(const Duration(days: 1));
  }

  static DateTime _nextWeekdayTime(
    int weekday,
    int minutesFromMidnight,
    DateTime now,
  ) {
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );
    final daysUntil = (weekday - now.weekday) % DateTime.daysPerWeek;
    target = target.add(Duration(days: daysUntil));
    if (target.isAfter(now)) {
      return target;
    }
    return target.add(const Duration(days: 7));
  }
}
