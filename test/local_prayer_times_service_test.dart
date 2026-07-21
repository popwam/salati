import 'package:flutter_test/flutter_test.dart';

import 'package:salati/core/models/operational_config.dart';
import 'package:salati/core/models/points_config.dart';
import 'package:salati/features/prayer/models/prayer_settings.dart';
import 'package:salati/features/prayer/models/qiyam_preference.dart';
import 'package:salati/features/prayer/services/local_prayer_times_service.dart';

void main() {
  test('returns six prayer entries for the requested date', () async {
    const service = LocalPrayerTimesService(
      operationalConfig: OperationalConfig(
        defaultUserPlanId: 'free',
        pointsRules: PointsRulesConfig.defaults,
        authAvailability: AuthAvailability(
          anonymousEnabled: true,
          googleEnabled: true,
          phoneEnabled: true,
          emailPasswordEnabled: true,
        ),
        prayerProvider: PrayerProviderConfig(
          providerType: 'local_calculation',
          calculationMethod: 'egyptian',
          apiBaseUrl: '',
          availableCountries: ['مصر'],
          defaultCountry: 'مصر',
          defaultCity: 'القاهرة',
          defaultLatitude: 30.0444,
          defaultLongitude: 31.2357,
        ),
        contentSources: ContentSourcesConfig(
          adhkarSource: 'local',
          hadithSource: 'local',
          textSource: 'local',
        ),
        quranLimits: QuranLimitsConfig(
          ayahFreeMinutes: 60,
          wordFreeMinutes: 30,
          rewardedAyahMinutes: 60,
          rewardedWordMinutes: 30,
        ),
      ),
    );

    const settings = PrayerSettings(
      country: 'مصر',
      city: 'القاهرة',
      calculationMethod: 'egyptian',
      notificationsEnabled: false,
      qiyamPreference: QiyamPreference.lastThird,
      latitude: 30.0444,
      longitude: 31.2357,
    );

    final result = await service.getPrayerTimesForDate(
      settings: settings,
      date: DateTime(2026, 4, 28),
    );

    expect(result.entries.length, 6);
    expect(result.entries.first.label, 'الفجر');
    expect(result.entries.first.time.year, 2026);
    expect(result.entries.first.time.month, 4);
    expect(result.entries.first.time.day, 28);
  });
}
