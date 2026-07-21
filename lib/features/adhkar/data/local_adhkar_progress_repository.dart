import '../../../core/services/app_preferences.dart';

class LocalAdhkarProgressRepository {
  LocalAdhkarProgressRepository(this._preferences);

  final AppPreferences _preferences;

  Future<Set<String>> loadFavorites() async {
    return _preferences.adhkarFavorites;
  }

  Future<void> saveFavorites(Set<String> values) {
    return _preferences.setAdhkarFavorites(values);
  }

  Future<Set<String>> loadCompleted() async {
    final storedDate = _preferences.adhkarCompletedDate;
    final todayKey = _todayKey();
    if (storedDate != todayKey) {
      await _preferences.setAdhkarCompleted({});
      await _preferences.setAdhkarCompletedDate(todayKey);
      return {};
    }

    return _preferences.adhkarCompleted;
  }

  Future<Map<String, int>> loadCounts() async {
    final storedDate = _preferences.adhkarCountsDate;
    final todayKey = _todayKey();
    if (storedDate != todayKey) {
      await _preferences.setAdhkarCounts({});
      await _preferences.setAdhkarCountsDate(todayKey);
      await _preferences.setAdhkarCompleted({});
      await _preferences.setAdhkarCompletedDate(todayKey);
      return {};
    }

    return _preferences.adhkarCounts;
  }

  Future<void> saveCounts(Map<String, int> values) async {
    await _preferences.setAdhkarCountsDate(_todayKey());
    await _preferences.setAdhkarCounts(values);
  }

  Future<void> saveCompleted(Set<String> values) async {
    await _preferences.setAdhkarCompletedDate(_todayKey());
    await _preferences.setAdhkarCompleted(values);
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
