import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/services/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cumulative score only counts the same completed prayer once', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final date = DateTime(2026, 4, 28);

    await preferences.markPrayerCompleted(prayerKey: 'fajr', date: date);
    await preferences.markPrayerCompleted(prayerKey: 'fajr', date: date);

    expect(preferences.completedPrayerScore(date), 10.0);
    expect(preferences.prayerScoreSummary.totalScore, 10.0);
    expect(preferences.prayerScoreSummary.completedCount, 1);
    expect(preferences.prayerScoreSummary.missedCount, 0);
    expect(preferences.completedPrayerKeysForDate(date), {'fajr'});
  });

  test('locked completed prayer ignores later missed change', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final date = DateTime(2026, 4, 28);

    await preferences.markPrayerCompleted(prayerKey: 'dhuhr', date: date);
    await preferences.markPrayerMissed(prayerKey: 'dhuhr', date: date);

    expect(preferences.completedPrayerScore(date), 10.0);
    expect(preferences.prayerScoreSummary.totalScore, 10.0);
    expect(preferences.prayerScoreSummary.completedCount, 1);
    expect(preferences.prayerScoreSummary.missedCount, 0);
    expect(preferences.completedPrayerKeysForDate(date), {'dhuhr'});
    expect(preferences.missedPrayerKeysForDate(date), isEmpty);
  });

  test('missed prayer can be completed late for half score', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final date = DateTime(2026, 4, 28);

    await preferences.markPrayerMissed(prayerKey: 'asr', date: date);
    await preferences.markPrayerCompleted(prayerKey: 'asr', date: date);
    await preferences.markPrayerCompleted(prayerKey: 'asr', date: date);

    expect(preferences.completedPrayerScore(date), 5.0);
    expect(preferences.prayerScoreSummary.totalScore, 5.0);
    expect(preferences.prayerScoreSummary.completedCount, 1);
    expect(preferences.prayerScoreSummary.missedCount, 0);
    expect(preferences.completedPrayerKeysForDate(date), {'asr'});
    expect(preferences.lateCompletedPrayerKeysForDate(date), {'asr'});
    expect(preferences.missedPrayerKeysForDate(date), isEmpty);
  });

  test('cumulative score spans multiple dates', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);

    await preferences.markPrayerCompleted(
      prayerKey: 'fajr',
      date: DateTime(2026, 4, 28),
    );

    await preferences.markPrayerMissed(
      prayerKey: 'isha',
      date: DateTime(2026, 4, 29),
    );

    expect(preferences.prayerScoreSummary.totalScore, 9.0);
    expect(preferences.prayerScoreSummary.completedCount, 1);
    expect(preferences.prayerScoreSummary.missedCount, 1);
  });

  test('fard plus nawafil adds extra cumulative score once', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final date = DateTime(2026, 4, 28);

    await preferences.markPrayerCompleted(
      prayerKey: 'maghrib',
      date: date,
      withNawafil: true,
    );

    expect(preferences.prayerScoreSummary.totalScore, 10.25);
    expect(preferences.nawafilPrayerKeysForDate(date), {'maghrib'});
  });

  test('late completed prayer ignores nawafil bonus', () async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    final preferences = AppPreferences(sharedPreferences);
    final date = DateTime(2026, 4, 28);

    await preferences.markPrayerMissed(prayerKey: 'isha', date: date);
    await preferences.markPrayerCompleted(
      prayerKey: 'isha',
      date: date,
      withNawafil: true,
    );

    expect(preferences.missedPrayerKeysForDate(date), isEmpty);
    expect(preferences.completedPrayerKeysForDate(date), {'isha'});
    expect(preferences.lateCompletedPrayerKeysForDate(date), {'isha'});
    expect(preferences.nawafilPrayerKeysForDate(date), isEmpty);
    expect(preferences.prayerScoreSummary.totalScore, 5.0);
  });
}
