import 'package:adhan_dart/adhan_dart.dart';

import '../../../core/models/operational_config.dart';
import '../models/daily_prayer_times.dart';
import '../models/prayer_settings.dart';
import 'prayer_times_service.dart';

class LocalPrayerTimesService implements PrayerTimesService {
  const LocalPrayerTimesService({required this.operationalConfig});

  final OperationalConfig operationalConfig;

  @override
  Future<DailyPrayerTimes> getTodayPrayerTimes({
    required PrayerSettings settings,
  }) async {
    return getPrayerTimesForDate(settings: settings, date: DateTime.now());
  }

  @override
  Future<DailyPrayerTimes> getPrayerTimesForDate({
    required PrayerSettings settings,
    required DateTime date,
  }) async {
    final latitude =
        settings.latitude ?? operationalConfig.prayerProvider.defaultLatitude;

    final longitude =
        settings.longitude ?? operationalConfig.prayerProvider.defaultLongitude;

    final parameters = _parametersFor(settings.calculationMethod);

    final prayerTimes = PrayerTimes(
      coordinates: Coordinates(latitude, longitude),
      date: date,
      calculationParameters: parameters,
    );

    return DailyPrayerTimes(
      locationLabel: settings.locationLabel?.isNotEmpty == true
          ? settings.locationLabel!
          : settings.city,
      calculationLabel: settings.calculationMethod,
      entries: [
        PrayerTimeEntry(
          key: 'fajr',
          label: 'الفجر',
          time: prayerTimes.fajr.toLocal(),
        ),
        PrayerTimeEntry(
          key: 'sunrise',
          label: 'الشروق',
          time: prayerTimes.sunrise.toLocal(),
        ),
        PrayerTimeEntry(
          key: 'dhuhr',
          label: 'الظهر',
          time: prayerTimes.dhuhr.toLocal(),
        ),
        PrayerTimeEntry(
          key: 'asr',
          label: 'العصر',
          time: prayerTimes.asr.toLocal(),
        ),
        PrayerTimeEntry(
          key: 'maghrib',
          label: 'المغرب',
          time: prayerTimes.maghrib.toLocal(),
        ),
        PrayerTimeEntry(
          key: 'isha',
          label: 'العشاء',
          time: prayerTimes.isha.toLocal(),
        ),
      ],
    );
  }

  CalculationParameters _parametersFor(String method) {
    switch (method.trim().toLowerCase()) {
      case 'egyptian':
      case 'الهيئة المصرية العامة للمساحة':
        return CalculationMethodParameters.egyptian();

      case 'ummalqura':
      case 'umm_al_qura':
      case 'أم القرى':
        return CalculationMethodParameters.ummAlQura();

      case 'karachi':
      case 'كراتشي':
        return CalculationMethodParameters.karachi();

      case 'muslimworldleague':
      case 'muslim_world_league':
      case 'رابطة العالم الإسلامي':
        return CalculationMethodParameters.muslimWorldLeague();

      case 'northamerica':
      case 'north_america':
      case 'أمريكا الشمالية':
        return CalculationMethodParameters.northAmerica();

      default:
        return CalculationMethodParameters.egyptian();
    }
  }
}
