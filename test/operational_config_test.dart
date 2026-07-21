import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/models/operational_config.dart';

void main() {
  group('QuranLimitsConfig', () {
    test('defaults to the Slice 3 Quran session limits', () {
      final limits = OperationalConfig.defaults().quranLimits;

      expect(limits.ayahFreeMinutes, 60);
      expect(limits.wordFreeMinutes, 30);
      expect(limits.rewardedAyahMinutes, 60);
      expect(limits.rewardedWordMinutes, 30);
    });

    test('fromMap falls back to the Slice 3 Quran session limits', () {
      final limits = QuranLimitsConfig.fromMap(const {});

      expect(limits.ayahFreeMinutes, 60);
      expect(limits.wordFreeMinutes, 30);
      expect(limits.rewardedAyahMinutes, 60);
      expect(limits.rewardedWordMinutes, 30);
    });
  });

  group('PrayerProviderConfig.fromMap', () {
    test('accepts latitude and longitude as num', () {
      final config = PrayerProviderConfig.fromMap({
        'defaultLatitude': 24.7136,
        'defaultLongitude': 46.6753,
      });

      expect(config.defaultLatitude, 24.7136);
      expect(config.defaultLongitude, 46.6753);
    });

    test('accepts latitude and longitude as numeric strings', () {
      final config = PrayerProviderConfig.fromMap({
        'defaultLatitude': '24.7136',
        'defaultLongitude': '46.6753',
      });

      expect(config.defaultLatitude, 24.7136);
      expect(config.defaultLongitude, 46.6753);
    });

    test('falls back to defaults when values are missing', () {
      final config = PrayerProviderConfig.fromMap(const {});

      expect(config.defaultLatitude, 30.0444);
      expect(config.defaultLongitude, 31.2357);
    });

    test('falls back to defaults when values are invalid strings', () {
      final config = PrayerProviderConfig.fromMap({
        'defaultLatitude': 'not-a-number',
        'defaultLongitude': 'still-not-a-number',
      });

      expect(config.defaultLatitude, 30.0444);
      expect(config.defaultLongitude, 31.2357);
    });
  });
}
