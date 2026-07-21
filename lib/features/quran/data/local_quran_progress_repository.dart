import '../../../core/services/app_preferences.dart';
import '../models/quran_progress.dart';

class LocalQuranProgressRepository {
  LocalQuranProgressRepository(this._preferences);

  final AppPreferences _preferences;

  List<String> get quranWirdRecords => _preferences.quranWirdRecords;

  String? get activeQuranWirdId => _preferences.activeQuranWirdId;

  Future<void> setQuranWirdRecords(List<String> values) {
    return _preferences.setQuranWirdRecords(values);
  }

  Future<void> setActiveQuranWirdId(String? value) {
    return _preferences.setActiveQuranWirdId(value);
  }

  Future<QuranProgress> load() async {
    return QuranProgress(
      lastReadSurah: _preferences.quranLastSurah,
      lastReadAyah: _preferences.quranLastAyah,
      dailyGoalPages: _preferences.quranDailyGoal,
      lastUpdatedAt: DateTime.tryParse(_preferences.quranLastUpdatedAt ?? ''),
    );
  }

  Future<void> save(QuranProgress progress) async {
    final savedAt = progress.lastUpdatedAt ?? DateTime.now();
    await _preferences.setQuranLastSurah(progress.lastReadSurah);
    await _preferences.setQuranLastAyah(progress.lastReadAyah);
    await _preferences.setQuranDailyGoal(progress.dailyGoalPages);
    await _preferences.setQuranLastUpdatedAt(savedAt.toIso8601String());
  }
}
