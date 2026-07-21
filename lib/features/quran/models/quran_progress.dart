class QuranProgress {
  const QuranProgress({
    required this.lastReadSurah,
    required this.lastReadAyah,
    required this.dailyGoalPages,
    this.lastUpdatedAt,
  });

  final int lastReadSurah;
  final int lastReadAyah;
  final int dailyGoalPages;
  final DateTime? lastUpdatedAt;

  QuranProgress copyWith({
    int? lastReadSurah,
    int? lastReadAyah,
    int? dailyGoalPages,
    DateTime? lastUpdatedAt,
  }) {
    return QuranProgress(
      lastReadSurah: lastReadSurah ?? this.lastReadSurah,
      lastReadAyah: lastReadAyah ?? this.lastReadAyah,
      dailyGoalPages: dailyGoalPages ?? this.dailyGoalPages,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
