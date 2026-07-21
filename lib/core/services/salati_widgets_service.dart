import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SalatiWidgetsService {
  const SalatiWidgetsService._();

  static const MethodChannel _channel = MethodChannel('salati/home_widget');

  static bool get _supportsNativeWidgets =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> _invokeBool(String method, [Object? arguments]) async {
    if (!_supportsNativeWidgets) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(method, arguments);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> updateTextWidget({
    required String key,
    required String title,
    required String body,
    required String reference,
  }) async {
    if (body.trim().isEmpty) {
      return false;
    }

    return _invokeBool('updateTextWidget', {
      'key': key,
      'title': title,
      'body': body,
      'reference': reference,
    });
  }

  static Future<bool> updateCustomAyahWidget({
    required String ayahName,
    required String ayahText,
  }) {
    return updateTextWidget(
      key: 'custom_ayah',
      title: ayahName,
      body: ayahText,
      reference: ayahName,
    );
  }

  static Future<bool> updateScreenReadingWidget({
    required String title,
    required String body,
    required String reference,
    required int surah,
    required int ayah,
    required String surahName,
  }) {
    return _invokeBool('updateScreenReadingWidget', {
      'title': title,
      'body': body,
      'reference': reference,
      'surah': surah,
      'ayah': ayah,
      'surahName': surahName,
    });
  }

  static Future<bool> updateCalendarWidget({
    required String title,
    required String hijriDate,
    required String gregorianDate,
    String? occasion,
  }) {
    final body = [
      hijriDate,
      gregorianDate,
      if (occasion != null && occasion.trim().isNotEmpty) occasion,
    ].join('\n');

    return updateTextWidget(
      key: 'calendar',
      title: title,
      body: body,
      reference: 'التقويم',
    );
  }

  static Future<bool> updateCalendar30Widget({
    required String monthTitle,
    required String todayBig,
    required String todaySmall,
    required int todayIndex,
    required List<CalendarWidgetDay> days,
  }) {
    return _invokeBool('updateCalendar30Widget', {
      'monthTitle': monthTitle,
      'todayBig': todayBig,
      'todaySmall': todaySmall,
      'todayIndex': todayIndex,
      'daysJson': jsonEncode(days.map((day) => day.toMap()).toList()),
    });
  }

  static Future<bool> updatePrayerStripWidget({
    required String fajr,
    required String sunrise,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    String? activePrayerKey,
    String? tomorrowFajr,
    String? tomorrowSunrise,
    String? tomorrowDhuhr,
    String? tomorrowAsr,
    String? tomorrowMaghrib,
    String? tomorrowIsha,
    String? tomorrowActivePrayerKey,
    String? accentColor,
    String? themeMode,
    double? textScale,
    bool? showAllPrayers,
  }) {
    return _invokeBool('updatePrayerStripWidget', {
      'fajr': fajr,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'activePrayerKey': activePrayerKey,
      'tomorrowFajr': tomorrowFajr,
      'tomorrowSunrise': tomorrowSunrise,
      'tomorrowDhuhr': tomorrowDhuhr,
      'tomorrowAsr': tomorrowAsr,
      'tomorrowMaghrib': tomorrowMaghrib,
      'tomorrowIsha': tomorrowIsha,
      'tomorrowActivePrayerKey': tomorrowActivePrayerKey,
      'accentColor': accentColor,
      'themeMode': themeMode,
      'textScale': textScale,
      'showAllPrayers': showAllPrayers,
    });
  }

  static Future<bool> updateTodayPrayerTimesWidget({
    required String fajr,
    required String sunrise,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    String? activePrayerKey,
    String? tomorrowFajr,
    String? tomorrowSunrise,
    String? tomorrowDhuhr,
    String? tomorrowAsr,
    String? tomorrowMaghrib,
    String? tomorrowIsha,
    String? tomorrowActivePrayerKey,
    String? accentColor,
    String? themeMode,
    double? textScale,
    bool? showAllPrayers,
  }) {
    return updatePrayerStripWidget(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      activePrayerKey: activePrayerKey,
      tomorrowFajr: tomorrowFajr,
      tomorrowSunrise: tomorrowSunrise,
      tomorrowDhuhr: tomorrowDhuhr,
      tomorrowAsr: tomorrowAsr,
      tomorrowMaghrib: tomorrowMaghrib,
      tomorrowIsha: tomorrowIsha,
      tomorrowActivePrayerKey: tomorrowActivePrayerKey,
      accentColor: accentColor,
      themeMode: themeMode,
      textScale: textScale,
      showAllPrayers: showAllPrayers,
    );
  }

  static Future<bool> updateNextPrayerWidget({
    required String prayerName,
    required String remaining,
    required int remainingMinutes,
    DateTime? prayerTime,
    String? prayerKey,
    String? accentColor,
    String? themeMode,
    double? textScale,
    bool? showCountdown,
  }) {
    return _invokeBool('updateNextPrayerWidget', {
      'prayerName': prayerName,
      'remaining': remaining,
      'remainingMinutes': remainingMinutes,
      'prayerTimeMillis': prayerTime?.millisecondsSinceEpoch,
      'prayerKey': prayerKey,
      'accentColor': accentColor,
      'themeMode': themeMode,
      'textScale': textScale,
      'showCountdown': showCountdown,
    });
  }

  static Future<bool> hasNextPrayerWidget() {
    return _invokeBool('hasNextPrayerWidget');
  }

  static Future<bool> updatePointsAndRatingWidget({
    required String points,
    required String prayerRating,
    required int completedPrayersToday,
  }) {
    return _invokeBool('updatePointsPrayerRatingWidget', {
      'points': points,
      'prayerRating': prayerRating,
      'completedPrayersToday': completedPrayersToday,
    });
  }

  static Future<bool> updateQuickControlsWidget({
    required bool notificationsLoud,
    required bool nextAlertEnabled,
    required bool touchLockEnabled,
  }) {
    return _invokeBool('updateQuickControlsWidget', {
      'notificationsLoud': notificationsLoud,
      'nextAlertEnabled': nextAlertEnabled,
      'touchLockEnabled': touchLockEnabled,
    });
  }

  static Future<bool> scheduleMidnightWidgetRefresh({
    required DateTime triggerAt,
  }) {
    return _invokeBool('scheduleMidnightWidgetRefresh', {
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
    });
  }

  static Future<bool> saveFavoriteAyahsForWidget({
    required List<FavoriteWidgetItem> ayahs,
  }) {
    return _invokeBool('saveFavoriteAyahs', {
      'ayahs': ayahs.map((item) => item.toMap()).toList(),
    });
  }

  static Future<bool> saveFavoriteAzkarForWidget({
    required List<FavoriteWidgetItem> items,
  }) {
    return _invokeBool('saveFavoriteAzkar', {
      'items': items.map((item) => item.toMap()).toList(),
    });
  }

  static Future<bool> refreshRandomAyahWidget() {
    return _invokeBool('updateRandomAyah');
  }

  static Future<bool> refreshRandomZikrWidget() {
    return _invokeBool('updateRandomZikr');
  }

  static FavoriteWidgetItem pickRandom(List<FavoriteWidgetItem> items) {
    if (items.isEmpty) {
      throw StateError('items is empty');
    }

    return items[Random().nextInt(items.length)];
  }
}

class FavoriteWidgetItem {
  const FavoriteWidgetItem({
    required this.title,
    required this.body,
    required this.reference,
  });

  final String title;
  final String body;
  final String reference;

  Map<String, String> toMap() {
    return {'title': title, 'body': body, 'reference': reference};
  }
}

class CalendarWidgetDay {
  const CalendarWidgetDay({required this.hijri, required this.miladi});

  final String hijri;
  final String miladi;

  Map<String, String> toMap() {
    return {'hijri': hijri, 'miladi': miladi};
  }
}
