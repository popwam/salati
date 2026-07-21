import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/points_config.dart';
import '../../features/prayer/models/qiyam_preference.dart';

class PrayerScoreSummary {
  const PrayerScoreSummary({
    required this.totalScore,
    required this.completedCount,
    required this.missedCount,
  });

  final double totalScore;
  final int completedCount;
  final int missedCount;
}

class AppPreferences extends ChangeNotifier {
  AppPreferences(this._sharedPreferences);

  static const _selectedTabKey = 'selected_user_tab';
  static const _localeCodeKey = 'locale_code';
  static const _quranTranslationLocaleCodeKey = 'quran_translation_locale_code';
  static const _themeModeKey = 'theme_mode';
  static const _themeStyleKey = 'theme_style';
  static const _appFontKey = 'app_font';
  static const _quranFontKey = 'quran_font';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _initialPermissionsRequestedKey =
      'initial_permissions_requested';
  static const _widgetAddReminderShownKey = 'widget_add_reminder_shown';
  static const _firstCloudRestoreAttemptedKey = 'first_cloud_restore_attempted';
  static const _lastCloudBackupAtKey = 'last_cloud_backup_at';
  static const _proTrialRewardedAdsWatchedKey =
      'pro_trial_rewarded_ads_watched';
  static const _proTrialUnlockedAtKey = 'pro_trial_unlocked_at';
  static const _quranAyahAutoSecondsKey = 'quran_ayah_auto_seconds';
  static const _quranAyahFontSizeKey = 'quran_ayah_font_size';
  static const _quranAyahFontWeightKey = 'quran_ayah_font_weight';
  static const _quranPageFontSizeKey = 'quran_page_font_size';
  static const _quranPageFontWeightKey = 'quran_page_font_weight';
  static const _quranPageFullScreenKey = 'quran_page_full_screen';
  static const _quranPageBookmarkVerseKey = 'quran_page_bookmark_verse';
  static const _quranWordFontWeightKey = 'quran_word_font_weight';
  static const _prayerCountryKey = 'prayer_country';
  static const _prayerCityKey = 'prayer_city';
  static const _prayerMethodKey = 'prayer_method';
  static const _prayerManualLocationEnabledKey =
      'prayer_manual_location_enabled';
  static const _prayerLatitudeKey = 'prayer_latitude';
  static const _prayerLongitudeKey = 'prayer_longitude';
  static const _prayerNotificationsEnabledKey = 'prayer_notifications_enabled';
  static const _disabledAdhanPrayerKeysKey = 'disabled_adhan_prayer_keys';
  static const _selectedAdhanKey = 'selected_adhan_key';
  static const _selectedFajrAdhanKey = 'selected_fajr_adhan_key';
  static const _selectedMorningAzkarSoundKey =
      'selected_morning_azkar_sound_key';
  static const _selectedEveningAzkarSoundKey =
      'selected_evening_azkar_sound_key';
  static const _prayerLeadReminderSecondsKey = 'prayer_lead_reminder_seconds';
  static const _prayerOverlayAlertsEnabledKey = 'prayer_overlay_alerts_enabled';
  static const _prayerDndControlEnabledKey = 'prayer_dnd_control_enabled';
  static const _prayerPriorityCallsEnabledKey = 'prayer_priority_calls_enabled';
  static const _prayerKeepAwakeEnabledKey = 'prayer_keep_awake_enabled';
  static const _prayerFocusGuardEnabledKey = 'prayer_focus_guard_enabled';
  static const _backgroundAudioEnabledKey = 'background_audio_enabled';
  static const _homeWidgetsEnabledKey = 'home_widgets_enabled';
  static const _homeWidgetAccentColorKey = 'home_widget_accent_color';
  static const _homeWidgetThemeModeKey = 'home_widget_theme_mode';
  static const _homeWidgetTextScaleKey = 'home_widget_text_scale';
  static const _homeWidgetShowCountdownKey = 'home_widget_show_countdown';
  static const _homeWidgetShowAllPrayersKey = 'home_widget_show_all_prayers';
  static const _qiyamPreferenceKey = 'qiyam_preference';
  static const _lastReflectionPrayerKey = 'last_reflection_prayer_key';
  static const _lastReflectionAnswerKey = 'last_reflection_answer';
  static const _prayerCompletedRecordsKey = 'prayer_completed_records';
  static const _prayerMissedRecordsKey = 'prayer_missed_records';
  static const _prayerLateCompletedRecordsKey = 'prayer_late_completed_records';
  static const _prayerNawafilRecordsKey = 'prayer_nawafil_records';
  static const _prayerLockedRecordsKey = 'prayer_locked_records';
  static const _quranLastSurahKey = 'quran_last_surah';
  static const _quranLastAyahKey = 'quran_last_ayah';
  static const _quranWirdsKey = 'quran_wirds';
  static const _activeQuranWirdIdKey = 'active_quran_wird_id';
  static const _quranDailyGoalKey = 'quran_daily_goal';
  static const _quranLastUpdatedAtKey = 'quran_last_updated_at';
  static const _adhkarFavoritesKey = 'adhkar_favorites';
  static const _adhkarCompletedKey = 'adhkar_completed';
  static const _adhkarCompletedDateKey = 'adhkar_completed_date';
  static const _adhkarCountsKey = 'adhkar_counts';
  static const _adhkarCountsDateKey = 'adhkar_counts_date';
  static const _duaCompletedKey = 'dua_completed';
  static const _duaCompletedDateKey = 'dua_completed_date';
  static const _morningAdhkarReminderEnabledKey =
      'morning_adhkar_reminder_enabled';
  static const _morningAdhkarReminderMinutesKey =
      'morning_adhkar_reminder_minutes';
  static const _eveningAdhkarReminderEnabledKey =
      'evening_adhkar_reminder_enabled';
  static const _eveningAdhkarReminderMinutesKey =
      'evening_adhkar_reminder_minutes';
  static const _fridayKahfReminderEnabledKey = 'friday_kahf_reminder_enabled';
  static const _fridayKahfReminderMinutesKey = 'friday_kahf_reminder_minutes';
  static const _requireKahfBeforeDailyWirdKey =
      'require_kahf_before_daily_wird';
  static const _kahfCompletedWeekKey = 'kahf_completed_week';
  static const _mulkReminderEnabledKey = 'mulk_reminder_enabled';
  static const _mulkReminderMinutesKey = 'mulk_reminder_minutes';
  static const _prayerUseDeviceLocationKey = 'prayer_use_device_location';
  static const _prayerLocationLabelKey = 'prayer_location_label';
  static const _prayerLastLocationUpdatedAtKey =
      'prayer_last_location_updated_at';
  static const _adhkarSurahAutomationEnabledKey =
      'adhkar_surah_automation_enabled';
  static const _adhkarSurahAutomationFirstKey = 'adhkar_surah_automation_first';
  static const _adhkarAutomationModeKey = 'adhkar_automation_mode';

  static const _syncableKeys = <String>{
    _localeCodeKey,
    _quranTranslationLocaleCodeKey,
    _themeModeKey,
    _themeStyleKey,
    _appFontKey,
    _quranFontKey,
    _quranAyahAutoSecondsKey,
    _quranAyahFontSizeKey,
    _quranAyahFontWeightKey,
    _quranPageFontSizeKey,
    _quranPageFontWeightKey,
    _quranPageFullScreenKey,
    _quranPageBookmarkVerseKey,
    _quranWordFontWeightKey,
    _prayerCountryKey,
    _prayerCityKey,
    _prayerMethodKey,
    _prayerManualLocationEnabledKey,
    _prayerLatitudeKey,
    _prayerLongitudeKey,
    _prayerNotificationsEnabledKey,
    _disabledAdhanPrayerKeysKey,
    _selectedAdhanKey,
    _selectedFajrAdhanKey,
    _selectedMorningAzkarSoundKey,
    _selectedEveningAzkarSoundKey,
    _prayerLeadReminderSecondsKey,
    _prayerOverlayAlertsEnabledKey,
    _prayerDndControlEnabledKey,
    _prayerPriorityCallsEnabledKey,
    _prayerKeepAwakeEnabledKey,
    _prayerFocusGuardEnabledKey,
    _backgroundAudioEnabledKey,
    _homeWidgetsEnabledKey,
    _homeWidgetAccentColorKey,
    _homeWidgetThemeModeKey,
    _homeWidgetTextScaleKey,
    _homeWidgetShowCountdownKey,
    _homeWidgetShowAllPrayersKey,
    _qiyamPreferenceKey,
    _lastReflectionPrayerKey,
    _lastReflectionAnswerKey,
    _prayerCompletedRecordsKey,
    _prayerMissedRecordsKey,
    _prayerLateCompletedRecordsKey,
    _prayerNawafilRecordsKey,
    _prayerLockedRecordsKey,
    _quranLastSurahKey,
    _quranLastAyahKey,
    _quranWirdsKey,
    _activeQuranWirdIdKey,
    _quranDailyGoalKey,
    _quranLastUpdatedAtKey,
    _adhkarFavoritesKey,
    _adhkarCompletedKey,
    _adhkarCompletedDateKey,
    _adhkarCountsKey,
    _adhkarCountsDateKey,
    _duaCompletedKey,
    _duaCompletedDateKey,
    _morningAdhkarReminderEnabledKey,
    _morningAdhkarReminderMinutesKey,
    _eveningAdhkarReminderEnabledKey,
    _eveningAdhkarReminderMinutesKey,
    _fridayKahfReminderEnabledKey,
    _fridayKahfReminderMinutesKey,
    _requireKahfBeforeDailyWirdKey,
    _kahfCompletedWeekKey,
    _mulkReminderEnabledKey,
    _mulkReminderMinutesKey,
    _prayerUseDeviceLocationKey,
    _prayerLocationLabelKey,
    _prayerLastLocationUpdatedAtKey,
    _adhkarSurahAutomationEnabledKey,
    _adhkarSurahAutomationFirstKey,
    _adhkarAutomationModeKey,
  };

  final SharedPreferences _sharedPreferences;

  int get selectedUserTab {
    final index = _sharedPreferences.getInt(_selectedTabKey) ?? 2;
    return index >= 0 && index < 5 ? index : 2;
  }

  Future<void> setSelectedUserTab(int index) async {
    await _sharedPreferences.setInt(_selectedTabKey, index);
    notifyListeners();
  }

  bool get onboardingCompleted =>
      _sharedPreferences.getBool(_onboardingCompletedKey) ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _sharedPreferences.setBool(_onboardingCompletedKey, value);
    notifyListeners();
  }

  bool get initialPermissionsRequested =>
      _sharedPreferences.getBool(_initialPermissionsRequestedKey) ?? false;

  Future<void> setInitialPermissionsRequested(bool value) async {
    await _sharedPreferences.setBool(_initialPermissionsRequestedKey, value);
    notifyListeners();
  }

  bool get widgetAddReminderShown =>
      _sharedPreferences.getBool(_widgetAddReminderShownKey) ?? false;

  Future<void> setWidgetAddReminderShown(bool value) async {
    await _sharedPreferences.setBool(_widgetAddReminderShownKey, value);
    notifyListeners();
  }

  bool get firstCloudRestoreAttempted =>
      _sharedPreferences.getBool(_firstCloudRestoreAttemptedKey) ?? false;

  Future<void> setFirstCloudRestoreAttempted(bool value) async {
    await _sharedPreferences.setBool(_firstCloudRestoreAttemptedKey, value);
    notifyListeners();
  }

  DateTime? get lastCloudBackupAt {
    final value = _sharedPreferences.getString(_lastCloudBackupAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> setLastCloudBackupAt(DateTime? value) async {
    if (value == null) {
      await _sharedPreferences.remove(_lastCloudBackupAtKey);
    } else {
      await _sharedPreferences.setString(
        _lastCloudBackupAtKey,
        value.toIso8601String(),
      );
    }
    notifyListeners();
  }

  String get localeCode => _sharedPreferences.getString(_localeCodeKey) ?? 'ar';

  Locale get locale => Locale(localeCode);

  Future<void> setLocaleCode(String value) async {
    await _sharedPreferences.setString(_localeCodeKey, value);
    notifyListeners();
  }

  String get quranTranslationLocaleCode =>
      _sharedPreferences.getString(_quranTranslationLocaleCodeKey) ??
      localeCode;

  Future<void> setQuranTranslationLocaleCode(String value) async {
    await _sharedPreferences.setString(_quranTranslationLocaleCodeKey, value);
    notifyListeners();
  }

  ThemeMode get themeMode {
    final value = _sharedPreferences.getString(_themeModeKey) ?? 'light';
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await _sharedPreferences.setString(_themeModeKey, value.name);
    notifyListeners();
  }

  String get themeStyleKey =>
      _sharedPreferences.getString(_themeStyleKey) ?? 'emerald';

  Future<void> setThemeStyleKey(String value) async {
    await _sharedPreferences.setString(_themeStyleKey, value);
    notifyListeners();
  }

  String get appFontKey => _sharedPreferences.getString(_appFontKey) ?? 'cairo';

  Future<void> setAppFontKey(String value) async {
    await _sharedPreferences.setString(_appFontKey, value);
    notifyListeners();
  }

  String get quranFontKey =>
      _sharedPreferences.getString(_quranFontKey) ?? 'amiri_quran';

  Future<void> setQuranFontKey(String value) async {
    await _sharedPreferences.setString(_quranFontKey, value);
    notifyListeners();
  }

  int get proTrialRewardedAdsWatched =>
      _sharedPreferences.getInt(_proTrialRewardedAdsWatchedKey) ?? 0;

  Future<int> incrementProTrialRewardedAdsWatched() async {
    final nextValue = (proTrialRewardedAdsWatched + 1).clamp(0, 5).toInt();
    await _sharedPreferences.setInt(_proTrialRewardedAdsWatchedKey, nextValue);
    notifyListeners();
    return nextValue;
  }

  Future<void> setProTrialRewardedAdsWatched(int value) async {
    await _sharedPreferences.setInt(
      _proTrialRewardedAdsWatchedKey,
      value.clamp(0, 5).toInt(),
    );
    notifyListeners();
  }

  Future<void> markProTrialUnlocked() async {
    await _sharedPreferences.setString(
      _proTrialUnlockedAtKey,
      DateTime.now().toIso8601String(),
    );
    await _sharedPreferences.setInt(_proTrialRewardedAdsWatchedKey, 5);
    notifyListeners();
  }

  bool get prayerUseDeviceLocation =>
      _sharedPreferences.getBool(_prayerUseDeviceLocationKey) ?? true;

  Future<void> setPrayerUseDeviceLocation(bool value) async {
    await _sharedPreferences.setBool(_prayerUseDeviceLocationKey, value);
    notifyListeners();
  }

  String? get prayerLocationLabel {
    final value = _sharedPreferences.getString(_prayerLocationLabelKey);
    return value?.trim().isNotEmpty == true ? value!.trim() : null;
  }

  Future<void> setPrayerLocationLabel(String? value) async {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) {
      await _sharedPreferences.remove(_prayerLocationLabelKey);
    } else {
      await _sharedPreferences.setString(_prayerLocationLabelKey, clean);
    }

    notifyListeners();
  }

  DateTime? get prayerLastLocationUpdatedAt {
    final value = _sharedPreferences.getString(_prayerLastLocationUpdatedAtKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<void> setPrayerLastLocationUpdatedAt(DateTime? value) async {
    if (value == null) {
      await _sharedPreferences.remove(_prayerLastLocationUpdatedAtKey);
    } else {
      await _sharedPreferences.setString(
        _prayerLastLocationUpdatedAtKey,
        value.toIso8601String(),
      );
    }

    notifyListeners();
  }

  bool get adhkarSurahAutomationEnabled =>
      _sharedPreferences.getBool(_adhkarSurahAutomationEnabledKey) ?? false;

  Future<void> setAdhkarSurahAutomationEnabled(bool value) async {
    await _sharedPreferences.setBool(_adhkarSurahAutomationEnabledKey, value);
    notifyListeners();
  }

  String get adhkarSurahAutomationFirst =>
      _sharedPreferences.getString(_adhkarSurahAutomationFirstKey) ?? 'adhkar';

  Future<void> setAdhkarSurahAutomationFirst(String value) async {
    final normalized = value == 'surah' ? 'surah' : 'adhkar';
    await _sharedPreferences.setString(
      _adhkarSurahAutomationFirstKey,
      normalized,
    );
    notifyListeners();
  }

  String get adhkarAutomationMode =>
      _sharedPreferences.getString(_adhkarAutomationModeKey) ?? 'read';

  Future<void> setAdhkarAutomationMode(String value) async {
    final normalized = value == 'heard' ? 'heard' : 'read';
    await _sharedPreferences.setString(_adhkarAutomationModeKey, normalized);
    notifyListeners();
  }

  bool get proTrialUnlocked =>
      _sharedPreferences.getString(_proTrialUnlockedAtKey)?.isNotEmpty == true;

  double get quranAyahAutoSeconds =>
      _sharedPreferences.getDouble(_quranAyahAutoSecondsKey) ?? 10;

  Future<void> setQuranAyahAutoSeconds(double value) async {
    await _sharedPreferences.setDouble(_quranAyahAutoSecondsKey, value);
    notifyListeners();
  }

  int get quranAyahFontWeight =>
      _sharedPreferences.getInt(_quranAyahFontWeightKey) ?? 500;

  Future<void> setQuranAyahFontWeight(int value) async {
    await _sharedPreferences.setInt(_quranAyahFontWeightKey, value);
    notifyListeners();
  }

  double get quranAyahFontSize =>
      _sharedPreferences.getDouble(_quranAyahFontSizeKey) ?? 30;

  Future<void> setQuranAyahFontSize(double value) async {
    await _sharedPreferences.setDouble(_quranAyahFontSizeKey, value);
    notifyListeners();
  }

  double get quranPageFontSize =>
      _sharedPreferences.getDouble(_quranPageFontSizeKey) ?? 28;

  Future<void> setQuranPageFontSize(double value) async {
    await _sharedPreferences.setDouble(_quranPageFontSizeKey, value);
    notifyListeners();
  }

  int get quranPageFontWeight =>
      _sharedPreferences.getInt(_quranPageFontWeightKey) ?? 400;

  Future<void> setQuranPageFontWeight(int value) async {
    await _sharedPreferences.setInt(_quranPageFontWeightKey, value);
    notifyListeners();
  }

  bool get quranPageFullScreen =>
      _sharedPreferences.getBool(_quranPageFullScreenKey) ?? false;

  Future<void> setQuranPageFullScreen(bool value) async {
    await _sharedPreferences.setBool(_quranPageFullScreenKey, value);
    notifyListeners();
  }

  String? get quranPageBookmarkVerseKey {
    final value = _sharedPreferences.getString(_quranPageBookmarkVerseKey);
    return value?.trim().isNotEmpty == true ? value!.trim() : null;
  }

  Future<void> setQuranPageBookmarkVerseKey(String value) async {
    await _sharedPreferences.setString(_quranPageBookmarkVerseKey, value);
    notifyListeners();
  }

  int get quranWordFontWeight =>
      _sharedPreferences.getInt(_quranWordFontWeightKey) ?? 300;

  Future<void> setQuranWordFontWeight(int value) async {
    await _sharedPreferences.setInt(_quranWordFontWeightKey, value);
    notifyListeners();
  }

  String get prayerCountry =>
      _sharedPreferences.getString(_prayerCountryKey) ?? 'مصر';

  Future<void> setPrayerCountry(String value) {
    return _sharedPreferences.setString(_prayerCountryKey, value);
  }

  String get prayerCity =>
      _sharedPreferences.getString(_prayerCityKey) ?? 'القاهرة';

  Future<void> setPrayerCity(String value) {
    return _sharedPreferences.setString(_prayerCityKey, value);
  }

  String get prayerMethod =>
      _sharedPreferences.getString(_prayerMethodKey) ??
      'الهيئة المصرية العامة للمساحة';

  Future<void> setPrayerMethod(String value) {
    return _sharedPreferences.setString(_prayerMethodKey, value);
  }

  bool get prayerManualLocationEnabled =>
      _sharedPreferences.getBool(_prayerManualLocationEnabledKey) ?? false;

  Future<void> setPrayerManualLocationEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerManualLocationEnabledKey, value);
  }

  double? get prayerLatitude =>
      _sharedPreferences.getDouble(_prayerLatitudeKey);

  Future<void> setPrayerLatitude(double value) {
    return _sharedPreferences.setDouble(_prayerLatitudeKey, value);
  }

  Future<void> clearPrayerLatitude() {
    return _sharedPreferences.remove(_prayerLatitudeKey);
  }

  double? get prayerLongitude =>
      _sharedPreferences.getDouble(_prayerLongitudeKey);

  Future<void> setPrayerLongitude(double value) {
    return _sharedPreferences.setDouble(_prayerLongitudeKey, value);
  }

  Future<void> clearPrayerLongitude() {
    return _sharedPreferences.remove(_prayerLongitudeKey);
  }

  bool get prayerNotificationsEnabled =>
      _sharedPreferences.getBool(_prayerNotificationsEnabledKey) ?? true;

  Future<void> setPrayerNotificationsEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerNotificationsEnabledKey, value);
  }

  Set<String> get disabledAdhanPrayerKeys =>
      _sharedPreferences.getStringList(_disabledAdhanPrayerKeysKey)?.toSet() ??
      {};

  bool isAdhanEnabledForPrayer(String prayerKey) {
    return !disabledAdhanPrayerKeys.contains(prayerKey);
  }

  String get selectedAdhanKey =>
      _sharedPreferences.getString(_selectedAdhanKey) ?? 'default_adhan';

  Future<void> setSelectedAdhanKey(String value) async {
    await _sharedPreferences.setString(_selectedAdhanKey, value);
    notifyListeners();
  }

  String get selectedFajrAdhanKey =>
      _sharedPreferences.getString(_selectedFajrAdhanKey) ??
      'fajr_default_adhan';

  Future<void> setSelectedFajrAdhanKey(String value) async {
    await _sharedPreferences.setString(_selectedFajrAdhanKey, value);
    notifyListeners();
  }

  String get selectedMorningAzkarSoundKey =>
      _sharedPreferences.getString(_selectedMorningAzkarSoundKey) ??
      'azkar_morning';

  Future<void> setSelectedMorningAzkarSoundKey(String value) async {
    await _sharedPreferences.setString(_selectedMorningAzkarSoundKey, value);
    notifyListeners();
  }

  String get selectedEveningAzkarSoundKey =>
      _sharedPreferences.getString(_selectedEveningAzkarSoundKey) ??
      'azkar_evening';

  Future<void> setSelectedEveningAzkarSoundKey(String value) async {
    await _sharedPreferences.setString(_selectedEveningAzkarSoundKey, value);
    notifyListeners();
  }

  Future<void> setAdhanEnabledForPrayer(String prayerKey, bool enabled) async {
    final disabled = disabledAdhanPrayerKeys;
    if (enabled) {
      disabled.remove(prayerKey);
    } else {
      disabled.add(prayerKey);
    }
    await _sharedPreferences.setStringList(
      _disabledAdhanPrayerKeysKey,
      disabled.toList()..sort(),
    );
    notifyListeners();
  }

  int get prayerLeadReminderSeconds =>
      _sharedPreferences.getInt(_prayerLeadReminderSecondsKey) ?? 30;

  Future<void> setPrayerLeadReminderSeconds(int value) {
    return _sharedPreferences.setInt(_prayerLeadReminderSecondsKey, value);
  }

  bool get prayerOverlayAlertsEnabled =>
      _sharedPreferences.getBool(_prayerOverlayAlertsEnabledKey) ?? false;

  Future<void> setPrayerOverlayAlertsEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerOverlayAlertsEnabledKey, value);
  }

  bool get prayerDndControlEnabled =>
      _sharedPreferences.getBool(_prayerDndControlEnabledKey) ?? false;

  Future<void> setPrayerDndControlEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerDndControlEnabledKey, value);
  }

  bool get prayerPriorityCallsEnabled =>
      _sharedPreferences.getBool(_prayerPriorityCallsEnabledKey) ?? false;

  Future<void> setPrayerPriorityCallsEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerPriorityCallsEnabledKey, value);
  }

  bool get prayerKeepAwakeEnabled =>
      _sharedPreferences.getBool(_prayerKeepAwakeEnabledKey) ?? false;

  Future<void> setPrayerKeepAwakeEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerKeepAwakeEnabledKey, value);
  }

  bool get prayerFocusGuardEnabled =>
      _sharedPreferences.getBool(_prayerFocusGuardEnabledKey) ?? false;

  Future<void> setPrayerFocusGuardEnabled(bool value) {
    return _sharedPreferences.setBool(_prayerFocusGuardEnabledKey, value);
  }

  bool get backgroundAudioEnabled =>
      _sharedPreferences.getBool(_backgroundAudioEnabledKey) ?? false;

  Future<void> setBackgroundAudioEnabled(bool value) {
    return _sharedPreferences.setBool(_backgroundAudioEnabledKey, value);
  }

  bool get homeWidgetsEnabled =>
      _sharedPreferences.getBool(_homeWidgetsEnabledKey) ?? true;

  Future<void> setHomeWidgetsEnabled(bool value) async {
    await _sharedPreferences.setBool(_homeWidgetsEnabledKey, value);
    notifyListeners();
  }

  String get homeWidgetAccentColor =>
      _sharedPreferences.getString(_homeWidgetAccentColorKey) ?? '#1F9D62';

  Future<void> setHomeWidgetAccentColor(String value) async {
    await _sharedPreferences.setString(_homeWidgetAccentColorKey, value);
    notifyListeners();
  }

  String get homeWidgetThemeMode =>
      _sharedPreferences.getString(_homeWidgetThemeModeKey) ?? 'system';

  Future<void> setHomeWidgetThemeMode(String value) async {
    await _sharedPreferences.setString(_homeWidgetThemeModeKey, value);
    notifyListeners();
  }

  double get homeWidgetTextScale =>
      (_sharedPreferences.getDouble(_homeWidgetTextScaleKey) ?? 1.0)
          .clamp(0.85, 1.35)
          .toDouble();

  Future<void> setHomeWidgetTextScale(double value) async {
    await _sharedPreferences.setDouble(
      _homeWidgetTextScaleKey,
      value.clamp(0.85, 1.35).toDouble(),
    );
    notifyListeners();
  }

  bool get homeWidgetShowCountdown =>
      _sharedPreferences.getBool(_homeWidgetShowCountdownKey) ?? true;

  Future<void> setHomeWidgetShowCountdown(bool value) async {
    await _sharedPreferences.setBool(_homeWidgetShowCountdownKey, value);
    notifyListeners();
  }

  bool get homeWidgetShowAllPrayers =>
      _sharedPreferences.getBool(_homeWidgetShowAllPrayersKey) ?? true;

  Future<void> setHomeWidgetShowAllPrayers(bool value) async {
    await _sharedPreferences.setBool(_homeWidgetShowAllPrayersKey, value);
    notifyListeners();
  }

  QiyamPreference get qiyamPreference {
    final value = _sharedPreferences.getString(_qiyamPreferenceKey);
    return qiyamPreferenceFromKey(value);
  }

  Future<void> setQiyamPreference(QiyamPreference value) {
    return _sharedPreferences.setString(_qiyamPreferenceKey, value.key);
  }

  bool get morningAdhkarReminderEnabled =>
      _sharedPreferences.getBool(_morningAdhkarReminderEnabledKey) ?? false;

  Future<void> setMorningAdhkarReminderEnabled(bool value) async {
    await _sharedPreferences.setBool(_morningAdhkarReminderEnabledKey, value);
    notifyListeners();
  }

  int get morningAdhkarReminderMinutes =>
      _dayMinute(_morningAdhkarReminderMinutesKey, 6 * 60);

  Future<void> setMorningAdhkarReminderMinutes(int value) async {
    await _sharedPreferences.setInt(
      _morningAdhkarReminderMinutesKey,
      _clampDayMinute(value),
    );
    notifyListeners();
  }

  bool get eveningAdhkarReminderEnabled =>
      _sharedPreferences.getBool(_eveningAdhkarReminderEnabledKey) ?? false;

  Future<void> setEveningAdhkarReminderEnabled(bool value) async {
    await _sharedPreferences.setBool(_eveningAdhkarReminderEnabledKey, value);
    notifyListeners();
  }

  int get eveningAdhkarReminderMinutes =>
      _dayMinute(_eveningAdhkarReminderMinutesKey, 18 * 60);

  Future<void> setEveningAdhkarReminderMinutes(int value) async {
    await _sharedPreferences.setInt(
      _eveningAdhkarReminderMinutesKey,
      _clampDayMinute(value),
    );
    notifyListeners();
  }

  bool get fridayKahfReminderEnabled =>
      _sharedPreferences.getBool(_fridayKahfReminderEnabledKey) ?? false;

  Future<void> setFridayKahfReminderEnabled(bool value) async {
    await _sharedPreferences.setBool(_fridayKahfReminderEnabledKey, value);
    notifyListeners();
  }

  int get fridayKahfReminderMinutes =>
      _dayMinute(_fridayKahfReminderMinutesKey, 9 * 60);

  Future<void> setFridayKahfReminderMinutes(int value) async {
    await _sharedPreferences.setInt(
      _fridayKahfReminderMinutesKey,
      _clampDayMinute(value),
    );
    notifyListeners();
  }

  bool get requireKahfBeforeDailyWird =>
      _sharedPreferences.getBool(_requireKahfBeforeDailyWirdKey) ?? false;

  Future<void> setRequireKahfBeforeDailyWird(bool value) async {
    await _sharedPreferences.setBool(_requireKahfBeforeDailyWirdKey, value);
    notifyListeners();
  }

  bool get mulkReminderEnabled =>
      _sharedPreferences.getBool(_mulkReminderEnabledKey) ?? false;

  Future<void> setMulkReminderEnabled(bool value) async {
    await _sharedPreferences.setBool(_mulkReminderEnabledKey, value);
    notifyListeners();
  }

  int get mulkReminderMinutes => _dayMinute(_mulkReminderMinutesKey, 21 * 60);

  Future<void> setMulkReminderMinutes(int value) async {
    await _sharedPreferences.setInt(
      _mulkReminderMinutesKey,
      _clampDayMinute(value),
    );
    notifyListeners();
  }

  bool get isKahfGateActiveToday {
    final now = DateTime.now();
    return requireKahfBeforeDailyWird &&
        now.weekday == DateTime.friday &&
        !isKahfCompletedForCurrentWeek;
  }

  bool get isKahfCompletedForCurrentWeek =>
      _sharedPreferences.getString(_kahfCompletedWeekKey) ==
      _kahfWeekKey(DateTime.now());

  Future<void> markKahfCompletedForCurrentWeek() async {
    await _sharedPreferences.setString(
      _kahfCompletedWeekKey,
      _kahfWeekKey(DateTime.now()),
    );
    notifyListeners();
  }

  String? get lastReflectionPrayerKey =>
      _sharedPreferences.getString(_lastReflectionPrayerKey);

  String? get lastReflectionAnswer =>
      _sharedPreferences.getString(_lastReflectionAnswerKey);

  Future<void> savePrayerReflection({
    required String prayerKey,
    required String answer,
  }) async {
    await _sharedPreferences.setString(_lastReflectionPrayerKey, prayerKey);
    await _sharedPreferences.setString(_lastReflectionAnswerKey, answer);
  }

  Set<String> completedPrayerKeysForDate(DateTime date) {
    return _recordsForDate(_prayerCompletedRecordsKey, date);
  }

  Set<String> missedPrayerKeysForDate(DateTime date) {
    return _recordsForDate(_prayerMissedRecordsKey, date);
  }

  Set<String> nawafilPrayerKeysForDate(DateTime date) {
    return _recordsForDate(_prayerNawafilRecordsKey, date);
  }

  Set<String> lateCompletedPrayerKeysForDate(DateTime date) {
    return _recordsForDate(_prayerLateCompletedRecordsKey, date);
  }

  Set<String> lockedPrayerKeysForDate(DateTime date) {
    return _recordsForDate(_prayerLockedRecordsKey, date);
  }

  bool isPrayerLocked({required String prayerKey, required DateTime date}) {
    return lockedPrayerKeysForDate(date).contains(prayerKey);
  }

  PrayerScoreSummary get prayerScoreSummary {
    return prayerScoreSummaryForRule(PlanPointsRule.free);
  }

  PrayerScoreSummary prayerScoreSummaryForRule(PlanPointsRule rule) {
    final completedCount = _allRecords(_prayerCompletedRecordsKey).length;
    final missedCount = _allRecords(_prayerMissedRecordsKey).length;
    final lateCompletedCount = _allRecords(
      _prayerLateCompletedRecordsKey,
    ).length;
    final nawafilCount = _allRecords(_prayerNawafilRecordsKey).length;
    return PrayerScoreSummary(
      totalScore:
          ((completedCount - lateCompletedCount) * rule.prayerOnTime) +
          (lateCompletedCount * rule.prayerLate) +
          (nawafilCount * 0.25) -
          (missedCount * rule.prayerMissed.abs()),
      completedCount: completedCount,
      missedCount: missedCount,
    );
  }

  double get cumulativePrayerScore => prayerScoreSummary.totalScore;

  PrayerScoreSummary dailyPrayerScoreSummary(DateTime date) {
    return dailyPrayerScoreSummaryForRule(date, PlanPointsRule.free);
  }

  PrayerScoreSummary dailyPrayerScoreSummaryForRule(
    DateTime date,
    PlanPointsRule rule,
  ) {
    final completedCount = completedPrayerKeysForDate(date).length;
    final missedCount = missedPrayerKeysForDate(date).length;
    final lateCompletedCount = lateCompletedPrayerKeysForDate(date).length;
    final nawafilCount = nawafilPrayerKeysForDate(date).length;
    return PrayerScoreSummary(
      totalScore:
          ((completedCount - lateCompletedCount) * rule.prayerOnTime) +
          (lateCompletedCount * rule.prayerLate) +
          (nawafilCount * 0.25) -
          (missedCount * rule.prayerMissed.abs()),
      completedCount: completedCount,
      missedCount: missedCount,
    );
  }

  double dailyPrayerScore(DateTime date) {
    return dailyPrayerScoreSummary(date).totalScore;
  }

  Future<void> markPrayerCompleted({
    required String prayerKey,
    DateTime? date,
    bool withNawafil = false,
    bool completedLate = false,
  }) async {
    final targetDate = date ?? DateTime.now();
    final completed = completedPrayerKeysForDate(targetDate);
    final missed = missedPrayerKeysForDate(targetDate);
    final lateCompleted = lateCompletedPrayerKeysForDate(targetDate);
    final nawafil = nawafilPrayerKeysForDate(targetDate);
    final locked = lockedPrayerKeysForDate(targetDate);
    final wasLocked = locked.contains(prayerKey);
    if (wasLocked && !missed.contains(prayerKey)) {
      return;
    }
    completed.add(prayerKey);
    missed.remove(prayerKey);
    if (wasLocked || completedLate) {
      lateCompleted.add(prayerKey);
    } else {
      lateCompleted.remove(prayerKey);
    }
    if (wasLocked || completedLate) {
      nawafil.remove(prayerKey);
    } else if (withNawafil) {
      nawafil.add(prayerKey);
    } else {
      nawafil.remove(prayerKey);
    }
    locked.add(prayerKey);
    await _saveRecords(_prayerCompletedRecordsKey, completed, targetDate);
    await _saveRecords(_prayerMissedRecordsKey, missed, targetDate);
    await _saveRecords(
      _prayerLateCompletedRecordsKey,
      lateCompleted,
      targetDate,
    );
    await _saveRecords(_prayerNawafilRecordsKey, nawafil, targetDate);
    await _saveRecords(_prayerLockedRecordsKey, locked, targetDate);
    notifyListeners();
  }

  Future<void> markPrayerMissed({
    required String prayerKey,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    if (isPrayerLocked(prayerKey: prayerKey, date: targetDate)) {
      return;
    }
    final completed = completedPrayerKeysForDate(targetDate);
    final missed = missedPrayerKeysForDate(targetDate);
    final lateCompleted = lateCompletedPrayerKeysForDate(targetDate);
    final nawafil = nawafilPrayerKeysForDate(targetDate);
    final locked = lockedPrayerKeysForDate(targetDate);
    completed.remove(prayerKey);
    missed.add(prayerKey);
    lateCompleted.remove(prayerKey);
    nawafil.remove(prayerKey);
    locked.add(prayerKey);
    await _saveRecords(_prayerCompletedRecordsKey, completed, targetDate);
    await _saveRecords(_prayerMissedRecordsKey, missed, targetDate);
    await _saveRecords(
      _prayerLateCompletedRecordsKey,
      lateCompleted,
      targetDate,
    );
    await _saveRecords(_prayerNawafilRecordsKey, nawafil, targetDate);
    await _saveRecords(_prayerLockedRecordsKey, locked, targetDate);
    notifyListeners();
  }

  double completedPrayerScore(DateTime date) {
    return dailyPrayerScore(date);
  }

  int get quranLastSurah => _sharedPreferences.getInt(_quranLastSurahKey) ?? 1;

  Future<void> setQuranLastSurah(int value) {
    return _sharedPreferences.setInt(_quranLastSurahKey, value);
  }

  int get quranLastAyah => _sharedPreferences.getInt(_quranLastAyahKey) ?? 1;

  Future<void> setQuranLastAyah(int value) {
    return _sharedPreferences.setInt(_quranLastAyahKey, value);
  }

  List<String> get quranWirdRecords =>
      _sharedPreferences.getStringList(_quranWirdsKey) ?? const [];

  Future<void> setQuranWirdRecords(List<String> values) async {
    await _sharedPreferences.setStringList(_quranWirdsKey, values);
    notifyListeners();
  }

  String? get activeQuranWirdId =>
      _sharedPreferences.getString(_activeQuranWirdIdKey);

  Future<void> setActiveQuranWirdId(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _sharedPreferences.remove(_activeQuranWirdIdKey);
    } else {
      await _sharedPreferences.setString(_activeQuranWirdIdKey, normalized);
    }
    notifyListeners();
  }

  int get quranDailyGoal => _sharedPreferences.getInt(_quranDailyGoalKey) ?? 1;

  Future<void> setQuranDailyGoal(int value) {
    return _sharedPreferences.setInt(_quranDailyGoalKey, value);
  }

  String? get quranLastUpdatedAt =>
      _sharedPreferences.getString(_quranLastUpdatedAtKey);

  Future<void> setQuranLastUpdatedAt(String value) {
    return _sharedPreferences.setString(_quranLastUpdatedAtKey, value);
  }

  Set<String> get adhkarFavorites =>
      _sharedPreferences.getStringList(_adhkarFavoritesKey)?.toSet() ?? {};

  Future<void> setAdhkarFavorites(Set<String> values) {
    return _sharedPreferences.setStringList(
      _adhkarFavoritesKey,
      values.toList(),
    );
  }

  Set<String> get adhkarCompleted =>
      _sharedPreferences.getStringList(_adhkarCompletedKey)?.toSet() ?? {};

  Future<void> setAdhkarCompleted(Set<String> values) {
    return _sharedPreferences.setStringList(
      _adhkarCompletedKey,
      values.toList(),
    );
  }

  String? get adhkarCompletedDate =>
      _sharedPreferences.getString(_adhkarCompletedDateKey);

  Future<void> setAdhkarCompletedDate(String value) {
    return _sharedPreferences.setString(_adhkarCompletedDateKey, value);
  }

  Map<String, int> get adhkarCounts {
    final items =
        _sharedPreferences.getStringList(_adhkarCountsKey) ?? const [];
    final result = <String, int>{};
    for (final entry in items) {
      final separatorIndex = entry.indexOf('|');
      if (separatorIndex <= 0 || separatorIndex >= entry.length - 1) {
        continue;
      }
      final key = entry.substring(0, separatorIndex);
      final value = int.tryParse(entry.substring(separatorIndex + 1));
      if (key.isNotEmpty && value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  Future<void> setAdhkarCounts(Map<String, int> values) {
    final serialized = values.entries
        .map((entry) => '${entry.key}|${entry.value}')
        .toList();
    return _sharedPreferences.setStringList(_adhkarCountsKey, serialized);
  }

  String? get adhkarCountsDate =>
      _sharedPreferences.getString(_adhkarCountsDateKey);

  Future<void> setAdhkarCountsDate(String value) {
    return _sharedPreferences.setString(_adhkarCountsDateKey, value);
  }

  Set<String> get duaCompleted =>
      _sharedPreferences.getStringList(_duaCompletedKey)?.toSet() ?? {};

  Future<void> setDuaCompleted(Set<String> values) {
    return _sharedPreferences.setStringList(_duaCompletedKey, values.toList());
  }

  String? get duaCompletedDate =>
      _sharedPreferences.getString(_duaCompletedDateKey);

  Future<void> setDuaCompletedDate(String value) {
    return _sharedPreferences.setString(_duaCompletedDateKey, value);
  }

  Map<String, Object?> exportSyncSnapshot() {
    final values = <String, Object?>{};

    for (final key in _syncableKeys) {
      if (!_sharedPreferences.containsKey(key)) {
        continue;
      }

      final value = _sharedPreferences.get(key);
      if (value is String || value is bool || value is int || value is double) {
        values[key] = value;
      } else if (value is List<String>) {
        values[key] = List<String>.from(value);
      }
    }

    return {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'values': values,
    };
  }

  Future<void> importSyncSnapshot(Map<String, dynamic> snapshot) async {
    final rawValues = snapshot['values'];
    if (rawValues is! Map) {
      return;
    }

    for (final entry in rawValues.entries) {
      final key = entry.key.toString();
      if (!_syncableKeys.contains(key)) {
        continue;
      }

      final value = entry.value;
      if (value == null) {
        await _sharedPreferences.remove(key);
      } else if (value is bool) {
        await _sharedPreferences.setBool(key, value);
      } else if (value is int) {
        await _sharedPreferences.setInt(key, value);
      } else if (value is double) {
        await _sharedPreferences.setDouble(key, value);
      } else if (value is String) {
        await _sharedPreferences.setString(key, value);
      } else if (value is Iterable) {
        await _sharedPreferences.setStringList(
          key,
          value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        );
      }
    }

    notifyListeners();
  }

  Set<String> _recordsForDate(String key, DateTime date) {
    final stamp = _dateStamp(date);
    final records = _sharedPreferences.getStringList(key) ?? const [];
    return records
        .where((item) => item.startsWith('$stamp:'))
        .map((item) => item.split(':').last)
        .toSet();
  }

  Set<String> _allRecords(String key) {
    return (_sharedPreferences.getStringList(key) ?? const []).toSet();
  }

  Future<void> _saveRecords(
    String key,
    Set<String> prayerKeys,
    DateTime date,
  ) async {
    final stamp = _dateStamp(date);
    final records = _sharedPreferences.getStringList(key) ?? const [];
    final preserved = records
        .where((item) => !item.startsWith('$stamp:'))
        .toList();
    final updated = [...preserved, ...prayerKeys.map((item) => '$stamp:$item')];
    await _sharedPreferences.setStringList(key, updated);
  }

  int _dayMinute(String key, int fallback) {
    return _clampDayMinute(_sharedPreferences.getInt(key) ?? fallback);
  }

  int _clampDayMinute(int value) {
    if (value < 0) {
      return 0;
    }
    if (value >= 24 * 60) {
      return (24 * 60) - 1;
    }
    return value;
  }

  String _kahfWeekKey(DateTime value) {
    final friday = value.add(Duration(days: DateTime.friday - value.weekday));
    return _dateStamp(friday);
  }

  String _dateStamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
