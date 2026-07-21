class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.key,
    required this.label,
    required this.time,
  });

  final String key;
  final String label;
  final DateTime time;
}

class DailyPrayerTimes {
  const DailyPrayerTimes({
    required this.entries,
    required this.locationLabel,
    required this.calculationLabel,
  });

  final List<PrayerTimeEntry> entries;
  final String locationLabel;
  final String calculationLabel;

  PrayerTimeEntry? get nextPrayer {
    final now = DateTime.now();
    for (final entry in entries) {
      if (entry.time.isAfter(now)) {
        return entry;
      }
    }
    return entries.isNotEmpty ? entries.first : null;
  }

  PrayerTimeEntry? entryFor(String key) {
    for (final entry in entries) {
      if (entry.key == key) {
        return entry;
      }
    }
    return null;
  }
}
