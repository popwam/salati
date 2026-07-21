import '../../../core/services/app_preferences.dart';
import '../models/prayer_settings.dart';
import 'prayer_settings_repository.dart';

class LocalPrayerSettingsRepository implements PrayerSettingsRepository {
  LocalPrayerSettingsRepository(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<PrayerSettings> load() async {
    return PrayerSettings(
      country: _preferences.prayerCountry,
      city: _preferences.prayerCity,
      calculationMethod: _preferences.prayerMethod,
      useDeviceLocation: _preferences.prayerUseDeviceLocation,
      notificationsEnabled: _preferences.prayerNotificationsEnabled,
      leadReminderSeconds: _preferences.prayerLeadReminderSeconds,
      overlayAlertsEnabled: _preferences.prayerOverlayAlertsEnabled,
      dndControlEnabled: _preferences.prayerDndControlEnabled,
      priorityCallsEnabled: _preferences.prayerPriorityCallsEnabled,
      keepAwakeEnabled: _preferences.prayerKeepAwakeEnabled,
      focusGuardEnabled: _preferences.prayerFocusGuardEnabled,
      backgroundAudioEnabled: _preferences.backgroundAudioEnabled,
      homeWidgetsEnabled: _preferences.homeWidgetsEnabled,
      qiyamPreference: _preferences.qiyamPreference,
      latitude: _preferences.prayerLatitude,
      longitude: _preferences.prayerLongitude,
      locationLabel: _preferences.prayerLocationLabel,
      lastLocationUpdatedAt: _preferences.prayerLastLocationUpdatedAt,
    );
  }

  @override
  Future<void> save(PrayerSettings settings) async {
    await _preferences.setPrayerCountry(settings.country);
    await _preferences.setPrayerCity(settings.city);
    await _preferences.setPrayerMethod(settings.calculationMethod);

    await _preferences.setPrayerUseDeviceLocation(settings.useDeviceLocation);

    await _preferences.setPrayerNotificationsEnabled(
      settings.notificationsEnabled,
    );
    await _preferences.setPrayerLeadReminderSeconds(
      settings.leadReminderSeconds,
    );
    await _preferences.setPrayerOverlayAlertsEnabled(
      settings.overlayAlertsEnabled,
    );
    await _preferences.setPrayerDndControlEnabled(settings.dndControlEnabled);
    await _preferences.setPrayerPriorityCallsEnabled(
      settings.priorityCallsEnabled,
    );
    await _preferences.setPrayerKeepAwakeEnabled(settings.keepAwakeEnabled);
    await _preferences.setPrayerFocusGuardEnabled(settings.focusGuardEnabled);
    await _preferences.setBackgroundAudioEnabled(
      settings.backgroundAudioEnabled,
    );
    await _preferences.setHomeWidgetsEnabled(settings.homeWidgetsEnabled);
    await _preferences.setQiyamPreference(settings.qiyamPreference);

    // TODO(server-sync): keep this cached location mirrored with the user profile
    // when offline write queues are added.
    if (settings.latitude != null) {
      await _preferences.setPrayerLatitude(settings.latitude!);
    } else {
      await _preferences.clearPrayerLatitude();
    }

    if (settings.longitude != null) {
      await _preferences.setPrayerLongitude(settings.longitude!);
    } else {
      await _preferences.clearPrayerLongitude();
    }

    await _preferences.setPrayerLocationLabel(settings.locationLabel);
    await _preferences.setPrayerLastLocationUpdatedAt(
      settings.lastLocationUpdatedAt,
    );
  }
}
