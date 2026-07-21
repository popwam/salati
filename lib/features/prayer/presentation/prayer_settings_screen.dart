import 'package:flutter/material.dart';

import '../../../core/models/feature_entitlement.dart';
import '../../../core/services/android_permission_settings_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/salati_widgets_service.dart';
import '../../../shared/widgets/loading_state_view.dart';
import '../data/prayer_settings_repository.dart';
import '../models/prayer_settings.dart';
import '../models/qiyam_preference.dart';
import '../services/device_location_service.dart';
import '../services/local_prayer_times_service.dart';
import 'prayer_settings_controller.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({
    super.key,
    required this.repository,
    required this.services,
    required this.preferences,
  });

  final PrayerSettingsRepository repository;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  static const _morningAdhkarNotificationId = 920001;
  static const _eveningAdhkarNotificationId = 920002;
  static const _fridayKahfNotificationId = 920003;
  static const _mulkNotificationId = 920004;
  static const double _locationRefreshDistanceMeters = 50000; // 50 كم

  late final PrayerSettingsController _controller;

  final _permissionSettings = const AndroidPermissionSettingsService();
  final _deviceLocationService = const DeviceLocationService();

  bool _notificationsEnabled = false;
  int _leadReminderSeconds = 30;
  bool _focusGuardEnabled = false;
  QiyamPreference _qiyamPreference = QiyamPreference.lastThird;

  bool _morningAdhkarReminderEnabled = false;
  int _morningAdhkarReminderMinutes = 6 * 60;

  bool _eveningAdhkarReminderEnabled = false;
  int _eveningAdhkarReminderMinutes = 18 * 60;

  bool _fridayKahfReminderEnabled = false;
  int _fridayKahfReminderMinutes = 9 * 60;

  bool _requireKahfBeforeDailyWird = false;
  bool _adhkarSurahAutomationEnabled = false;
  String _adhkarSurahAutomationFirst = 'adhkar';
  String _adhkarAutomationMode = 'read';

  bool _mulkReminderEnabled = false;
  int _mulkReminderMinutes = 21 * 60;

  bool _useDeviceLocation = true;
  bool _homeWidgetsEnabled = true;
  String _selectedAdhanKey = 'default_adhan';
  String _selectedFajrAdhanKey = 'fajr_default_adhan';
  String _selectedMorningAzkarSoundKey = 'azkar_morning';
  String _selectedEveningAzkarSoundKey = 'azkar_evening';
  String? _notificationSyncWarning;

  @override
  void initState() {
    super.initState();
    _controller = PrayerSettingsController(repository: widget.repository);
    _controller.addListener(_syncForm);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _controller.load();
    await _refreshDeviceLocationIfNeeded();
  }

  void _syncForm() {
    if (_controller.isSaving) {
      return;
    }

    final settings = _controller.settings;
    if (settings == null) {
      return;
    }

    _useDeviceLocation = settings.useDeviceLocation;
    _homeWidgetsEnabled = settings.homeWidgetsEnabled;
    _notificationsEnabled = settings.notificationsEnabled;
    _leadReminderSeconds = settings.leadReminderSeconds;
    _focusGuardEnabled = settings.focusGuardEnabled;
    _qiyamPreference = settings.qiyamPreference;

    _morningAdhkarReminderEnabled =
        widget.preferences.morningAdhkarReminderEnabled;
    _morningAdhkarReminderMinutes =
        widget.preferences.morningAdhkarReminderMinutes;

    _eveningAdhkarReminderEnabled =
        widget.preferences.eveningAdhkarReminderEnabled;
    _eveningAdhkarReminderMinutes =
        widget.preferences.eveningAdhkarReminderMinutes;

    _fridayKahfReminderEnabled = widget.preferences.fridayKahfReminderEnabled;
    _fridayKahfReminderMinutes = widget.preferences.fridayKahfReminderMinutes;

    _requireKahfBeforeDailyWird = widget.preferences.requireKahfBeforeDailyWird;
    _adhkarSurahAutomationEnabled =
        widget.preferences.adhkarSurahAutomationEnabled;
    _adhkarSurahAutomationFirst = widget.preferences.adhkarSurahAutomationFirst;
    _adhkarAutomationMode = widget.preferences.adhkarAutomationMode;

    _mulkReminderEnabled = widget.preferences.mulkReminderEnabled;
    _mulkReminderMinutes = widget.preferences.mulkReminderMinutes;
    _selectedAdhanKey = widget.preferences.selectedAdhanKey;
    _selectedFajrAdhanKey = widget.preferences.selectedFajrAdhanKey;
    _selectedMorningAzkarSoundKey =
        widget.preferences.selectedMorningAzkarSoundKey;
    _selectedEveningAzkarSoundKey =
        widget.preferences.selectedEveningAzkarSoundKey;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncForm)
      ..dispose();
    super.dispose();
  }

  Future<void> _refreshDeviceLocationIfNeeded({bool force = false}) async {
    final settings = _controller.settings;
    if (settings == null || !settings.useDeviceLocation) {
      return;
    }

    final position = await _deviceLocationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر الحصول على الموقع. تأكد من تشغيل خدمة الموقع.'),
        ),
      );
      return;
    }

    var shouldUpdate = force;

    if (!shouldUpdate) {
      final oldLat = settings.latitude;
      final oldLng = settings.longitude;

      if (oldLat == null || oldLng == null) {
        shouldUpdate = true;
      } else {
        final distance = _deviceLocationService.distanceBetweenMeters(
          oldLatitude: oldLat,
          oldLongitude: oldLng,
          newLatitude: position.latitude,
          newLongitude: position.longitude,
        );

        shouldUpdate = distance >= _locationRefreshDistanceMeters;
      }
    }

    if (!shouldUpdate) {
      return;
    }

    final locationLabel = await _deviceLocationService
        .getLocationLabelFromPosition(position);

    final updatedSettings = settings.copyWith(
      latitude: position.latitude,
      longitude: position.longitude,
      locationLabel: locationLabel,
      lastLocationUpdatedAt: DateTime.now(),
      useDeviceLocation: true,
    );

    await _controller.save(updatedSettings);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم تحديث الموقع: $locationLabel')));

    setState(() {});
  }

  Future<void> _save() async {
    final currentSettings = _controller.settings;

    if (currentSettings == null) {
      return;
    }

    final settings = currentSettings.copyWith(
      notificationsEnabled: _notificationsEnabled,
      leadReminderSeconds: _leadReminderSeconds,
      overlayAlertsEnabled: false,
      dndControlEnabled: false,
      priorityCallsEnabled: false,
      keepAwakeEnabled: false,
      focusGuardEnabled: _focusGuardEnabled,
      backgroundAudioEnabled: false,
      homeWidgetsEnabled: _homeWidgetsEnabled,
      useDeviceLocation: _useDeviceLocation,
      qiyamPreference: _qiyamPreference,
    );

    await _saveAdhkarReminderPreferences();
    await _controller.save(settings);

    _notificationSyncWarning = null;
    final notificationsReady = await _syncPrayerNotifications(settings);

    await widget.services.analyticsService.trackEvent(
      'prayer_settings_saved',
      parameters: {
        'notifications_enabled': _notificationsEnabled ? 1 : 0,
        'lead_reminder_seconds': _leadReminderSeconds,
      },
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notificationSyncWarning ??
              (notificationsReady
                  ? 'تم حفظ إعدادات صلاتي وجدولة التنبيهات'
                  : 'تم حفظ إعدادات صلاتي'),
        ),
      ),
    );
    await _showWidgetReminderIfNeeded();
  }

  Future<void> _showWidgetReminderIfNeeded() async {
    if (widget.preferences.widgetAddReminderShown) {
      return;
    }

    await widget.preferences.setWidgetAddReminderShown(true);
    await widget.services.analyticsService.trackEvent('widget_reminder_shown');

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.widgets_rounded,
                size: 42,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'جرّب ويدجت صلاتي',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'بعد حفظ مواقيت الصلاة، أضف ويدجت الصلاة التالية أو مواقيت اليوم من الشاشة الرئيسية لتحصل على خط كبير وألوان تنبيه قريبة من تجربة iPhone.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('فهمت'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAdhkarReminderPreferences() async {
    await widget.preferences.setMorningAdhkarReminderEnabled(
      _morningAdhkarReminderEnabled,
    );
    await widget.preferences.setMorningAdhkarReminderMinutes(
      _morningAdhkarReminderMinutes,
    );

    await widget.preferences.setEveningAdhkarReminderEnabled(
      _eveningAdhkarReminderEnabled,
    );
    await widget.preferences.setEveningAdhkarReminderMinutes(
      _eveningAdhkarReminderMinutes,
    );

    await widget.preferences.setFridayKahfReminderEnabled(
      _fridayKahfReminderEnabled,
    );
    await widget.preferences.setFridayKahfReminderMinutes(
      _fridayKahfReminderMinutes,
    );

    await widget.preferences.setRequireKahfBeforeDailyWird(
      _requireKahfBeforeDailyWird,
    );
    await widget.preferences.setAdhkarSurahAutomationEnabled(
      _adhkarSurahAutomationEnabled,
    );
    await widget.preferences.setAdhkarSurahAutomationFirst(
      _adhkarSurahAutomationFirst,
    );
    await widget.preferences.setAdhkarAutomationMode(_adhkarAutomationMode);

    await widget.preferences.setMulkReminderEnabled(_mulkReminderEnabled);
    await widget.preferences.setMulkReminderMinutes(_mulkReminderMinutes);
    await widget.preferences.setSelectedAdhanKey(_selectedAdhanKey);
    await widget.preferences.setSelectedFajrAdhanKey(_selectedFajrAdhanKey);
    await widget.preferences.setSelectedMorningAzkarSoundKey(
      _selectedMorningAzkarSoundKey,
    );
    await widget.preferences.setSelectedEveningAzkarSoundKey(
      _selectedEveningAzkarSoundKey,
    );
  }

  Future<bool> _syncPrayerNotifications(PrayerSettings settings) async {
    final hasContentReminders =
        _morningAdhkarReminderEnabled ||
        _eveningAdhkarReminderEnabled ||
        _fridayKahfReminderEnabled ||
        _mulkReminderEnabled;

    if (!settings.notificationsEnabled && !hasContentReminders) {
      await widget.services.notificationService.cancelPrayerNotifications();
      return false;
    }

    final granted = await widget.services.notificationService
        .requestPermissions();

    if (!granted) {
      _notificationSyncWarning =
          'تم الحفظ، لكن صلاحية الإشعارات غير مفعلة. افتح إعدادات الإشعارات من نفس الشاشة.';
      return false;
    }

    try {
      await widget.services.notificationService.cancelPrayerNotifications();

      if (settings.notificationsEnabled) {
        final config = await widget.services.appConfigRepository
            .loadOperationalConfig();

        final prayerTimesService = LocalPrayerTimesService(
          operationalConfig: config,
        );

        final dates = [
          DateTime.now(),
          DateTime.now().add(const Duration(days: 1)),
        ];

        const prayerKeys = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};

        for (final date in dates) {
          final times = await prayerTimesService.getPrayerTimesForDate(
            settings: settings,
            date: date,
          );

          for (var index = 0; index < times.entries.length; index++) {
            final entry = times.entries[index];

            if (!prayerKeys.contains(entry.key)) {
              continue;
            }

            if (!widget.preferences.isAdhanEnabledForPrayer(entry.key)) {
              continue;
            }

            final id =
                date.year * 100000 + date.month * 1000 + date.day * 10 + index;

            await widget.services.notificationService.schedulePrayerReminder(
              id: id,
              title: 'حان وقت ${entry.label}',
              body: 'الأذان الآن حسب مواقيت صلاتي المحفوظة.',
              scheduledAt: entry.time,
              androidSound: _androidSoundForPrayer(entry.key),
            );
          }
        }
      }

      await _scheduleAdhkarNotifications();
      return true;
    } catch (_) {
      _notificationSyncWarning =
          'تم الحفظ، لكن تعذرت جدولة بعض التنبيهات. راجع صلاحيات الإشعارات والمنبهات ثم احفظ مرة أخرى.';
      return false;
    }
  }

  Future<void> _scheduleAdhkarNotifications() async {
    final now = DateTime.now();

    if (_morningAdhkarReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _morningAdhkarNotificationId,
        title: 'أذكار الصباح',
        body: 'ابدأ ورد الصباح بهدوء وذكر.',
        scheduledAt: _nextDailyTime(_morningAdhkarReminderMinutes, now),
        androidSound: _rawAzkarSound(_selectedMorningAzkarSoundKey),
      );
    }

    if (_eveningAdhkarReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _eveningAdhkarNotificationId,
        title: 'أذكار المساء',
        body: 'وقت ورد المساء وطمأنينة نهاية اليوم.',
        scheduledAt: _nextDailyTime(_eveningAdhkarReminderMinutes, now),
        androidSound: _rawAzkarSound(_selectedEveningAzkarSoundKey),
      );
    }

    if (_fridayKahfReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _fridayKahfNotificationId,
        title: 'سورة الكهف',
        body: 'تنبيه الجمعة لقراءة سورة الكهف.',
        scheduledAt: _nextWeekdayTime(
          DateTime.friday,
          _fridayKahfReminderMinutes,
          now,
        ),
        payload: 'quran_surah:18',
        useAlarmAudio: false,
      );
    }

    if (_mulkReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _mulkNotificationId,
        title: 'سورة الملك',
        body: 'وقت قراءة سورة الملك حسب اختيارك.',
        scheduledAt: _nextDailyTime(_mulkReminderMinutes, now),
        payload: 'quran_surah:67',
        useAlarmAudio: false,
      );
    }
  }

  DateTime _nextDailyTime(int minutesFromMidnight, DateTime now) {
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );

    if (target.isAfter(now)) {
      return target;
    }

    return target.add(const Duration(days: 1));
  }

  DateTime _nextWeekdayTime(
    int weekday,
    int minutesFromMidnight,
    DateTime now,
  ) {
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );

    final daysUntil = (weekday - now.weekday) % DateTime.daysPerWeek;
    target = target.add(Duration(days: daysUntil));

    if (target.isAfter(now)) {
      return target;
    }

    return target.add(const Duration(days: 7));
  }

  Future<void> _testNotification(String kind) async {
    final granted = await widget.services.notificationService
        .requestPermissions();

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('افتح صلاحية الإشعارات أولًا للاختبار.'),
          ),
        );
      }
      return;
    }

    final title = switch (kind) {
      'adhan' => 'اختبار الأذان',
      'morning' => 'اختبار أذكار الصباح',
      'evening' => 'اختبار أذكار المساء',
      _ => 'اختبار قيام الليل',
    };

    final body = switch (kind) {
      'adhan' => 'هذا تنبيه تجريبي لقرب وقت الصلاة.',
      'morning' => 'هذا تنبيه تجريبي لأذكار الصباح.',
      'evening' => 'هذا تنبيه تجريبي لأذكار المساء.',
      _ => 'هذا تنبيه تجريبي لقيام الليل.',
    };

    final id = switch (kind) {
      'adhan' => 990001,
      'morning' => 990002,
      'evening' => 990003,
      _ => 990004,
    };

    await widget.services.notificationService.schedulePrayerReminder(
      id: id,
      title: title,
      body: body,
      scheduledAt: DateTime.now().add(const Duration(seconds: 5)),
      androidSound: _androidSoundForTest(kind),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم جدولة اختبار بعد 5 ثواني.')),
    );
  }

  Future<void> _testWidgetRefresh(String kind) async {
    final refreshed = switch (kind) {
      'ayah' => await SalatiWidgetsService.refreshRandomAyahWidget(),
      'zikr' => await SalatiWidgetsService.refreshRandomZikrWidget(),
      'next_prayer' => await SalatiWidgetsService.hasNextPrayerWidget(),
      _ => false,
    };

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refreshed
              ? 'Widget refresh request sent.'
              : kind == 'next_prayer'
              ? 'أضف ويدجت الصلاة إلى الشاشة الرئيسية أولًا.'
              : 'Widget refresh needs manual verification on Android.',
        ),
      ),
    );
  }

  String _androidSoundForPrayer(String prayerKey) {
    if (prayerKey == 'fajr') {
      return _rawAdhanSound(_selectedFajrAdhanKey);
    }
    return _rawAdhanSound(_selectedAdhanKey);
  }

  String _androidSoundForTest(String kind) {
    switch (kind) {
      case 'adhan':
        return _androidSoundForPrayer('dhuhr');
      case 'morning':
        return _rawAzkarSound(_selectedMorningAzkarSoundKey);
      case 'evening':
      case 'qiyam':
      default:
        return _rawAzkarSound(_selectedEveningAzkarSoundKey);
    }
  }

  String _rawAzkarSound(String key) {
    switch (key.trim().toLowerCase()) {
      case 'azkar_morning':
      case 'morning_default':
        return 'azkar_morning';
      case 'azkar_evening':
      case 'evening_default':
      default:
        return 'azkar_evening';
    }
  }

  String _rawAdhanSound(String key) {
    switch (key.trim().toLowerCase()) {
      case 'fajr_default_adhan':
      case 'adhan_fajr_default':
        return 'adhan_fajr_default';
      case 'default_adhan':
      case 'adhan_default':
      default:
        return 'adhan_default';
    }
  }

  String _normalizeCalculationMethod(String? value) {
    final normalized = value?.trim();

    switch (normalized) {
      case 'egyptian':
      case 'umm_al_qura':
      case 'muslim_world_league':
      case 'karachi':
      case 'north_america':
        return normalized!;

      case 'الهيئة المصرية العامة للمساحة':
      case 'Egyptian General Authority of Survey':
        return 'egyptian';

      case 'أم القرى':
        return 'umm_al_qura';

      case 'رابطة العالم الإسلامي':
        return 'muslim_world_league';

      case 'كراتشي':
        return 'karachi';

      case 'أمريكا الشمالية':
        return 'north_america';

      default:
        return 'egyptian';
    }
  }

  String _timeLabel(int minutesFromMidnight) {
    final hour = (minutesFromMidnight ~/ 60).toString().padLeft(2, '0');
    final minute = (minutesFromMidnight % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickReminderMinutes({
    required int currentValue,
    required ValueChanged<int> onChanged,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentValue ~/ 60,
        minute: currentValue % 60,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    onChanged((selected.hour * 60) + selected.minute);
  }

  Future<void> _updateCalculationMethod(String value) async {
    final currentSettings = _controller.settings;
    if (currentSettings == null) {
      return;
    }

    final safeValue = _normalizeCalculationMethod(value);

    await _controller.save(
      currentSettings.copyWith(calculationMethod: safeValue),
    );

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث طريقة حساب المواقيت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('إعدادات صلاتي')),
        body: const LoadingStateView(label: 'جاري تحميل الإعدادات'),
      );
    }

    final settings = _controller.settings;
    final calculationMethod = _normalizeCalculationMethod(
      settings?.calculationMethod,
    );
    final session = widget.services.authService.currentSession;
    final entitlementStream = session == null
        ? Stream<List<FeatureEntitlement>>.value(const [])
        : widget.services.entitlementRepository.watchUserEntitlements(
            session.uid,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات صلاتي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الموقع والحساب',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يتم استخدام موقعك الحالي لحساب مواقيت الصلاة. يمكنك تحديث الموقع عند تغيير مكانك.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _refreshDeviceLocationIfNeeded(force: true),
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('تحديث موقعي الآن'),
                  ),
                  if (settings?.locationLabel?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'الموقع الحالي: ${settings!.locationLabel!}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: calculationMethod,
                    decoration: const InputDecoration(
                      labelText: 'طريقة حساب مواقيت الصلاة',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'egyptian',
                        child: Text('الهيئة المصرية العامة للمساحة'),
                      ),
                      DropdownMenuItem(
                        value: 'umm_al_qura',
                        child: Text('أم القرى'),
                      ),
                      DropdownMenuItem(
                        value: 'muslim_world_league',
                        child: Text('رابطة العالم الإسلامي'),
                      ),
                      DropdownMenuItem(value: 'karachi', child: Text('كراتشي')),
                      DropdownMenuItem(
                        value: 'north_america',
                        child: Text('أمريكا الشمالية'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _updateCalculationMethod(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _QiyamPreferenceCard(
            value: _qiyamPreference,
            onChanged: (value) {
              setState(() => _qiyamPreference = value);
            },
          ),
          const SizedBox(height: 12),
          _PrayerRuntimePermissionsCard(
            notificationsEnabled: _notificationsEnabled,
            leadReminderSeconds: _leadReminderSeconds,
            focusGuardEnabled: _focusGuardEnabled,
            onNotificationsChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
            onLeadReminderChanged: (value) {
              setState(() => _leadReminderSeconds = value);
            },
            onFocusGuardChanged: (value) {
              setState(() => _focusGuardEnabled = value);
            },
            onOpenNotificationSettings:
                _permissionSettings.openNotificationSettings,
            onOpenAppSettings: _permissionSettings.openAppSettings,
            onOpenBatterySettings:
                _permissionSettings.openBatteryOptimizationSettings,
            onTestAdhan: () => _testNotification('adhan'),
            onTestMorningAdhkar: () => _testNotification('morning'),
            onTestEveningAdhkar: () => _testNotification('evening'),
            onTestQiyam: () => _testNotification('qiyam'),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<FeatureEntitlement>>(
            stream: entitlementStream,
            builder: (context, snapshot) {
              return _PrayerSoundSettingsCard(
                selectedAdhanKey: _selectedAdhanKey,
                selectedFajrAdhanKey: _selectedFajrAdhanKey,
                selectedMorningAzkarSoundKey: _selectedMorningAzkarSoundKey,
                selectedEveningAzkarSoundKey: _selectedEveningAzkarSoundKey,
                purchasedSounds: snapshot.data ?? const [],
                onAdhanChanged: (value) {
                  setState(() => _selectedAdhanKey = value);
                },
                onFajrAdhanChanged: (value) {
                  setState(() => _selectedFajrAdhanKey = value);
                },
                onMorningAzkarChanged: (value) {
                  setState(() => _selectedMorningAzkarSoundKey = value);
                },
                onEveningAzkarChanged: (value) {
                  setState(() => _selectedEveningAzkarSoundKey = value);
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _AdhkarReminderSettingsCard(
            morningEnabled: _morningAdhkarReminderEnabled,
            morningTimeLabel: _timeLabel(_morningAdhkarReminderMinutes),
            eveningEnabled: _eveningAdhkarReminderEnabled,
            eveningTimeLabel: _timeLabel(_eveningAdhkarReminderMinutes),
            fridayKahfEnabled: _fridayKahfReminderEnabled,
            fridayKahfTimeLabel: _timeLabel(_fridayKahfReminderMinutes),
            requireKahfBeforeDailyWird: _requireKahfBeforeDailyWird,
            automationEnabled: _adhkarSurahAutomationEnabled,
            automationFirst: _adhkarSurahAutomationFirst,
            automationMode: _adhkarAutomationMode,
            mulkEnabled: _mulkReminderEnabled,
            mulkTimeLabel: _timeLabel(_mulkReminderMinutes),
            onMorningEnabledChanged: (value) {
              setState(() => _morningAdhkarReminderEnabled = value);
            },
            onMorningTimePressed: () => _pickReminderMinutes(
              currentValue: _morningAdhkarReminderMinutes,
              onChanged: (value) {
                setState(() => _morningAdhkarReminderMinutes = value);
              },
            ),
            onEveningEnabledChanged: (value) {
              setState(() => _eveningAdhkarReminderEnabled = value);
            },
            onEveningTimePressed: () => _pickReminderMinutes(
              currentValue: _eveningAdhkarReminderMinutes,
              onChanged: (value) {
                setState(() => _eveningAdhkarReminderMinutes = value);
              },
            ),
            onFridayKahfEnabledChanged: (value) {
              setState(() => _fridayKahfReminderEnabled = value);
            },
            onFridayKahfTimePressed: () => _pickReminderMinutes(
              currentValue: _fridayKahfReminderMinutes,
              onChanged: (value) {
                setState(() => _fridayKahfReminderMinutes = value);
              },
            ),
            onRequireKahfChanged: (value) {
              setState(() => _requireKahfBeforeDailyWird = value);
            },
            onAutomationEnabledChanged: (value) {
              setState(() => _adhkarSurahAutomationEnabled = value);
            },
            onAutomationFirstChanged: (value) {
              setState(() => _adhkarSurahAutomationFirst = value);
            },
            onAutomationModeChanged: (value) {
              setState(() => _adhkarAutomationMode = value);
            },
            onMulkEnabledChanged: (value) {
              setState(() => _mulkReminderEnabled = value);
            },
            onMulkTimePressed: () => _pickReminderMinutes(
              currentValue: _mulkReminderMinutes,
              onChanged: (value) {
                setState(() => _mulkReminderMinutes = value);
              },
            ),
          ),
          const SizedBox(height: 12),
          _HomeWidgetsSettingsCard(
            enabled: _homeWidgetsEnabled,
            onChanged: (value) {
              setState(() => _homeWidgetsEnabled = value);
            },
            onRefreshAyah: () => _testWidgetRefresh('ayah'),
            onRefreshZikr: () => _testWidgetRefresh('zikr'),
            onRefreshNextPrayer: () => _testWidgetRefresh('next_prayer'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _controller.isSaving ? null : _save,
            child: Text(
              _controller.isSaving ? 'جاري الحفظ...' : 'حفظ التغييرات',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerSoundSettingsCard extends StatelessWidget {
  const _PrayerSoundSettingsCard({
    required this.selectedAdhanKey,
    required this.selectedFajrAdhanKey,
    required this.selectedMorningAzkarSoundKey,
    required this.selectedEveningAzkarSoundKey,
    required this.purchasedSounds,
    required this.onAdhanChanged,
    required this.onFajrAdhanChanged,
    required this.onMorningAzkarChanged,
    required this.onEveningAzkarChanged,
  });

  final String selectedAdhanKey;
  final String selectedFajrAdhanKey;
  final String selectedMorningAzkarSoundKey;
  final String selectedEveningAzkarSoundKey;
  final List<FeatureEntitlement> purchasedSounds;
  final ValueChanged<String> onAdhanChanged;
  final ValueChanged<String> onFajrAdhanChanged;
  final ValueChanged<String> onMorningAzkarChanged;
  final ValueChanged<String> onEveningAzkarChanged;

  static const _adhanOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'default_adhan', child: Text('الأذان الافتراضي')),
  ];

  static const _fajrOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(
      value: 'fajr_default_adhan',
      child: Text('أذان الفجر الافتراضي'),
    ),
  ];

  static const _morningOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'azkar_morning', child: Text('أذكار الصباح')),
  ];

  static const _eveningOptions = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'azkar_evening', child: Text('أذكار المساء')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الأصوات',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اختيار المؤذن وأصوات الأذكار من هنا. الأصوات الإضافية تظهر بعد إضافتها من المتجر وربط ملفها بنفس المفتاح.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _safeDropdownValue(selectedAdhanKey, _adhanOptions),
              decoration: const InputDecoration(labelText: 'مؤذن الصلوات'),
              items: _adhanOptions,
              onChanged: (value) {
                if (value != null) onAdhanChanged(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _safeDropdownValue(
                selectedFajrAdhanKey,
                _fajrOptions,
              ),
              decoration: const InputDecoration(labelText: 'مؤذن الفجر'),
              items: _fajrOptions,
              onChanged: (value) {
                if (value != null) onFajrAdhanChanged(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _safeDropdownValue(
                selectedMorningAzkarSoundKey,
                _morningOptions,
              ),
              decoration: const InputDecoration(labelText: 'صوت أذكار الصباح'),
              items: _morningOptions,
              onChanged: (value) {
                if (value != null) onMorningAzkarChanged(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _safeDropdownValue(
                selectedEveningAzkarSoundKey,
                _eveningOptions,
              ),
              decoration: const InputDecoration(labelText: 'صوت أذكار المساء'),
              items: _eveningOptions,
              onChanged: (value) {
                if (value != null) onEveningAzkarChanged(value);
              },
            ),
            const SizedBox(height: 12),
            _PurchasedSoundsList(entitlements: purchasedSounds),
          ],
        ),
      ),
    );
  }

  static String _safeDropdownValue(
    String value,
    List<DropdownMenuItem<String>> items,
  ) {
    return items.any((item) => item.value == value)
        ? value
        : (items.first.value ?? value);
  }
}

class _PurchasedSoundsList extends StatelessWidget {
  const _PurchasedSoundsList({required this.entitlements});

  final List<FeatureEntitlement> entitlements;

  @override
  Widget build(BuildContext context) {
    final sounds = entitlements
        .where(
          (item) =>
              item.isActive &&
              (item.featureKey.startsWith('adhan:') ||
                  item.assetKind == 'adhan_audio'),
        )
        .toList(growable: false);

    if (sounds.isEmpty) {
      return const Text('Purchased sounds: none');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Purchased sounds',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ...sounds.map(
          (item) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_open_rounded),
            title: Text(item.title ?? item.featureKey),
            subtitle: const Text('Visible from Store. Audio asset pending.'),
          ),
        ),
      ],
    );
  }
}

class _AdhkarReminderSettingsCard extends StatelessWidget {
  const _AdhkarReminderSettingsCard({
    required this.morningEnabled,
    required this.morningTimeLabel,
    required this.eveningEnabled,
    required this.eveningTimeLabel,
    required this.fridayKahfEnabled,
    required this.fridayKahfTimeLabel,
    required this.requireKahfBeforeDailyWird,
    required this.automationEnabled,
    required this.automationFirst,
    required this.automationMode,
    required this.mulkEnabled,
    required this.mulkTimeLabel,
    required this.onMorningEnabledChanged,
    required this.onMorningTimePressed,
    required this.onEveningEnabledChanged,
    required this.onEveningTimePressed,
    required this.onFridayKahfEnabledChanged,
    required this.onFridayKahfTimePressed,
    required this.onRequireKahfChanged,
    required this.onAutomationEnabledChanged,
    required this.onAutomationFirstChanged,
    required this.onAutomationModeChanged,
    required this.onMulkEnabledChanged,
    required this.onMulkTimePressed,
  });

  final bool morningEnabled;
  final String morningTimeLabel;
  final bool eveningEnabled;
  final String eveningTimeLabel;
  final bool fridayKahfEnabled;
  final String fridayKahfTimeLabel;
  final bool requireKahfBeforeDailyWird;
  final bool automationEnabled;
  final String automationFirst;
  final String automationMode;
  final bool mulkEnabled;
  final String mulkTimeLabel;
  final ValueChanged<bool> onMorningEnabledChanged;
  final VoidCallback onMorningTimePressed;
  final ValueChanged<bool> onEveningEnabledChanged;
  final VoidCallback onEveningTimePressed;
  final ValueChanged<bool> onFridayKahfEnabledChanged;
  final VoidCallback onFridayKahfTimePressed;
  final ValueChanged<bool> onRequireKahfChanged;
  final ValueChanged<bool> onAutomationEnabledChanged;
  final ValueChanged<String> onAutomationFirstChanged;
  final ValueChanged<String> onAutomationModeChanged;
  final ValueChanged<bool> onMulkEnabledChanged;
  final VoidCallback onMulkTimePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الأذكار والسور',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: morningEnabled,
              title: const Text('تذكير أذكار الصباح'),
              subtitle: Text('الموعد: $morningTimeLabel'),
              onChanged: onMorningEnabledChanged,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onMorningTimePressed,
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('تغيير موعد الصباح'),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: eveningEnabled,
              title: const Text('تذكير أذكار المساء'),
              subtitle: Text('الموعد: $eveningTimeLabel'),
              onChanged: onEveningEnabledChanged,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onEveningTimePressed,
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('تغيير موعد المساء'),
              ),
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: fridayKahfEnabled,
              title: const Text('تذكير سورة الكهف يوم الجمعة'),
              subtitle: Text('الموعد: $fridayKahfTimeLabel'),
              onChanged: onFridayKahfEnabledChanged,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onFridayKahfTimePressed,
                icon: const Icon(Icons.event_outlined),
                label: const Text('تغيير موعد الكهف'),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: requireKahfBeforeDailyWird,
              title: const Text('الكهف أولًا يوم الجمعة'),
              subtitle: const Text(
                'يفتح قارئ الصفحة أو الآية أو الكلمة على سورة الكهف حتى يتم تسجيل إتمامها.',
              ),
              onChanged: onRequireKahfChanged,
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: automationEnabled,
              title: const Text('Adhkar / Surah automation'),
              subtitle: const Text(
                'Settings only. Runtime automation pending.',
              ),
              onChanged: onAutomationEnabledChanged,
            ),
            DropdownButtonFormField<String>(
              initialValue: automationFirst == 'surah' ? 'surah' : 'adhkar',
              decoration: const InputDecoration(labelText: 'Start with'),
              items: const [
                DropdownMenuItem(value: 'adhkar', child: Text('Adhkar first')),
                DropdownMenuItem(value: 'surah', child: Text('Surah first')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onAutomationFirstChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: automationMode == 'heard' ? 'heard' : 'read',
              decoration: const InputDecoration(labelText: 'Adhkar mode'),
              items: const [
                DropdownMenuItem(value: 'read', child: Text('Read')),
                DropdownMenuItem(value: 'heard', child: Text('Heard')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onAutomationModeChanged(value);
                }
              },
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: mulkEnabled,
              title: const Text('تذكير سورة الملك'),
              subtitle: Text('الموعد: $mulkTimeLabel'),
              onChanged: onMulkEnabledChanged,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onMulkTimePressed,
                icon: const Icon(Icons.nightlight_round),
                label: const Text('تغيير موعد الملك'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWidgetsSettingsCard extends StatelessWidget {
  const _HomeWidgetsSettingsCard({
    required this.enabled,
    required this.onChanged,
    required this.onRefreshAyah,
    required this.onRefreshZikr,
    required this.onRefreshNextPrayer,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRefreshAyah;
  final VoidCallback onRefreshZikr;
  final VoidCallback onRefreshNextPrayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              secondary: Icon(
                Icons.widgets_rounded,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Home widgets'),
              subtitle: const Text(
                'Widget refresh hooks use the existing native service.',
              ),
              onChanged: onChanged,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled ? onRefreshAyah : null,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Test ayah widget'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onRefreshZikr : null,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Test zikr widget'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onRefreshNextPrayer : null,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Test next prayer widget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PermissionStatus { enabled, disabled, manual }

class _PermissionStatusRow extends StatelessWidget {
  const _PermissionStatusRow({
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String label;
  final _PermissionStatus status;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (status) {
      _PermissionStatus.enabled => Icons.check_circle_rounded,
      _PermissionStatus.disabled => Icons.cancel_rounded,
      _PermissionStatus.manual => Icons.help_outline_rounded,
    };
    final color = switch (status) {
      _PermissionStatus.enabled => Colors.green,
      _PermissionStatus.disabled => theme.colorScheme.error,
      _PermissionStatus.manual => theme.colorScheme.tertiary,
    };
    final value = switch (status) {
      _PermissionStatus.enabled => 'Enabled',
      _PermissionStatus.disabled => 'Disabled',
      _PermissionStatus.manual => 'Needs manual verification',
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => onTap(),
    );
  }
}

class _PrayerRuntimePermissionsCard extends StatelessWidget {
  const _PrayerRuntimePermissionsCard({
    required this.notificationsEnabled,
    required this.leadReminderSeconds,
    required this.focusGuardEnabled,
    required this.onNotificationsChanged,
    required this.onLeadReminderChanged,
    required this.onFocusGuardChanged,
    required this.onOpenNotificationSettings,
    required this.onOpenAppSettings,
    required this.onOpenBatterySettings,
    required this.onTestAdhan,
    required this.onTestMorningAdhkar,
    required this.onTestEveningAdhkar,
    required this.onTestQiyam,
  });

  final bool notificationsEnabled;
  final int leadReminderSeconds;
  final bool focusGuardEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<int> onLeadReminderChanged;
  final ValueChanged<bool> onFocusGuardChanged;
  final Future<void> Function() onOpenNotificationSettings;
  final Future<void> Function() onOpenAppSettings;
  final Future<void> Function() onOpenBatterySettings;
  final VoidCallback onTestAdhan;
  final VoidCallback onTestMorningAdhkar;
  final VoidCallback onTestEveningAdhkar;
  final VoidCallback onTestQiyam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'صلاحية الإشعارات',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            _PermissionStatusRow(
              label: 'Notifications',
              status: notificationsEnabled
                  ? _PermissionStatus.enabled
                  : _PermissionStatus.disabled,
              onTap: onOpenNotificationSettings,
            ),
            _PermissionStatusRow(
              label: 'Battery / background work',
              status: _PermissionStatus.manual,
              onTap: onOpenBatterySettings,
            ),
            _PermissionStatusRow(
              label: 'Lock screen',
              status: _PermissionStatus.manual,
              onTap: onOpenAppSettings,
            ),
            _PermissionStatusRow(
              label: 'Auto-start',
              status: _PermissionStatus.manual,
              onTap: onOpenAppSettings,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: notificationsEnabled,
              title: const Text('تفعيل الإشعارات'),
              subtitle: const Text(
                'تنبيهات الصلاة والأذكار وسورة الكهف والملك.',
              ),
              onChanged: onNotificationsChanged,
            ),
            DropdownButtonFormField<int>(
              initialValue: leadReminderSeconds,
              decoration: const InputDecoration(
                labelText: 'التنبيه قبل الصلاة',
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 ثانية')),
                DropdownMenuItem(value: 60, child: Text('دقيقة')),
                DropdownMenuItem(value: 300, child: Text('5 دقائق')),
                DropdownMenuItem(value: 600, child: Text('10 دقائق')),
                DropdownMenuItem(value: 900, child: Text('15 دقيقة')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onLeadReminderChanged(value);
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: focusGuardEnabled,
              title: const Text('قفل اللمس قبل الصلاة'),
              subtitle: const Text(
                'يظهر قفل شاشة داخل التطبيق قبل الصلاة حسب وقت التنبيه، ويُلغى بالضغط 5 مرات.',
              ),
              onChanged: onFocusGuardChanged,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenNotificationSettings,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('فتح صلاحية الإشعارات'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenAppSettings,
                  icon: const Icon(Icons.settings_applications_outlined),
                  label: const Text('إعدادات التطبيق'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenBatterySettings,
                  icon: const Icon(Icons.battery_saver_outlined),
                  label: const Text('توفير البطارية'),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onTestAdhan,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('اختبار الأذان'),
                ),
                OutlinedButton.icon(
                  onPressed: onTestMorningAdhkar,
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: const Text('اختبار الصباح'),
                ),
                OutlinedButton.icon(
                  onPressed: onTestEveningAdhkar,
                  icon: const Icon(Icons.nightlight_outlined),
                  label: const Text('اختبار المساء'),
                ),
                OutlinedButton.icon(
                  onPressed: onTestQiyam,
                  icon: const Icon(Icons.bedtime_outlined),
                  label: const Text('اختبار القيام'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QiyamPreferenceCard extends StatelessWidget {
  const _QiyamPreferenceCard({required this.value, required this.onChanged});

  final QiyamPreference value;
  final ValueChanged<QiyamPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const prayerLabels = [
      'الفجر',
      'الشروق',
      'الظهر',
      'العصر',
      'المغرب',
      'العشاء',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قيام الليل',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prayerLabels
                  .map((label) => Chip(label: Text(label)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<QiyamPreference>(
              initialValue: value,
              decoration: const InputDecoration(
                labelText: 'وقت قيام الليل المفضل',
              ),
              items: QiyamPreference.values
                  .map(
                    (item) => DropdownMenuItem<QiyamPreference>(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (nextValue) {
                if (nextValue != null) {
                  onChanged(nextValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
