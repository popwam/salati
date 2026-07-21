class PrayerGuide {
  const PrayerGuide({
    required this.prayerKey,
    required this.prayerName,
    required this.beforeRakaat,
    required this.beforeNote,
    required this.fardRakaat,
    required this.fardNote,
    required this.afterRakaat,
    required this.afterNote,
    required this.recitationGuidance,
    required this.simpleSteps,
    required this.wuduGuidance,
    required this.notes,
  });

  final String prayerKey;
  final String prayerName;
  final int beforeRakaat;
  final String beforeNote;
  final int fardRakaat;
  final String fardNote;
  final int afterRakaat;
  final String afterNote;
  final List<String> recitationGuidance;
  final List<String> simpleSteps;
  final List<String> wuduGuidance;
  final List<String> notes;
}
