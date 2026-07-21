import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salati/core/services/app_preferences.dart';

void main() {
  test('exports and imports the syncable local user state', () async {
    SharedPreferences.setMockInitialValues({});
    final sourcePrefs = AppPreferences(await SharedPreferences.getInstance());
    final date = DateTime(2026, 5, 14);

    await sourcePrefs.setThemeMode(ThemeMode.dark);
    await sourcePrefs.setPrayerCountry('Egypt');
    await sourcePrefs.setPrayerCity('Cairo');
    await sourcePrefs.setQuranLastSurah(18);
    await sourcePrefs.setAdhkarFavorites({'morning_1', 'evening_2'});
    await sourcePrefs.setAdhkarSurahAutomationEnabled(true);
    await sourcePrefs.setAdhkarSurahAutomationFirst('surah');
    await sourcePrefs.setAdhkarAutomationMode('heard');
    await sourcePrefs.markPrayerCompleted(prayerKey: 'fajr', date: date);

    final snapshot = sourcePrefs.exportSyncSnapshot();

    SharedPreferences.setMockInitialValues({});
    final restoredPrefs = AppPreferences(await SharedPreferences.getInstance());
    await restoredPrefs.importSyncSnapshot(snapshot);

    expect(restoredPrefs.themeMode, ThemeMode.dark);
    expect(restoredPrefs.prayerCountry, 'Egypt');
    expect(restoredPrefs.prayerCity, 'Cairo');
    expect(restoredPrefs.quranLastSurah, 18);
    expect(restoredPrefs.adhkarFavorites, {'morning_1', 'evening_2'});
    expect(restoredPrefs.adhkarSurahAutomationEnabled, isTrue);
    expect(restoredPrefs.adhkarSurahAutomationFirst, 'surah');
    expect(restoredPrefs.adhkarAutomationMode, 'heard');
    expect(restoredPrefs.completedPrayerKeysForDate(date), {'fajr'});
  });

  test('stores backup metadata and clamps automation choices safely', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences(await SharedPreferences.getInstance());
    final backupAt = DateTime(2026, 6, 4, 12, 30);

    await prefs.setFirstCloudRestoreAttempted(true);
    await prefs.setLastCloudBackupAt(backupAt);
    await prefs.setAdhkarSurahAutomationFirst('bad-value');
    await prefs.setAdhkarAutomationMode('bad-value');

    expect(prefs.firstCloudRestoreAttempted, isTrue);
    expect(prefs.lastCloudBackupAt, backupAt);
    expect(prefs.adhkarSurahAutomationFirst, 'adhkar');
    expect(prefs.adhkarAutomationMode, 'read');
  });

  test('does not import unknown keys from a remote snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences(await SharedPreferences.getInstance());

    await prefs.importSyncSnapshot({
      'values': {
        'unknown_sensitive_key': 'ignored',
        'prayer_city': 'Alexandria',
      },
    });

    expect(prefs.prayerCity, 'Alexandria');
    expect(prefs.exportSyncSnapshot().toString(), isNot(contains('ignored')));
  });
}
