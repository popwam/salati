import 'qiyam_preference.dart';

class PrayerSettings {
  const PrayerSettings({
    required this.country,
    required this.city,
    required this.calculationMethod,
    required this.notificationsEnabled,
    required this.qiyamPreference,
    this.useDeviceLocation = true,
    this.leadReminderSeconds = 30,
    this.overlayAlertsEnabled = false,
    this.dndControlEnabled = false,
    this.priorityCallsEnabled = false,
    this.keepAwakeEnabled = false,
    this.focusGuardEnabled = false,
    this.backgroundAudioEnabled = false,
    this.homeWidgetsEnabled = false,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.lastLocationUpdatedAt,
  });

  final String country;
  final String city;
  final String calculationMethod;
  final bool useDeviceLocation;
  final bool notificationsEnabled;
  final int leadReminderSeconds;
  final bool overlayAlertsEnabled;
  final bool dndControlEnabled;
  final bool priorityCallsEnabled;
  final bool keepAwakeEnabled;
  final bool focusGuardEnabled;
  final bool backgroundAudioEnabled;
  final bool homeWidgetsEnabled;
  final QiyamPreference qiyamPreference;
  final double? latitude;
  final double? longitude;

  /// مثال: القاهرة الجديدة / البساتين / مدينة نصر
  final String? locationLabel;

  /// آخر مرة فحصنا فيها الموقع.
  final DateTime? lastLocationUpdatedAt;

  PrayerSettings copyWith({
    String? country,
    String? city,
    String? calculationMethod,
    bool? useDeviceLocation,
    bool? notificationsEnabled,
    int? leadReminderSeconds,
    bool? overlayAlertsEnabled,
    bool? dndControlEnabled,
    bool? priorityCallsEnabled,
    bool? keepAwakeEnabled,
    bool? focusGuardEnabled,
    bool? backgroundAudioEnabled,
    bool? homeWidgetsEnabled,
    QiyamPreference? qiyamPreference,
    double? latitude,
    double? longitude,
    String? locationLabel,
    DateTime? lastLocationUpdatedAt,
  }) {
    return PrayerSettings(
      country: country ?? this.country,
      city: city ?? this.city,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      useDeviceLocation: useDeviceLocation ?? this.useDeviceLocation,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      leadReminderSeconds: leadReminderSeconds ?? this.leadReminderSeconds,
      overlayAlertsEnabled: overlayAlertsEnabled ?? this.overlayAlertsEnabled,
      dndControlEnabled: dndControlEnabled ?? this.dndControlEnabled,
      priorityCallsEnabled: priorityCallsEnabled ?? this.priorityCallsEnabled,
      keepAwakeEnabled: keepAwakeEnabled ?? this.keepAwakeEnabled,
      focusGuardEnabled: focusGuardEnabled ?? this.focusGuardEnabled,
      backgroundAudioEnabled:
          backgroundAudioEnabled ?? this.backgroundAudioEnabled,
      homeWidgetsEnabled: homeWidgetsEnabled ?? this.homeWidgetsEnabled,
      qiyamPreference: qiyamPreference ?? this.qiyamPreference,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationLabel: locationLabel ?? this.locationLabel,
      lastLocationUpdatedAt:
          lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
    );
  }
}
