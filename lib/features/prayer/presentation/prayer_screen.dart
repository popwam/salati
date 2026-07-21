import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/operational_config.dart';
import '../../../core/models/points_config.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/points_award_service.dart';
import '../../../core/services/salati_widgets_service.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/info_card.dart';
import '../data/prayer_settings_repository.dart';
import '../models/daily_prayer_times.dart';
import '../models/prayer_guide.dart';
import '../models/prayer_reflection_entry.dart';
import '../models/prayer_reflection_prompt.dart';
import '../models/prayer_settings.dart';
import '../models/prayer_time_info.dart';
import '../services/device_location_service.dart';
import '../services/local_prayer_times_service.dart';
import '../services/prayer_experience_service.dart';
import 'daily_results_screen.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({
    super.key,
    required this.repository,
    required this.preferences,
    required this.services,
  });

  final PrayerSettingsRepository repository;
  final AppPreferences preferences;
  final AppServices services;

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

enum _PrayerCheckState { prayed, prayedWithNawafil, missed }

enum _PrayerSegment { before, fard, after }

enum _PrayerMomentState {
  prayed,
  prayedWithNawafil,
  missed,
  pending,
  upcoming,
  informational,
}

enum _PrayerUrgencyLevel { calm, soon, urgent }

class _RemoteDashboardConfig {
  const _RemoteDashboardConfig({
    required this.homeCardOrder,
    required this.hiddenHomeSections,
    required this.globalMessage,
    required this.primaryColorHex,
    required this.pointsRules,
  });

  final List<String> homeCardOrder;
  final Set<String> hiddenHomeSections;
  final String globalMessage;
  final String primaryColorHex;
  final PointsRulesConfig pointsRules;

  static const fallback = _RemoteDashboardConfig(
    homeCardOrder: ['next_prayer', 'prayer_times'],
    hiddenHomeSections: <String>{},
    globalMessage: '',
    primaryColorHex: '#1F9D62',
    pointsRules: PointsRulesConfig.defaults,
  );

  factory _RemoteDashboardConfig.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final order = _stringList(map['homeCardOrder']);
    return _RemoteDashboardConfig(
      homeCardOrder: order.isEmpty ? fallback.homeCardOrder : order,
      hiddenHomeSections: _stringList(map['hiddenHomeSections']).toSet(),
      globalMessage: _stringValue(map['globalMessage']) ?? '',
      primaryColorHex:
          _stringValue(map['primaryColorHex']) ?? fallback.primaryColorHex,
      pointsRules: PointsRulesConfig.fromMap(
        map['pointsRules'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class _PrayerUrgency {
  const _PrayerUrgency({
    required this.level,
    required this.label,
    required this.accent,
    required this.background,
    required this.foreground,
  });

  final _PrayerUrgencyLevel level;
  final String label;
  final Color accent;
  final Color background;
  final Color foreground;
}

class _PrayerOverviewSummary {
  const _PrayerOverviewSummary({
    required this.score,
    required this.completedCount,
    required this.missedCount,
    required this.pendingCount,
  });

  final double score;
  final int completedCount;
  final int missedCount;
  final int pendingCount;
}

class _PrayerScreenState extends State<PrayerScreen> {
  static const _experienceService = PrayerExperienceService();
  static const _obligatoryPrayerKeys = <String>{
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  };
  static const _morningAdhkarNotificationId = 920001;
  static const _eveningAdhkarNotificationId = 920002;
  static const _fridayKahfNotificationId = 920003;
  static const _mulkNotificationId = 920004;
  static const _touchLockRequiredTaps = 5;
  static const double _pointsPending = -0.25;

  late final PointsAwardService _pointsAwardService;
  PrayerSettings? _settings;
  DailyPrayerTimes? _times;
  DailyPrayerTimes? _displayTimes;
  DailyPrayerTimes? _nextDayTimes;
  OperationalConfig? _operationalConfig;
  _RemoteDashboardConfig _remoteDashboardConfig =
      _RemoteDashboardConfig.fallback;
  PrayerTimeInfo? _info;
  Timer? _ticker;
  bool _isLoading = true;
  String? _error;
  bool _showingNextDayPrayers = false;
  Set<String> _completedPrayerKeys = <String>{};
  Set<String> _missedPrayerKeys = <String>{};
  final Map<String, PrayerReflectionEntry> _savedReflections =
      <String, PrayerReflectionEntry>{};
  int _heroTapCount = 0;
  DateTime? _lastHeroTapAt;
  int _touchLockTapCount = 0;
  String? _dismissedTouchLockPrayerKey;
  DateTime? _lastHomeWidgetSyncAt;
  DateTime? _trustedServerAnchor;
  Stopwatch? _trustedServerStopwatch;
  bool _serverClockAvailable = false;

  void _logScore(String message) {
    if (kDebugMode) {
      debugPrint('[Score] $message');
    }
  }

  void _logReflection(String message) {
    if (kDebugMode) {
      debugPrint('[Reflection] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _pointsAwardService = PointsAwardService(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime _trustedNow() {
    final anchor = _trustedServerAnchor;
    final stopwatch = _trustedServerStopwatch;
    if (anchor != null && stopwatch != null) {
      return anchor.add(stopwatch.elapsed);
    }
    return DateTime.now();
  }

  Future<DateTime> _loadTrustedNow() async {
    final fallback = _trustedNow();
    if (!widget.services.firebaseConfigured) {
      _serverClockAvailable = false;
      return fallback;
    }

    final session = widget.services.authService.currentSession;
    if (session == null) {
      _serverClockAvailable = false;
      return fallback;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(session.uid);
      await ref.set({
        'clientClockProbeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final snapshot = await ref.get(const GetOptions(source: Source.server));
      final value = snapshot.data()?['clientClockProbeAt'];
      if (value is Timestamp) {
        _trustedServerAnchor = value.toDate();
        _trustedServerStopwatch = Stopwatch()..start();
        _serverClockAvailable = true;
        return _trustedNow();
      }
    } catch (error) {
      debugPrint('[ServerClock] failed to load trusted time: $error');
    }

    _serverClockAvailable = false;
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await widget.services.appConfigRepository
          .loadOperationalConfig();
      final settings = await widget.repository.load();
      final effectiveSettings = _applyOperationalDefaults(settings, config);
      final prayerTimesService = LocalPrayerTimesService(
        operationalConfig: config,
      );
      final now = await _loadTrustedNow();
      final times = await prayerTimesService.getPrayerTimesForDate(
        settings: effectiveSettings,
        date: now,
      );
      final nextDayTimes = await prayerTimesService.getPrayerTimesForDate(
        settings: effectiveSettings,
        date: now.add(const Duration(days: 1)),
      );
      final showingNextDayPrayers = _isAfterIsha(times, now);
      final displayTimes = showingNextDayPrayers ? nextDayTimes : times;
      final info = _experienceService.buildPrayerTimeInfo(
        dailyTimes: displayTimes,
        qiyamPreference: effectiveSettings.qiyamPreference,
        now: now,
      );
      final remoteDashboardConfig = await _loadRemoteDashboardConfig();

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = effectiveSettings;
        _times = times;
        _displayTimes = displayTimes;
        _nextDayTimes = nextDayTimes;
        _operationalConfig = config;
        _remoteDashboardConfig = remoteDashboardConfig;
        _info = info;
        _completedPrayerKeys = widget.preferences.completedPrayerKeysForDate(
          displayTimes.entries.first.time,
        );
        _missedPrayerKeys = widget.preferences.missedPrayerKeysForDate(
          displayTimes.entries.first.time,
        );
        _showingNextDayPrayers = showingNextDayPrayers;
        _isLoading = false;
      });
      await _autoMarkUnregisteredPassedPrayersAsMissed(displayTimes);
      await _syncHomeWidgets(force: true);
      _startTicker();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = mapAppErrorToArabic(error);
        _isLoading = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshLiveInfo();
    });
  }

  void _refreshLiveInfo() {
    final settings = _settings;
    final todayTimes = _times;
    final currentDisplayTimes = _displayTimes;
    if (!mounted ||
        settings == null ||
        todayTimes == null ||
        currentDisplayTimes == null) {
      return;
    }

    final now = _trustedNow();
    final shouldShowNextDay = _isAfterIsha(todayTimes, now);
    if (shouldShowNextDay != _showingNextDayPrayers) {
      _load();
      return;
    }

    final nextInfo = _experienceService.buildPrayerTimeInfo(
      dailyTimes: currentDisplayTimes,
      qiyamPreference: settings.qiyamPreference,
      now: now,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _info = nextInfo;
    });
    unawaited(_syncHomeWidgets());
  }

  PrayerSettings _applyOperationalDefaults(
    PrayerSettings settings,
    OperationalConfig config,
  ) {
    return settings.copyWith(
      country: settings.country.isEmpty
          ? config.prayerProvider.defaultCountry
          : settings.country,
      city: settings.city.isEmpty
          ? config.prayerProvider.defaultCity
          : settings.city,
      calculationMethod: settings.calculationMethod.isEmpty
          ? config.prayerProvider.calculationMethod
          : settings.calculationMethod,
      latitude: settings.latitude ?? config.prayerProvider.defaultLatitude,
      longitude: settings.longitude ?? config.prayerProvider.defaultLongitude,
    );
  }

  Future<_RemoteDashboardConfig> _loadRemoteDashboardConfig() async {
    if (!widget.services.firebaseConfigured) {
      return _RemoteDashboardConfig.fallback;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('remote_app_config')
          .doc('published')
          .get();
      return _RemoteDashboardConfig.fromMap(snapshot.data());
    } catch (error) {
      debugPrint('[DashboardConfig] failed to load remote config: $error');
      return _RemoteDashboardConfig.fallback;
    }
  }

  double _currentUserPoints() {
    return widget.preferences
        .prayerScoreSummaryForRule(_freePointsRule())
        .totalScore
        .toDouble();
  }

  PointsRulesConfig _effectivePointsRules() {
    return _remoteDashboardConfig.pointsRules;
  }

  PlanPointsRule _freePointsRule() {
    return _effectivePointsRules().ruleForPlan('free');
  }

  Future<void> _refreshDeviceLocationAndReload() async {
    final settings = _settings;
    if (settings == null) {
      await _load();
      return;
    }

    if (!settings.useDeviceLocation) {
      await _load();
      return;
    }

    try {
      final service = const DeviceLocationService();
      final position = await service.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحديث الموقع الحالي.')),
          );
        }
        await _load();
        return;
      }

      final label = await service.getLocationLabelFromPosition(position);
      final updatedSettings = settings.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        locationLabel: label,
        useDeviceLocation: true,
        lastLocationUpdatedAt: DateTime.now(),
      );
      await widget.repository.save(updatedSettings);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديث الموقع: $label')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الموقع: $error')));
      }
    }

    await _load();
  }

  Future<List<FeatureEntitlement>> _loadWidgetEntitlements() async {
    final session = widget.services.authService.currentSession;
    if (!widget.services.firebaseConfigured || session == null) {
      return const <FeatureEntitlement>[];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(session.uid)
          .collection('entitlements')
          .get();
      return snapshot.docs
          .map(
            (doc) => FeatureEntitlement.fromMap({
              'featureKey': doc.id,
              ...doc.data(),
            }),
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('[WidgetsEntitlements] failed to load: $error');
      return const <FeatureEntitlement>[];
    }
  }

  bool _canUseWidget(String widgetKey, List<FeatureEntitlement> entitlements) {
    const freeWidgets = <String>{
      'next_prayer_widget',
      'next_prayer',
      'calendar_widget',
      'calendar',
      'date_widget',
    };
    if (freeWidgets.contains(widgetKey)) {
      return true;
    }
    return entitlements.any((entitlement) {
      if (!entitlement.isActive) {
        return false;
      }
      final metadataWidgetKey = entitlement.metadata['widgetKey'];
      final keys = <String>{
        entitlement.featureKey,
        entitlement.unlockKey ?? '',
        if (metadataWidgetKey is String) metadataWidgetKey,
        'widget:$widgetKey',
      };
      return keys.contains(widgetKey) ||
          keys.contains('widget:$widgetKey') ||
          (entitlement.unlockKey?.contains(widgetKey) ?? false);
    });
  }

  Future<void> _syncCurrentPointsToFirestore() async {
    final session = widget.services.authService.currentSession;

    if (session == null) {
      _logScore('skip firestore sync reason=missing-session');
      return;
    }

    final rule = _freePointsRule();
    final date =
        (_displayTimes?.entries.first.time ?? _times?.entries.first.time) ??
        _trustedNow();
    final points = widget.preferences
        .prayerScoreSummaryForRule(rule)
        .totalScore
        .toDouble();
    final dailyScore = widget.preferences
        .dailyPrayerScoreSummaryForRule(date, rule)
        .totalScore;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(session.uid)
          .set({
            'prayerScore': points,
            'dailyPrayerScore': dailyScore,
            'pointsUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _logScore('synced firestore prayerScore=$points uid=${session.uid}');
    } catch (error) {
      _logScore('failed firestore points sync error=$error');
    }
  }

  Future<void> _syncHomeWidgets({bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!widget.preferences.homeWidgetsEnabled) {
      return;
    }

    final times = _displayTimes ?? _times;
    final info = _info;
    if (times == null || info == null || times.entries.isEmpty) {
      return;
    }

    final now = _trustedNow();
    final lastSync = _lastHomeWidgetSyncAt;
    if (!force &&
        lastSync != null &&
        now.difference(lastSync) < const Duration(minutes: 1)) {
      return;
    }
    _lastHomeWidgetSyncAt = now;

    final entriesByKey = {for (final entry in times.entries) entry.key: entry};
    final tomorrowEntriesByKey = {
      for (final entry in (_nextDayTimes?.entries ?? const <PrayerTimeEntry>[]))
        entry.key: entry,
    };
    final rule = _freePointsRule();
    final scoreSummary = widget.preferences.prayerScoreSummaryForRule(rule);
    final daySummary = widget.preferences.dailyPrayerScoreSummaryForRule(
      times.entries.first.time,
      rule,
    );
    final entitlements = await _loadWidgetEntitlements();
    final canUpdatePrayerTimes = _canUseWidget(
      'prayer_times_widget',
      entitlements,
    );
    final canUpdatePoints = _canUseWidget('points_widget', entitlements);
    final canUpdateControls = _canUseWidget(
      'quick_controls_widget',
      entitlements,
    );

    await Future.wait([
      if (canUpdatePrayerTimes)
        SalatiWidgetsService.updateTodayPrayerTimesWidget(
          fajr: _widgetTime(entriesByKey['fajr']),
          sunrise: _widgetTime(entriesByKey['sunrise']),
          dhuhr: _widgetTime(entriesByKey['dhuhr']),
          asr: _widgetTime(entriesByKey['asr']),
          maghrib: _widgetTime(entriesByKey['maghrib']),
          isha: _widgetTime(entriesByKey['isha']),
          activePrayerKey: info.nextPrayer.key,
          tomorrowFajr: _widgetTime(tomorrowEntriesByKey['fajr']),
          tomorrowSunrise: _widgetTime(tomorrowEntriesByKey['sunrise']),
          tomorrowDhuhr: _widgetTime(tomorrowEntriesByKey['dhuhr']),
          tomorrowAsr: _widgetTime(tomorrowEntriesByKey['asr']),
          tomorrowMaghrib: _widgetTime(tomorrowEntriesByKey['maghrib']),
          tomorrowIsha: _widgetTime(tomorrowEntriesByKey['isha']),
          tomorrowActivePrayerKey: 'fajr',
          accentColor: widget.preferences.homeWidgetAccentColor,
          themeMode: widget.preferences.homeWidgetThemeMode,
          textScale: widget.preferences.homeWidgetTextScale,
          showAllPrayers: widget.preferences.homeWidgetShowAllPrayers,
        ),
      SalatiWidgetsService.updateNextPrayerWidget(
        prayerName: info.nextPrayer.label,
        remaining: _experienceService.formatRemaining(info.timeRemaining),
        remainingMinutes: info.timeRemaining.inMinutes,
        prayerTime: info.nextPrayer.time,
        prayerKey: info.nextPrayer.key,
        accentColor: widget.preferences.homeWidgetAccentColor,
        themeMode: widget.preferences.homeWidgetThemeMode,
        textScale: widget.preferences.homeWidgetTextScale,
        showCountdown: widget.preferences.homeWidgetShowCountdown,
      ),
      if (canUpdatePoints)
        SalatiWidgetsService.updatePointsAndRatingWidget(
          points: _widgetScore(scoreSummary.totalScore),
          prayerRating: _widgetRating(daySummary),
          completedPrayersToday: daySummary.completedCount,
        ),
      if (canUpdateControls)
        SalatiWidgetsService.updateQuickControlsWidget(
          notificationsLoud: widget.preferences.prayerNotificationsEnabled,
          nextAlertEnabled: widget.preferences.prayerNotificationsEnabled,
          touchLockEnabled: widget.preferences.prayerFocusGuardEnabled,
        ),
      if (widget.preferences.prayerNotificationsEnabled)
        widget.services.notificationService.showOngoingPrayerStatus(
          title: 'صلاتي',
          body:
              'الصلاة القادمة: ${info.nextPrayer.label} بعد ${_experienceService.formatRemaining(info.timeRemaining)}',
          nextPrayerName: info.nextPrayer.label,
          nextPrayerTime: info.nextPrayer.time,
          remaining: info.timeRemaining,
        ),
      SalatiWidgetsService.scheduleMidnightWidgetRefresh(
        triggerAt: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1, minutes: 1)),
      ),
    ]);
  }

  String _widgetTime(PrayerTimeEntry? entry) {
    if (entry == null) {
      return '--:--';
    }

    final hour = entry.time.hour.toString().padLeft(2, '0');
    final minute = entry.time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _widgetScore(double value) {
    final text = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return value > 0 ? '+$text' : text;
  }

  String _widgetRating(PrayerScoreSummary summary) {
    if (summary.completedCount >= 5 && summary.missedCount == 0) {
      return 'ممتاز';
    }
    if (summary.completedCount >= 3 && summary.missedCount <= 1) {
      return 'جيد';
    }
    if (summary.missedCount > summary.completedCount) {
      return 'يحتاج هدوء وترتيب';
    }
    return 'قيد المتابعة';
  }

  Future<void> _autoMarkUnregisteredPassedPrayersAsMissed(
    DailyPrayerTimes times,
  ) async {
    final now = _trustedNow();
    var changed = false;

    final obligatoryEntries = times.entries
        .where((entry) => _obligatoryPrayerKeys.contains(entry.key))
        .toList();

    for (var index = 0; index < obligatoryEntries.length; index++) {
      final prayer = obligatoryEntries[index];

      if (widget.preferences.isPrayerLocked(
        prayerKey: prayer.key,
        date: prayer.time,
      )) {
        continue;
      }

      final DateTime autoMissedAt;

      if (index < obligatoryEntries.length - 1) {
        final nextPrayer = obligatoryEntries[index + 1];

        // إذا دخل وقت الصلاة التالية ولم تسجل الصلاة الحالية، تعتبر فائتة.
        autoMissedAt = nextPrayer.time;
      } else {
        // العشاء: اعتبرها فائتة بعد نصف ساعة من منتصف الليل أو وقت مناسب لاحق.
        final nextDay = DateTime(
          prayer.time.year,
          prayer.time.month,
          prayer.time.day,
        ).add(const Duration(days: 1));

        autoMissedAt = nextDay.add(const Duration(minutes: 30));
      }

      if (now.isBefore(autoMissedAt)) {
        continue;
      }

      await widget.preferences.markPrayerMissed(
        prayerKey: prayer.key,
        date: prayer.time,
      );
      await _awardPrayerPoints(prayer, PrayerPointResult.missed);

      changed = true;
    }

    if (!changed) {
      return;
    }

    final stateDate = times.entries.first.time;

    if (mounted) {
      setState(() {
        _completedPrayerKeys = widget.preferences.completedPrayerKeysForDate(
          stateDate,
        );
        _missedPrayerKeys = widget.preferences.missedPrayerKeysForDate(
          stateDate,
        );
      });
    }

    await _syncCurrentPointsToFirestore();
    await _syncHomeWidgets(force: true);
  }

  Future<void> _markPrayerAsPrayed(PrayerTimeEntry prayer) async {
    await _markPrayerAsPrayedWithOptions(prayer, withNawafil: false);
  }

  Future<void> _markPrayerAsPrayedWithOptions(
    PrayerTimeEntry prayer, {
    required bool withNawafil,
  }) async {
    final result = _prayerPointResultForCompletion(prayer);
    await widget.preferences.markPrayerCompleted(
      prayerKey: prayer.key,
      date: prayer.time,
      withNawafil: withNawafil,
      completedLate: result == PrayerPointResult.late,
    );

    final stateDate = _displayTimes?.entries.first.time ?? prayer.time;

    if (mounted) {
      setState(() {
        _completedPrayerKeys = widget.preferences.completedPrayerKeysForDate(
          stateDate,
        );
        _missedPrayerKeys = widget.preferences.missedPrayerKeysForDate(
          stateDate,
        );
      });
    }

    await _syncCurrentPointsToFirestore();
    await _awardPrayerPoints(prayer, result);
    await _syncHomeWidgets(force: true);

    final totalPoints = _currentUserPoints();

    _logScore(
      'updated total=$totalPoints prayer=${prayer.key} state=${withNawafil ? 'prayed_with_nawafil' : 'prayed'}',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تسجيل ${prayer.label}. نقاطك الآن: ${totalPoints.toStringAsFixed(2)}',
        ),
      ),
    );
  }

  Future<void> _markPrayerAsMissed(PrayerTimeEntry prayer) async {
    await widget.preferences.markPrayerMissed(
      prayerKey: prayer.key,
      date: prayer.time,
    );

    final stateDate = _displayTimes?.entries.first.time ?? prayer.time;

    if (mounted) {
      setState(() {
        _completedPrayerKeys = widget.preferences.completedPrayerKeysForDate(
          stateDate,
        );
        _missedPrayerKeys = widget.preferences.missedPrayerKeysForDate(
          stateDate,
        );
      });
    }

    await _syncCurrentPointsToFirestore();
    await _awardPrayerPoints(prayer, PrayerPointResult.missed);
    await _syncHomeWidgets(force: true);

    final totalPoints = _currentUserPoints();

    _logScore('updated total=$totalPoints prayer=${prayer.key} state=missed');

    await _openReflectionModal(prayer);
  }

  Future<PointsAwardResult> _awardPrayerPoints(
    PrayerTimeEntry prayer,
    PrayerPointResult result,
  ) async {
    final session = widget.services.authService.currentSession;
    if (session == null) {
      return const PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'missing-session',
      );
    }

    try {
      return await _pointsAwardService.awardPrayer(
        prayerKey: prayer.key,
        date: prayer.time,
        result: result,
        prayerName: prayer.label,
      );
    } catch (error) {
      _logScore('points award failed prayer=${prayer.key} error=$error');
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: error.toString(),
      );
    }
  }

  PrayerPointResult _prayerPointResultForCompletion(PrayerTimeEntry prayer) {
    final now = _trustedNow();
    return _isLatePrayerCompletion(prayer, now)
        ? PrayerPointResult.late
        : PrayerPointResult.onTime;
  }

  bool _isLatePrayerCompletion(PrayerTimeEntry prayer, DateTime now) {
    final nextPrayerStart = _nextObligatoryPrayerStartAfter(prayer);
    if (nextPrayerStart != null && !now.isBefore(nextPrayerStart)) {
      return true;
    }
    final onTimeUntil = prayer.time.add(const Duration(minutes: 30));
    return now.isAfter(onTimeUntil);
  }

  DateTime? _nextObligatoryPrayerStartAfter(PrayerTimeEntry prayer) {
    final entries = (_displayTimes ?? _times)?.entries
        .where((entry) => _obligatoryPrayerKeys.contains(entry.key))
        .toList(growable: false);
    if (entries == null || entries.isEmpty) {
      return null;
    }

    final index = entries.indexWhere((entry) => entry.key == prayer.key);
    if (index < 0) {
      return null;
    }
    if (index < entries.length - 1) {
      return entries[index + 1].time;
    }
    return _nextDayTimes?.entryFor('fajr')?.time;
  }

  Future<PrayerReflectionEntry?> _loadSavedReflection(
    PrayerTimeEntry prayer,
  ) async {
    final docId = _reflectionDocId(prayer);
    if (_savedReflections.containsKey(docId)) {
      return _savedReflections[docId];
    }

    final session = widget.services.authService.currentSession;
    if (session == null) {
      return null;
    }

    try {
      final existing = await widget.services.prayerReflectionRepository
          .loadReflection(uid: session.uid, docId: docId);
      if (existing != null) {
        _savedReflections[docId] = existing;
      }
      return existing;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openReflectionModal(PrayerTimeEntry prayer) async {
    final prompt = _experienceService.reflectionPromptForMissedPrayer(
      prayer.key,
    );
    if (prompt == null || !mounted) {
      return;
    }

    final existingEntry = await _loadSavedReflection(prayer);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _PrayerReflectionSheet(
          prompt: prompt,
          existingEntry: existingEntry,
          onSubmit: (answers) => _saveReflectionAnswers(
            prayer: prayer,
            prompt: prompt,
            answers: answers,
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openPrayerInteractionModal(PrayerTimeEntry prayer) async {
    if (prayer.key == 'sunrise') {
      return;
    }

    if (widget.preferences.isPrayerLocked(
      prayerKey: prayer.key,
      date: prayer.time,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ حالة هذه الصلاة بالفعل ولا يمكن تعديلها الآن.'),
        ),
      );
      return;
    }

    final guide = _experienceService.guideFor(prayer.key);
    final currentState = _stateForPrayer(prayer);
    final action = await showModalBottomSheet<_PrayerCheckState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _PrayerInteractionSheet(
          prayer: prayer,
          guide: guide,
          currentState: currentState,
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _PrayerCheckState.prayed:
        await _markPrayerAsPrayed(prayer);
        break;
      case _PrayerCheckState.prayedWithNawafil:
        await _markPrayerAsPrayedWithOptions(prayer, withNawafil: true);
        break;
      case _PrayerCheckState.missed:
        await _markPrayerAsMissed(prayer);
        break;
    }
  }

  Future<void> _openPrayerScheduleSheet(PrayerTimeEntry prayer) async {
    final isSunrise = prayer.key == 'sunrise';
    final guide = _experienceService.guideFor(prayer.key);
    final now = _trustedNow();
    final remaining = prayer.time.difference(now);
    final canRegister = !isSunrise && !prayer.time.isAfter(now);
    var adhanEnabled = widget.preferences.isAdhanEnabledForPrayer(prayer.key);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      prayer.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      title: remaining.isNegative
                          ? 'دخل وقت الصلاة منذ'
                          : 'فاضل على الصلاة',
                      body: _formatCountdown(remaining.abs()),
                    ),
                    const SizedBox(height: 12),
                    if (!isSunrise) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: adhanEnabled,
                        title: const Text('الأذان لهذه الصلاة'),
                        subtitle: Text(
                          adhanEnabled
                              ? 'سيتم جدولة تنبيه الأذان لهذه الصلاة عند حفظ الإعدادات.'
                              : 'لن يتم جدولة تنبيه لهذه الصلاة.',
                        ),
                        onChanged: (value) {
                          setSheetState(() => adhanEnabled = value);
                          unawaited(_setPrayerAdhanEnabled(prayer.key, value));
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    InfoCard(
                      title: 'طريقة الصلاة',
                      body: [
                        'فرض ${guide.prayerName}: ${_rakaatLabel(guide.fardRakaat)}.',
                        ...guide.simpleSteps.map((item) => '- $item'),
                      ].join('\n'),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      title: 'رخصة القصر في السفر',
                      body: _qasrGuideBody(guide),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      title: 'ماذا تقرأ؟',
                      body: guide.recitationGuidance
                          .map((item) => '- $item')
                          .join('\n'),
                    ),
                    const SizedBox(height: 12),
                    if (!isSunrise)
                      OutlinedButton.icon(
                        onPressed: () => _openPrayerOverviewSheet(guide),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('تفاصيل أكثر عن الصلاة'),
                      ),
                    if (canRegister) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_openPrayerInteractionModal(prayer));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('تسجيل حالة الصلاة'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setPrayerAdhanEnabled(String prayerKey, bool enabled) async {
    await widget.preferences.setAdhanEnabledForPrayer(prayerKey, enabled);
    if (!mounted) {
      return;
    }
    setState(() {});

    final settings = _settings;
    final config = _operationalConfig;
    if (settings == null || config == null || !settings.notificationsEnabled) {
      return;
    }

    final granted = await widget.services.notificationService
        .requestPermissions();
    if (!granted) {
      return;
    }

    await widget.services.notificationService.cancelPrayerNotifications();
    final prayerTimesService = LocalPrayerTimesService(
      operationalConfig: config,
    );
    final now = _trustedNow();
    final dates = [now, now.add(const Duration(days: 1))];
    const prayerKeys = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};

    for (final date in dates) {
      final times = await prayerTimesService.getPrayerTimesForDate(
        settings: settings,
        date: date,
      );
      for (var index = 0; index < times.entries.length; index++) {
        final entry = times.entries[index];
        if (!prayerKeys.contains(entry.key) ||
            !widget.preferences.isAdhanEnabledForPrayer(entry.key)) {
          continue;
        }
        final id =
            date.year * 100000 + date.month * 1000 + date.day * 10 + index;
        await widget.services.notificationService.schedulePrayerReminder(
          id: id,
          title: 'حان وقت الصلاة',
          body: 'صلاة ${entry.label} الآن',
          scheduledAt: entry.time,
          androidSound: _androidSoundForPrayer(entry.key),
        );
      }
    }
    await _scheduleAdhkarAndSurahReminders();
  }

  Future<void> _scheduleAdhkarAndSurahReminders() async {
    final now = _trustedNow();
    final preferences = widget.preferences;
    if (preferences.morningAdhkarReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _morningAdhkarNotificationId,
        title: 'أذكار الصباح',
        body: 'ابدأ ورد الصباح بهدوء وذكر.',
        scheduledAt: _nextDailyTime(
          preferences.morningAdhkarReminderMinutes,
          now,
        ),
        androidSound: _rawAzkarSound(preferences.selectedMorningAzkarSoundKey),
      );
    }
    if (preferences.eveningAdhkarReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _eveningAdhkarNotificationId,
        title: 'أذكار المساء',
        body: 'وقت ورد المساء وطمأنينة نهاية اليوم.',
        scheduledAt: _nextDailyTime(
          preferences.eveningAdhkarReminderMinutes,
          now,
        ),
        androidSound: _rawAzkarSound(preferences.selectedEveningAzkarSoundKey),
      );
    }
    if (preferences.fridayKahfReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _fridayKahfNotificationId,
        title: 'سورة الكهف',
        body: 'تنبيه الجمعة لقراءة سورة الكهف.',
        scheduledAt: _nextWeekdayTime(
          DateTime.friday,
          preferences.fridayKahfReminderMinutes,
          now,
        ),
        payload: 'quran_surah:18',
        useAlarmAudio: false,
      );
    }
    if (preferences.mulkReminderEnabled) {
      await widget.services.notificationService.schedulePrayerReminder(
        id: _mulkNotificationId,
        title: 'سورة الملك',
        body: 'وقت قراءة سورة الملك حسب اختيارك.',
        scheduledAt: _nextDailyTime(preferences.mulkReminderMinutes, now),
        payload: 'quran_surah:67',
        useAlarmAudio: false,
      );
    }
  }

  String _androidSoundForPrayer(String prayerKey) {
    if (prayerKey == 'fajr') {
      return _rawAdhanSound(widget.preferences.selectedFajrAdhanKey);
    }
    return _rawAdhanSound(widget.preferences.selectedAdhanKey);
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

  Future<PrayerReflectionEntry?> _saveReflectionAnswers({
    required PrayerTimeEntry prayer,
    required PrayerReflectionPrompt prompt,
    required Map<String, String> answers,
  }) async {
    final session = widget.services.authService.currentSession;
    if (session == null) {
      _logReflection('failed reason=missing-session prayer=${prayer.key}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mapAppErrorToArabic(
                FirebaseException(plugin: 'salati', code: 'missing-session'),
              ),
            ),
          ),
        );
      }
      return null;
    }

    final docId = _reflectionDocId(prayer);
    final entry = PrayerReflectionEntry(
      docId: docId,
      prayerKey: prompt.prayerKey,
      prayerName: prayer.label,
      answeredAt: _trustedNow(),
      scoreAtMoment: widget.preferences.dailyPrayerScore(_trustedNow()).round(),
      answers: prompt.questions
          .map(
            (question) => PrayerReflectionAnswer(
              questionId: question.id,
              question: question.prompt,
              answer: answers[question.id] ?? '',
            ),
          )
          .toList(),
      questionIds: prompt.questions.map((question) => question.id).toList(),
    );

    try {
      final saved = await widget.services.prayerReflectionRepository
          .saveReflectionOnce(uid: session.uid, entry: entry);
      if (!saved) {
        final existing = await widget.services.prayerReflectionRepository
            .loadReflection(uid: session.uid, docId: docId);
        if (existing != null) {
          _logReflection('success path=existing docId=$docId');
          _savedReflections[docId] = existing;
          return existing;
        }
        _logReflection('failed reason=not-saved docId=$docId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mapAppErrorToArabic(StateError('not-saved'))),
            ),
          );
        }
        return null;
      }
      _logReflection('success docId=$docId');
      _savedReflections[docId] = entry;
      return entry;
    } on FirebaseException catch (error) {
      _logReflection('failed reason=${error.code} docId=$docId');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
      }
      return null;
    } catch (error) {
      _logReflection('failed reason=unexpected docId=$docId');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
      }
      return null;
    }
  }

  Future<void> _openPrayerDetails(
    PrayerGuide guide,
    _PrayerSegment segment,
  ) async {
    final title = switch (segment) {
      _PrayerSegment.before => 'تفاصيل قبل ${guide.prayerName}',
      _PrayerSegment.fard => 'تفاصيل فرض ${guide.prayerName}',
      _PrayerSegment.after => 'تفاصيل بعد ${guide.prayerName}',
    };
    final rakaat = switch (segment) {
      _PrayerSegment.before => guide.beforeRakaat,
      _PrayerSegment.fard => guide.fardRakaat,
      _PrayerSegment.after => guide.afterRakaat,
    };
    final note = switch (segment) {
      _PrayerSegment.before => guide.beforeNote,
      _PrayerSegment.fard => guide.fardNote,
      _PrayerSegment.after => guide.afterNote,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                InfoCard(
                  title: 'عدد الركعات',
                  body: '${_rakaatLabel(rakaat)}\n$note',
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'ماذا يفعل؟',
                  body: guide.simpleSteps.map((item) => '- $item').join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'ماذا يقرأ؟',
                  body: guide.recitationGuidance
                      .map((item) => '- $item')
                      .join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'رخصة القصر في السفر',
                  body: _qasrGuideBody(guide),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'الوضوء (مختصر)',
                  body: guide.wuduGuidance.map((item) => '- $item').join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'تنبيه لطيف',
                  body: guide.notes.map((item) => '- $item').join('\n'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPrayerOverviewSheet(PrayerGuide guide) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'شرح ${guide.prayerName}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _PrayerStructureChips(guide: guide),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'طريقة الصلاة',
                  body: guide.simpleSteps.map((item) => '- $item').join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'ماذا يُقرأ',
                  body: guide.recitationGuidance
                      .map((item) => '- $item')
                      .join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'رخصة القصر في السفر',
                  body: _qasrGuideBody(guide),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'الوضوء',
                  body: guide.wuduGuidance.map((item) => '- $item').join('\n'),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: 'ملاحظات',
                  body: guide.notes.map((item) => '- $item').join('\n'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePrimaryCardTap(PrayerGuide guide) {
    final now = _trustedNow();
    if (_lastHeroTapAt == null ||
        now.difference(_lastHeroTapAt!) > const Duration(milliseconds: 650)) {
      _heroTapCount = 0;
    }

    _lastHeroTapAt = now;
    _heroTapCount += 1;
    if (_heroTapCount >= 3) {
      _heroTapCount = 0;
      _openPrayerOverviewSheet(guide);
    }
  }

  _PrayerMomentState _momentStateForPrayer(
    PrayerTimeEntry prayer,
    DateTime reference,
  ) {
    if (prayer.key == 'sunrise') {
      return _PrayerMomentState.informational;
    }

    final completed = widget.preferences.completedPrayerKeysForDate(
      prayer.time,
    );
    if (completed.contains(prayer.key)) {
      final nawafil = widget.preferences.nawafilPrayerKeysForDate(prayer.time);
      return nawafil.contains(prayer.key)
          ? _PrayerMomentState.prayedWithNawafil
          : _PrayerMomentState.prayed;
    }

    final missed = widget.preferences.missedPrayerKeysForDate(prayer.time);
    if (missed.contains(prayer.key)) {
      return _PrayerMomentState.missed;
    }

    if (!_obligatoryPrayerKeys.contains(prayer.key)) {
      return _PrayerMomentState.informational;
    }

    final selectedDay = DateUtils.dateOnly(prayer.time);
    final today = DateUtils.dateOnly(reference);
    if (selectedDay.isBefore(today)) {
      return _PrayerMomentState.pending;
    }
    if (selectedDay.isAfter(today)) {
      return _PrayerMomentState.upcoming;
    }
    return prayer.time.isAfter(reference)
        ? _PrayerMomentState.upcoming
        : _PrayerMomentState.pending;
  }

  _PrayerOverviewSummary _buildOverviewSummary(DailyPrayerTimes times) {
    final reference = _trustedNow();
    final rule = _freePointsRule();
    var score = 0.0;
    var completedCount = 0;
    var missedCount = 0;
    var pendingCount = 0;

    for (final prayer in times.entries) {
      if (!_obligatoryPrayerKeys.contains(prayer.key)) {
        continue;
      }

      switch (_momentStateForPrayer(prayer, reference)) {
        case _PrayerMomentState.prayed:
          score += rule.prayerOnTime;
          completedCount += 1;
          break;

        case _PrayerMomentState.prayedWithNawafil:
          score += rule.prayerOnTime + 0.25;
          completedCount += 1;
          break;

        case _PrayerMomentState.missed:
          score += rule.prayerMissed;
          missedCount += 1;
          break;

        case _PrayerMomentState.pending:
          score += _pointsPending;
          pendingCount += 1;
          break;

        case _PrayerMomentState.upcoming:
        case _PrayerMomentState.informational:
          break;
      }
    }

    return _PrayerOverviewSummary(
      score: score,
      completedCount: completedCount,
      missedCount: missedCount,
      pendingCount: pendingCount,
    );
  }

  String _formatCountdown(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatQiyamSuggestion(QiyamTimeSuggestion suggestion) {
    final time = TimeOfDay.fromDateTime(suggestion.suggestedAt).format(context);
    return '${suggestion.label} • $time';
  }

  String _formatPrayerTime(PrayerTimeEntry prayer) {
    return TimeOfDay.fromDateTime(prayer.time).format(context);
  }

  String _formatDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  _PrayerUrgency _urgencyFor(Duration remaining) {
    final minutes = remaining.inMinutes;
    if (minutes < 10) {
      return const _PrayerUrgency(
        level: _PrayerUrgencyLevel.urgent,
        label: 'أقل من 10 دقائق',
        accent: Color(0xFFE5484D),
        background: Color(0xFFFFECEC),
        foreground: Color(0xFF8A0F15),
      );
    }
    if (minutes < 30) {
      return const _PrayerUrgency(
        level: _PrayerUrgencyLevel.soon,
        label: 'اقترب الوقت',
        accent: Color(0xFFF5A524),
        background: Color(0xFFFFF3D6),
        foreground: Color(0xFF7A4B00),
      );
    }
    return const _PrayerUrgency(
      level: _PrayerUrgencyLevel.calm,
      label: 'الوقت متاح',
      accent: Color(0xFF1F9D62),
      background: Color(0xFFEAF8F0),
      foreground: Color(0xFF0B5D37),
    );
  }

  Future<void> _openAppRoute(String route) async {
    await Navigator.of(context).pushNamed(route);
  }

  Future<void> _enableAndRefreshHomeWidgets() async {
    await HapticFeedback.selectionClick();
    await widget.preferences.setHomeWidgetsEnabled(true);
    await _syncHomeWidgets(force: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديث بيانات الودجات. لو الودجت قديم احذفه وأضفه مرة أخرى.',
          ),
        ),
      );
  }

  Future<void> _openWidgetsDashboardSheet() async {
    final info = _info;
    final times = _displayTimes ?? _times;
    if (info == null || times == null) {
      return;
    }
    final widgetEntitlementsFuture = _loadWidgetEntitlements();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Color accentColor() =>
                _colorFromHex(widget.preferences.homeWidgetAccentColor);

            Future<void> updatePreference(
              Future<void> Function() action,
            ) async {
              await action();
              if (context.mounted) {
                setSheetState(() {});
              }
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الودجات',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'عاين الودجات وعدل شكلها قبل تحديثها على الشاشة الرئيسية.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<FeatureEntitlement>>(
                      future: widgetEntitlementsFuture,
                      builder: (context, entitlementSnapshot) {
                        final entitlements =
                            entitlementSnapshot.data ??
                            const <FeatureEntitlement>[];
                        final canShowPrayerTimes = _canUseWidget(
                          'prayer_times_widget',
                          entitlements,
                        );
                        final canShowPoints = _canUseWidget(
                          'points_widget',
                          entitlements,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WidgetPreviewCard(
                              title: 'الصلاة القادمة',
                              accent: accentColor(),
                              child: _NextPrayerWidgetPreview(
                                prayerName: info.nextPrayer.label,
                                timeLabel: _formatPrayerTime(info.nextPrayer),
                                countdownLabel:
                                    widget.preferences.homeWidgetShowCountdown
                                    ? _formatCountdown(info.timeRemaining)
                                    : 'مخفي',
                                textScale:
                                    widget.preferences.homeWidgetTextScale,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _WidgetPreviewCard(
                              title: 'تاريخ اليوم',
                              accent: accentColor(),
                              child: _DateWidgetPreview(
                                gregorianLabel: _formatDateLabel(_trustedNow()),
                                textScale:
                                    widget.preferences.homeWidgetTextScale,
                              ),
                            ),
                            if (canShowPrayerTimes) ...[
                              const SizedBox(height: 12),
                              _WidgetPreviewCard(
                                title: 'مواقيت اليوم',
                                accent: accentColor(),
                                child: _PrayerTimesWidgetPreview(
                                  times: times,
                                  activePrayerKey: _nextPrayerKeyForDisplay(
                                    info,
                                  ),
                                  showAllPrayers: widget
                                      .preferences
                                      .homeWidgetShowAllPrayers,
                                  textScale:
                                      widget.preferences.homeWidgetTextScale,
                                ),
                              ),
                            ],
                            if (canShowPoints) ...[
                              const SizedBox(height: 12),
                              _WidgetPreviewCard(
                                title: 'الورد والنقاط',
                                accent: accentColor(),
                                child: _ProgressWidgetPreview(
                                  completedPrayersToday: widget.preferences
                                      .dailyPrayerScoreSummary(
                                        times.entries.first.time,
                                      )
                                      .completedCount,
                                  totalPoints: widget
                                      .preferences
                                      .prayerScoreSummary
                                      .totalScore,
                                  quranProgress:
                                      'سورة ${widget.preferences.quranLastSurah}، آية ${widget.preferences.quranLastAyah}',
                                  textScale:
                                      widget.preferences.homeWidgetTextScale,
                                ),
                              ),
                            ],
                            if (!canShowPrayerTimes || !canShowPoints) ...[
                              const SizedBox(height: 12),
                              InfoCard(
                                title: 'الودجتات المدفوعة مخفية',
                                body:
                                    'أي ودجت مدفوع يظهر هنا بعد شرائه من المتجر أو منحه من الداشبورد.',
                                trailing: const Icon(Icons.lock_outline),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _WidgetSettingsSection(
                      accentColor: widget.preferences.homeWidgetAccentColor,
                      themeMode: widget.preferences.homeWidgetThemeMode,
                      textScale: widget.preferences.homeWidgetTextScale,
                      showCountdown: widget.preferences.homeWidgetShowCountdown,
                      showAllPrayers:
                          widget.preferences.homeWidgetShowAllPrayers,
                      onAccentChanged: (value) => updatePreference(
                        () =>
                            widget.preferences.setHomeWidgetAccentColor(value),
                      ),
                      onThemeModeChanged: (value) => updatePreference(
                        () => widget.preferences.setHomeWidgetThemeMode(value),
                      ),
                      onTextScaleChanged: (value) => updatePreference(
                        () => widget.preferences.setHomeWidgetTextScale(value),
                      ),
                      onShowCountdownChanged: (value) => updatePreference(
                        () => widget.preferences.setHomeWidgetShowCountdown(
                          value,
                        ),
                      ),
                      onShowAllPrayersChanged: (value) => updatePreference(
                        () => widget.preferences.setHomeWidgetShowAllPrayers(
                          value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await _enableAndRefreshHomeWidgets();
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('حفظ وتحديث الودجات'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لو ظهر تصميم قديم بعد التحديث، احذف الودجت من الشاشة الرئيسية وأضفه مرة أخرى.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _colorFromHex(String value) {
    final clean = value.replaceAll('#', '').trim();
    final parsed = int.tryParse(
      clean.length == 6 ? 'FF$clean' : clean,
      radix: 16,
    );
    return parsed == null ? const Color(0xFF1F9D62) : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _PrayerDashboardSkeleton();
    }

    if (_error != null) {
      return ErrorStateView(
        title: 'تعذر تحميل صلاتي',
        message: _error!,
        onRetry: _load,
      );
    }

    final settings = _settings;
    final info = _info;
    final times = _times;
    final displayTimes = _displayTimes;
    final config = _operationalConfig;
    if (settings == null ||
        info == null ||
        times == null ||
        displayTimes == null ||
        config == null) {
      return ErrorStateView(
        title: 'تعذر تحميل صلاتي',
        message: mapAppErrorToArabic(StateError('missing-prayer-data')),
        onRetry: _load,
      );
    }

    final focusPrayer =
        _currentRegisterablePrayer(times) ??
        info.currentPrayer ??
        info.lastPassedPrayer ??
        _lastPassedPrayer(times);
    final primaryPrayer = info.nextPrayer;
    final primaryGuide = _experienceService.guideFor(primaryPrayer.key);
    final overviewSummary = _buildOverviewSummary(times);
    final touchLockActive = _isPrayerTouchLockActive(info);
    final urgency = _urgencyFor(info.timeRemaining);
    final remoteConfig = _remoteDashboardConfig;
    final dashboardSections = _orderedDashboardSections({
      'prayer_times': _RemainingPrayersCard(
        times: displayTimes,
        title: _showingNextDayPrayers ? 'صلوات الغد' : 'صلوات اليوم',
        qiyamLabel: _formatQiyamSuggestion(info.qiyamSuggestion),
        currentPrayerKey: _showingNextDayPrayers
            ? null
            : info.currentPrayer?.key,
        nextPrayerKey: _nextPrayerKeyForDisplay(info),
        completedPrayerKeys: _completedPrayerKeys,
        missedPrayerKeys: _missedPrayerKeys,
        referenceNow: _trustedNow(),
        onPrayerTap: _openPrayerScheduleSheet,
      ),
    });

    final content = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),

      children: [
        _SalatiPrayerHeader(
          times: displayTimes,
          info: info,
          prayerTimeLabel: _formatPrayerTime(primaryPrayer),
          countdownLabel: _formatCountdown(info.timeRemaining),
          dateLabel: _formatDateLabel(displayTimes.entries.first.time),
          serverClockAvailable: _serverClockAvailable,
          onRefreshTap: _refreshDeviceLocationAndReload,
        ),
        const SizedBox(height: 14),
        _PrayerFeatureGrid(
          registerPrayerLabel: focusPrayer?.label,
          onRegisterTap: focusPrayer == null
              ? null
              : () => _openPrayerInteractionModal(focusPrayer),
          onQuranTap: () => _openAppRoute(AppRouter.quranRoute),
          onAdhkarTap: () => _openAppRoute(AppRouter.adhkarRoute),
          onSettingsTap: () => _openAppRoute(AppRouter.prayerSettingsRoute),
        ),
        const SizedBox(height: 14),
        if (displayTimes.locationLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTimes.locationLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (_serverClockAvailable)
                            Text(
                              'الوقت محسوب بمرجع موثوق من السيرفر',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'تحديث المواقيت',
                      onPressed: _refreshDeviceLocationAndReload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (remoteConfig.globalMessage.isNotEmpty) ...[
          _GlobalDashboardMessageCard(
            message: remoteConfig.globalMessage,
            accent: _colorFromHex(remoteConfig.primaryColorHex),
          ),
          const SizedBox(height: 12),
        ],
        ..._withSectionSpacing(dashboardSections),
        if (const bool.fromEnvironment('SALATI_SHOW_LEGACY_DASHBOARD')) ...[
          _PrimaryPrayerHeroCardV2(
            prayer: primaryPrayer,
            guide: primaryGuide,
            urgency: urgency,
            countdownLabel: _formatCountdown(info.timeRemaining),
            state: _stateForPrayer(primaryPrayer),
            registerPrayerLabel: focusPrayer?.label,
            onRegisterTap: focusPrayer == null
                ? null
                : () => _openPrayerInteractionModal(focusPrayer),
            onGuideTap: () => _openPrayerOverviewSheet(primaryGuide),
            onCardTap: () => _handlePrimaryCardTap(primaryGuide),
            onSegmentTap: _openPrayerDetails,
          ),
          const SizedBox(height: 12),
          _PrayerQuickActionsCard(
            registerPrayerLabel: focusPrayer?.label,
            notificationsEnabled: settings.notificationsEnabled,
            widgetsEnabled: widget.preferences.homeWidgetsEnabled,
            onRegisterTap: focusPrayer == null
                ? null
                : () => _openPrayerInteractionModal(focusPrayer),
            onSettingsTap: () => _openAppRoute(AppRouter.prayerSettingsRoute),
            onWidgetRefreshTap: _enableAndRefreshHomeWidgets,
            onWidgetPreviewTap: _openWidgetsDashboardSheet,
            onQuranTap: () => _openAppRoute(AppRouter.quranRoute),
            onAdhkarTap: () => _openAppRoute(AppRouter.adhkarRoute),
          ),
          const SizedBox(height: 12),
          _RemainingPrayersCard(
            times: displayTimes,
            title: _showingNextDayPrayers ? 'صلوات الغد' : 'صلوات اليوم',
            qiyamLabel: _formatQiyamSuggestion(info.qiyamSuggestion),
            currentPrayerKey: _showingNextDayPrayers
                ? null
                : info.currentPrayer?.key,
            nextPrayerKey: _nextPrayerKeyForDisplay(info),
            completedPrayerKeys: _completedPrayerKeys,
            missedPrayerKeys: _missedPrayerKeys,
            referenceNow: _trustedNow(),
            onPrayerTap: _openPrayerScheduleSheet,
          ),
          const SizedBox(height: 12),
          _DailyResultCard(
            summary: overviewSummary,
            streakDays: _completedPrayerStreak(),
            quranProgressLabel: _quranProgressLabel(),
            adhkarProgressLabel: _adhkarProgressLabel(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DailyResultsScreen(
                    settings: settings,
                    preferences: widget.preferences,
                    operationalConfig: config,
                    initialDate: _trustedNow(),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );

    if (!touchLockActive) {
      return content;
    }

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: _PrayerTouchLockOverlay(
            prayerLabel: info.nextPrayer.label,
            remainingLabel: _formatCountdown(info.timeRemaining),
            tapCount: _touchLockTapCount,
            requiredTaps: _touchLockRequiredTaps,
            onTap: () => _handlePrayerTouchLockTap(info.nextPrayer),
          ),
        ),
      ],
    );
  }

  bool _isPrayerTouchLockActive(PrayerTimeInfo info) {
    if (!widget.preferences.prayerFocusGuardEnabled) {
      _touchLockTapCount = 0;
      return false;
    }

    final nextPrayer = info.nextPrayer;
    if (nextPrayer.key == 'sunrise') {
      return false;
    }

    final key = _touchLockKey(nextPrayer);
    if (_dismissedTouchLockPrayerKey == key) {
      return false;
    }

    final lead = Duration(
      seconds: widget.preferences.prayerLeadReminderSeconds.clamp(10, 3600),
    );
    final remaining = nextPrayer.time.difference(_trustedNow());
    final active = !remaining.isNegative && remaining <= lead;
    if (!active) {
      _touchLockTapCount = 0;
    }
    return active;
  }

  void _handlePrayerTouchLockTap(PrayerTimeEntry prayer) {
    final nextCount = (_touchLockTapCount + 1).clamp(0, _touchLockRequiredTaps);
    setState(() => _touchLockTapCount = nextCount);
    if (nextCount >= _touchLockRequiredTaps) {
      setState(() {
        _dismissedTouchLockPrayerKey = _touchLockKey(prayer);
        _touchLockTapCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إيقاف قفل اللمس لصلاة ${prayer.label}.')),
      );
    }
  }

  String _touchLockKey(PrayerTimeEntry prayer) {
    final date = prayer.time;
    return '${date.year}-${date.month}-${date.day}:${prayer.key}';
  }

  String? _nextPrayerKeyForDisplay(PrayerTimeInfo info) {
    final displayTimes = _displayTimes;
    if (displayTimes == null) {
      return null;
    }
    final next = info.nextPrayer;
    final displayDate = displayTimes.entries.first.time;
    final isSameDay =
        next.time.year == displayDate.year &&
        next.time.month == displayDate.month &&
        next.time.day == displayDate.day;
    return isSameDay ? next.key : null;
  }

  PrayerTimeEntry? _currentRegisterablePrayer(DailyPrayerTimes times) {
    final now = _trustedNow();

    final obligatoryEntries = times.entries
        .where((entry) => _obligatoryPrayerKeys.contains(entry.key))
        .toList();

    for (var index = 0; index < obligatoryEntries.length; index++) {
      final prayer = obligatoryEntries[index];

      if (now.isBefore(prayer.time)) {
        continue;
      }

      final DateTime registerUntil;

      if (index < obligatoryEntries.length - 1) {
        final nextPrayer = obligatoryEntries[index + 1];

        // تظل الصلاة الحالية قابلة للتسجيل حتى نصف ساعة بعد الصلاة التالية.
        registerUntil = nextPrayer.time.add(const Duration(minutes: 30));
      } else {
        final nextDay = DateTime(
          prayer.time.year,
          prayer.time.month,
          prayer.time.day,
        ).add(const Duration(days: 1));

        registerUntil = nextDay.add(const Duration(minutes: 30));
      }

      if (now.isBefore(registerUntil)) {
        return prayer;
      }
    }

    return null;
  }

  PrayerTimeEntry? _lastPassedPrayer(DailyPrayerTimes times) {
    final now = _trustedNow();
    final prayers = times.entries.where((entry) => entry.key != 'sunrise');
    for (final entry in prayers.toList().reversed) {
      if (!entry.time.isAfter(now)) {
        return entry;
      }
    }
    return null;
  }

  _PrayerCheckState? _stateForPrayer(PrayerTimeEntry prayer) {
    final completed = widget.preferences.completedPrayerKeysForDate(
      prayer.time,
    );
    if (completed.contains(prayer.key)) {
      final nawafil = widget.preferences.nawafilPrayerKeysForDate(prayer.time);
      return nawafil.contains(prayer.key)
          ? _PrayerCheckState.prayedWithNawafil
          : _PrayerCheckState.prayed;
    }

    final missed = widget.preferences.missedPrayerKeysForDate(prayer.time);
    if (missed.contains(prayer.key)) {
      return _PrayerCheckState.missed;
    }

    return null;
  }

  bool _isAfterIsha(DailyPrayerTimes times, DateTime now) {
    final isha = times.entryFor('isha');
    return isha != null && !now.isBefore(isha.time);
  }

  String _reflectionDocId(PrayerTimeEntry prayer) {
    final year = prayer.time.year.toString().padLeft(4, '0');
    final month = prayer.time.month.toString().padLeft(2, '0');
    final day = prayer.time.day.toString().padLeft(2, '0');
    return 'reflection_$year-$month-${day}_${prayer.key}';
  }

  List<Widget> _orderedDashboardSections(Map<String, Widget> sections) {
    final hidden = _remoteDashboardConfig.hiddenHomeSections;
    final orderedKeys = <String>[
      ..._remoteDashboardConfig.homeCardOrder,
      ...sections.keys.where(
        (key) => !_remoteDashboardConfig.homeCardOrder.contains(key),
      ),
    ];

    return orderedKeys
        .where((key) => !hidden.contains(key))
        .map((key) => sections[key])
        .whereType<Widget>()
        .toList(growable: false);
  }

  List<Widget> _withSectionSpacing(List<Widget> sections) {
    final widgets = <Widget>[];
    for (var index = 0; index < sections.length; index += 1) {
      if (index > 0) {
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(sections[index]);
    }
    return widgets;
  }

  int _completedPrayerStreak() {
    final today = DateUtils.dateOnly(_trustedNow());
    var streak = 0;

    for (var daysBack = 0; daysBack < 365; daysBack += 1) {
      final date = today.subtract(Duration(days: daysBack));
      final summary = widget.preferences.dailyPrayerScoreSummary(date);
      if (summary.completedCount >= 5) {
        streak += 1;
        continue;
      }

      if (daysBack == 0 && summary.completedCount > 0) {
        continue;
      }

      break;
    }

    return streak;
  }

  String _quranProgressLabel() {
    return 'سورة ${widget.preferences.quranLastSurah}، آية ${widget.preferences.quranLastAyah}';
  }

  String _adhkarProgressLabel() {
    final completedCount = widget.preferences.adhkarCompleted.length;
    final favoritesCount = widget.preferences.adhkarFavorites.length;
    if (completedCount == 0 && favoritesCount == 0) {
      return 'ابدأ ورد الأذكار اليوم';
    }
    if (favoritesCount > 0) {
      return '$completedCount مكتمل، $favoritesCount مفضلة';
    }
    return '$completedCount ذكر مكتمل';
  }

  String _rakaatLabel(int rakaat) {
    return rakaat > 0 ? '$rakaat ركعة' : 'لا ركعات';
  }

  String _qasrGuideBody(PrayerGuide guide) {
    if (guide.prayerKey == 'sunrise') {
      return [
        '- الشروق وقت معلوم وليس صلاة مفروضة.',
        '- صلاة الضحى تبدأ بعد ارتفاع الشمس بوقت يسير، وتصلى ركعتين أو أكثر.',
        '- لا يوجد قصر مرتبط بوقت الشروق لأنه ليس فرضا يوميا.',
      ].join('\n');
    }

    if (guide.fardRakaat == 4) {
      return [
        '- القصر رخصة للمسافر في الصلاة الرباعية فقط.',
        '- ${guide.prayerName} تصلى ركعتين بدلا من أربع عند تحقق شروط السفر.',
        '- الجمع والقصر لهما تفاصيل فقهية، فارجع لأهل العلم عند اختلاف حالتك.',
      ].join('\n');
    }

    return [
      '- القصر لا يكون في ${guide.prayerName} لأنها ليست صلاة رباعية.',
      '- تصلى كما هي، مع مراعاة وقتها وحالك في السفر.',
      '- عند وجود عذر أو سفر طويل راجع فتوى موثوقة تناسب حالتك.',
    ].join('\n');
  }
}

class _SalatiPrayerHeader extends StatelessWidget {
  const _SalatiPrayerHeader({
    required this.times,
    required this.info,
    required this.prayerTimeLabel,
    required this.countdownLabel,
    required this.dateLabel,
    required this.serverClockAvailable,
    required this.onRefreshTap,
  });

  final DailyPrayerTimes times;
  final PrayerTimeInfo info;
  final String prayerTimeLabel;
  final String countdownLabel;
  final String dateLabel;
  final bool serverClockAvailable;
  final VoidCallback onRefreshTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = times.locationLabel.isEmpty
        ? 'موقعك الحالي'
        : times.locationLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F78BD),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F78BD).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      serverClockAvailable ? 'وقت موثوق من الخادم' : dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تحديث المواقيت',
                onPressed: onRefreshTap,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'الصلاة القادمة',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  info.nextPrayer.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                prayerTimeLabel,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              children: [
                Text(
                  countdownLabel,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'متبقي حتى ${info.nextPrayer.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrayerWeekStrip(date: times.entries.first.time),
        ],
      ),
    );
  }
}

class _PrayerWeekStrip extends StatelessWidget {
  const _PrayerWeekStrip({required this.date});

  final DateTime date;

  static const _days = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  @override
  Widget build(BuildContext context) {
    final start = date.subtract(Duration(days: date.weekday % 7));

    return Row(
      children: List.generate(7, (index) {
        final day = start.add(Duration(days: index));
        final selected = _sameDay(day, date);
        return Expanded(
          child: Container(
            height: 54,
            margin: EdgeInsetsDirectional.only(end: index == 6 ? 0 : 6),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _days[index],
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF2F78BD)
                        : Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: selected ? const Color(0xFF2F78BD) : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _PrayerFeatureGrid extends StatelessWidget {
  const _PrayerFeatureGrid({
    required this.registerPrayerLabel,
    required this.onRegisterTap,
    required this.onQuranTap,
    required this.onAdhkarTap,
    required this.onSettingsTap,
  });

  final String? registerPrayerLabel;
  final VoidCallback? onRegisterTap;
  final VoidCallback onQuranTap;
  final VoidCallback onAdhkarTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _PrayerFeatureTile(
          icon: Icons.check_circle_outline_rounded,
          title: registerPrayerLabel == null
              ? 'تسجيل الصلاة'
              : 'تسجيل $registerPrayerLabel',
          color: const Color(0xFF1E9D68),
          onTap: onRegisterTap,
        ),
        _PrayerFeatureTile(
          icon: Icons.auto_stories_outlined,
          title: 'القرآن',
          color: const Color(0xFF2F78BD),
          onTap: onQuranTap,
        ),
        _PrayerFeatureTile(
          icon: Icons.menu_book_outlined,
          title: 'الأذكار',
          color: const Color(0xFFE3A21A),
          onTap: onAdhkarTap,
        ),
        _PrayerFeatureTile(
          icon: Icons.tune_rounded,
          title: 'الإعدادات',
          color: const Color(0xFF7E57C2),
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class _PrayerFeatureTile extends StatelessWidget {
  const _PrayerFeatureTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6EEF7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerDashboardSkeleton extends StatelessWidget {
  const _PrayerDashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: const [
        _SkeletonBlock(height: 256, radius: 32),
        SizedBox(height: 12),
        _SkeletonBlock(height: 146, radius: 28),
        SizedBox(height: 12),
        _SkeletonBlock(height: 360, radius: 28),
        SizedBox(height: 12),
        _SkeletonBlock(height: 170, radius: 28),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: SizedBox(height: height),
    );
  }
}

class _GlobalDashboardMessageCard extends StatelessWidget {
  const _GlobalDashboardMessageCard({
    required this.message,
    required this.accent,
  });

  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: accent.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.campaign_outlined, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTouchLockOverlay extends StatelessWidget {
  const _PrayerTouchLockOverlay({
    required this.prayerLabel,
    required this.remainingLabel,
    required this.tapCount,
    required this.requiredTaps,
    required this.onTap,
  });

  final String prayerLabel;
  final String remainingLabel;
  final int tapCount;
  final int requiredTaps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remainingTaps = (requiredTaps - tapCount).clamp(0, requiredTaps);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_clock_outlined,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'قفل اللمس قبل صلاة $prayerLabel',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المتبقي: $remainingLabel',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        remainingTaps == 0
                            ? 'جارٍ إيقاف القفل...'
                            : 'اضغط $remainingTaps مرات لإيقاف قفل اللمس.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPrayerHeroCardV2 extends StatelessWidget {
  const _PrimaryPrayerHeroCardV2({
    required this.prayer,
    required this.guide,
    required this.urgency,
    required this.countdownLabel,
    required this.state,
    required this.onCardTap,
    required this.onGuideTap,
    required this.onSegmentTap,
    this.registerPrayerLabel,
    this.onRegisterTap,
  });

  final PrayerTimeEntry prayer;
  final PrayerGuide guide;
  final _PrayerUrgency urgency;
  final String countdownLabel;
  final _PrayerCheckState? state;
  final String? registerPrayerLabel;
  final VoidCallback onCardTap;
  final VoidCallback onGuideTap;
  final VoidCallback? onRegisterTap;
  final Future<void> Function(PrayerGuide guide, _PrayerSegment segment)
  onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = PrayerExperienceService().visualStyleFor(prayer.key);
    final statusLabel = switch (state) {
      _PrayerCheckState.prayed => 'تم تسجيلها',
      _PrayerCheckState.prayedWithNawafil => 'تم تسجيلها مع النوافل',
      _PrayerCheckState.missed => 'مسجلة فائتة',
      null => 'الصلاة التالية',
    };

    return Semantics(
      button: true,
      label: 'الصلاة التالية ${prayer.label}',
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(32),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: urgency.accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: urgency.accent.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _UrgencyBadge(urgency: urgency),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'شرح الصلاة',
                    onPressed: onGuideTap,
                    icon: const Icon(Icons.menu_book_outlined),
                    style: IconButton.styleFrom(
                      foregroundColor: urgency.foreground,
                      backgroundColor: urgency.background,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prayer.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      urgency.background,
                      style.highlightColor.withValues(alpha: 0.10),
                    ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      countdownLabel,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: urgency.foreground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PrayerHeroSegmentChipV2(
                    title: 'قبل',
                    value: guide.beforeRakaat,
                    accent: urgency.accent,
                    onTap: () => onSegmentTap(guide, _PrayerSegment.before),
                  ),
                  _PrayerHeroSegmentChipV2(
                    title: 'الفرض',
                    value: guide.fardRakaat,
                    accent: urgency.accent,
                    onTap: () => onSegmentTap(guide, _PrayerSegment.fard),
                  ),
                  _PrayerHeroSegmentChipV2(
                    title: 'بعد',
                    value: guide.afterRakaat,
                    accent: urgency.accent,
                    onTap: () => onSegmentTap(guide, _PrayerSegment.after),
                  ),
                ],
              ),
              if (onRegisterTap != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRegisterTap,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      registerPrayerLabel == null
                          ? 'تسجيل الصلاة الحالية'
                          : 'تسجيل صلاة $registerPrayerLabel',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: urgency.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency});

  final _PrayerUrgency urgency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: urgency.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: urgency.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            urgency.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: urgency.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerHeroSegmentChipV2 extends StatelessWidget {
  const _PrayerHeroSegmentChipV2({
    required this.title,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final int value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element, unused_element_parameter
class _PrimaryPrayerHeroCardLegacy extends StatelessWidget {
  const _PrimaryPrayerHeroCardLegacy({
    required this.prayer,
    required this.guide,
    required this.urgency,
    required this.prayerTimeLabel,
    required this.shortRemainingLabel,
    required this.countdownLabel,
    required this.countdownCaption,
    required this.state,
    required this.onCardTap,
    required this.onGuideTap,
    required this.onSegmentTap,
    // ignore: unused_element_parameter
    this.onRegisterTap,
  });

  final PrayerTimeEntry prayer;
  final PrayerGuide guide;
  final _PrayerUrgency urgency;
  final String prayerTimeLabel;
  final String shortRemainingLabel;
  final String countdownLabel;
  final String countdownCaption;
  final _PrayerCheckState? state;
  final VoidCallback onCardTap;
  final VoidCallback onGuideTap;
  final VoidCallback? onRegisterTap;
  final Future<void> Function(PrayerGuide guide, _PrayerSegment segment)
  onSegmentTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = PrayerExperienceService().visualStyleFor(prayer.key);
    final (statusLabel, statusColor) = switch (state) {
      _PrayerCheckState.prayed => ('تم تسجيل الفرض', Colors.green.shade100),
      _PrayerCheckState.prayedWithNawafil => (
        'تم تسجيل الفرض والنوافل',
        Colors.teal.shade100,
      ),
      _PrayerCheckState.missed => ('تم تسجيلها فائتة', Colors.red.shade100),
      null => ('بانتظار التسجيل', Colors.white.withAlpha(38)),
    };

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [style.startColor, style.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -6,
              end: -2,
              child: Icon(
                style.icon,
                size: 92,
                color: style.highlightColor.withAlpha(52),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        prayer.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: onGuideTap,
                      icon: const Icon(Icons.menu_book_outlined),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withAlpha(24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  countdownLabel,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countdownCaption,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(228),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PrayerHeroSegmentChip(
                      title: 'قبل',
                      value: guide.beforeRakaat,
                      onTap: () => onSegmentTap(guide, _PrayerSegment.before),
                    ),
                    _PrayerHeroSegmentChip(
                      title: 'الفرض',
                      value: guide.fardRakaat,
                      onTap: () => onSegmentTap(guide, _PrayerSegment.fard),
                    ),
                    _PrayerHeroSegmentChip(
                      title: 'بعد',
                      value: guide.afterRakaat,
                      onTap: () => onSegmentTap(guide, _PrayerSegment.after),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withAlpha(190),
                        ),
                      ),
                    ),
                    if (onRegisterTap != null)
                      FilledButton(
                        onPressed: onRegisterTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: style.startColor,
                        ),
                        child: const Text('تسجيل الصلاة'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerHeroSegmentChip extends StatelessWidget {
  const _PrayerHeroSegmentChip({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withAlpha(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withAlpha(220),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerInteractionSheet extends StatelessWidget {
  const _PrayerInteractionSheet({
    required this.prayer,
    required this.guide,
    required this.currentState,
  });

  final PrayerTimeEntry prayer;
  final PrayerGuide guide;
  final _PrayerCheckState? currentState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalRakaat =
        guide.beforeRakaat + guide.fardRakaat + guide.afterRakaat;
    final stateText = switch (currentState) {
      _PrayerCheckState.prayed => 'مسجلة كـ صليت الفرض',
      _PrayerCheckState.prayedWithNawafil => 'مسجلة كـ صليت الفرض والنوافل',
      _PrayerCheckState.missed => 'مسجلة كـ لم أصل',
      null => 'لم تسجل بعد',
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prayer.label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text('الركعات: $totalRakaat - $stateText'),
            const SizedBox(height: 16),
            _PrayerStructureChips(guide: guide),
            const SizedBox(height: 20),
            Text(
              'كيف تريد تسجيل هذه الصلاة؟',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(_PrayerCheckState.prayed);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('الفرض'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(_PrayerCheckState.prayedWithNawafil);
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('الفرض + النوافل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(_PrayerCheckState.missed);
                },
                icon: const Icon(Icons.do_not_disturb_on_outlined),
                label: const Text('لم أصل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerStructureChips extends StatelessWidget {
  const _PrayerStructureChips({required this.guide});

  final PrayerGuide guide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StructureChip(label: 'قبل', value: guide.beforeRakaat),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StructureChip(label: 'فرض', value: guide.fardRakaat),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StructureChip(label: 'بعد', value: guide.afterRakaat),
        ),
      ],
    );
  }
}

class _StructureChip extends StatelessWidget {
  const _StructureChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrayerQuickActionsCard extends StatelessWidget {
  const _PrayerQuickActionsCard({
    required this.registerPrayerLabel,
    required this.notificationsEnabled,
    required this.widgetsEnabled,
    required this.onRegisterTap,
    required this.onSettingsTap,
    required this.onWidgetRefreshTap,
    required this.onWidgetPreviewTap,
    required this.onQuranTap,
    required this.onAdhkarTap,
  });

  final String? registerPrayerLabel;
  final bool notificationsEnabled;
  final bool widgetsEnabled;
  final VoidCallback? onRegisterTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onWidgetRefreshTap;
  final VoidCallback onWidgetPreviewTap;
  final VoidCallback onQuranTap;
  final VoidCallback onAdhkarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: theme.dividerColor.withAlpha(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'اختصارات اليوم',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusDot(
                  label: notificationsEnabled ? 'الأذان مفعل' : 'الأذان متوقف',
                  active: notificationsEnabled,
                ),
                const SizedBox(width: 8),
                _StatusDot(
                  label: widgetsEnabled ? 'الودجت مفعل' : 'الودجت غير مفعل',
                  active: widgetsEnabled,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 390
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickActionTile(
                      width: width,
                      icon: Icons.check_circle_outline_rounded,
                      title: registerPrayerLabel == null
                          ? 'لا توجد صلاة للتسجيل'
                          : 'تسجيل $registerPrayerLabel',
                      subtitle: 'حفظ حالة الصلاة',
                      accent: const Color(0xFF1F9D62),
                      onTap: onRegisterTap,
                    ),
                    _QuickActionTile(
                      width: width,
                      icon: Icons.tune_rounded,
                      title: 'الإعدادات',
                      subtitle: 'الأذان والموقع',
                      accent: theme.colorScheme.primary,
                      onTap: onSettingsTap,
                    ),
                    _QuickActionTile(
                      width: width,
                      icon: Icons.dashboard_customize_outlined,
                      title: 'معاينة الودجات',
                      subtitle: 'الشكل والتخصيص',
                      accent: const Color(0xFF8B5CF6),
                      onTap: onWidgetPreviewTap,
                    ),
                    _QuickActionTile(
                      width: width,
                      icon: Icons.sync_rounded,
                      title: 'تحديث الودجت',
                      subtitle: 'إرسال البيانات الآن',
                      accent: const Color(0xFFF5A524),
                      onTap: onWidgetRefreshTap,
                    ),
                    _QuickActionTile(
                      width: width,
                      icon: Icons.auto_stories_outlined,
                      title: 'القرآن',
                      subtitle: 'متابعة الورد',
                      accent: const Color(0xFF4F46E5),
                      onTap: onQuranTap,
                    ),
                    _QuickActionTile(
                      width: width,
                      icon: Icons.menu_book_outlined,
                      title: 'الأذكار',
                      subtitle: 'ورد الصباح والمساء',
                      accent: const Color(0xFF0A7C66),
                      onTap: onAdhkarTap,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1F9D62) : const Color(0xFFE5484D);
    return Tooltip(
      message: label,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({
    required this.title,
    required this.accent,
    required this.child,
  });

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NextPrayerWidgetPreview extends StatelessWidget {
  const _NextPrayerWidgetPreview({
    required this.prayerName,
    required this.timeLabel,
    required this.countdownLabel,
    required this.textScale,
  });

  final String prayerName;
  final String timeLabel;
  final String countdownLabel;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prayerName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize:
                      (theme.textTheme.headlineSmall?.fontSize ?? 24) *
                      textScale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text('المتبقي $countdownLabel'),
            ],
          ),
        ),
        Text(
          timeLabel,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DateWidgetPreview extends StatelessWidget {
  const _DateWidgetPreview({
    required this.gregorianLabel,
    required this.textScale,
  });

  final String gregorianLabel;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تاريخ اليوم',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize:
                      (theme.textTheme.titleLarge?.fontSize ?? 22) * textScale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                gregorianLabel,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrayerTimesWidgetPreview extends StatelessWidget {
  const _PrayerTimesWidgetPreview({
    required this.times,
    required this.activePrayerKey,
    required this.showAllPrayers,
    required this.textScale,
  });

  final DailyPrayerTimes times;
  final String? activePrayerKey;
  final bool showAllPrayers;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final entries = showAllPrayers
        ? times.entries
        : times.entries
              .where((entry) => entry.key == activePrayerKey)
              .take(1)
              .toList(growable: false);
    final visibleEntries = entries.isEmpty ? times.entries.take(1) : entries;

    return Column(
      children: [
        for (final entry in visibleEntries)
          _PrayerTimePreviewRow(
            entry: entry,
            isActive: entry.key == activePrayerKey,
            textScale: textScale,
          ),
      ],
    );
  }
}

class _PrayerTimePreviewRow extends StatelessWidget {
  const _PrayerTimePreviewRow({
    required this.entry,
    required this.isActive,
    required this.textScale,
  });

  final PrayerTimeEntry entry;
  final bool isActive;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? const Color(0xFF1F9D62)
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFEAF8F0)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontSize:
                    (theme.textTheme.titleSmall?.fontSize ?? 14) * textScale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            TimeOfDay.fromDateTime(entry.time).format(context),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressWidgetPreview extends StatelessWidget {
  const _ProgressWidgetPreview({
    required this.completedPrayersToday,
    required this.totalPoints,
    required this.quranProgress,
    required this.textScale,
  });

  final int completedPrayersToday;
  final double totalPoints;
  final String quranProgress;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ProgressPill(
          label: 'صلوات اليوم',
          value: '$completedPrayersToday/5',
          textScale: textScale,
        ),
        _ProgressPill(
          label: 'النقاط',
          value: totalPoints.toStringAsFixed(0),
          textScale: textScale,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(quranProgress, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.label,
    required this.value,
    required this.textScale,
  });

  final String label;
  final String value;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize:
                  (theme.textTheme.titleLarge?.fontSize ?? 22) * textScale,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetSettingsSection extends StatelessWidget {
  const _WidgetSettingsSection({
    required this.accentColor,
    required this.themeMode,
    required this.textScale,
    required this.showCountdown,
    required this.showAllPrayers,
    required this.onAccentChanged,
    required this.onThemeModeChanged,
    required this.onTextScaleChanged,
    required this.onShowCountdownChanged,
    required this.onShowAllPrayersChanged,
  });

  final String accentColor;
  final String themeMode;
  final double textScale;
  final bool showCountdown;
  final bool showAllPrayers;
  final ValueChanged<String> onAccentChanged;
  final ValueChanged<String> onThemeModeChanged;
  final ValueChanged<double> onTextScaleChanged;
  final ValueChanged<bool> onShowCountdownChanged;
  final ValueChanged<bool> onShowAllPrayersChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const colors = {
      '#1F9D62': Color(0xFF1F9D62),
      '#F5A524': Color(0xFFF5A524),
      '#4F46E5': Color(0xFF4F46E5),
      '#E5484D': Color(0xFFE5484D),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تخصيص الودجت',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: colors.entries
                .map((entry) {
                  final selected = entry.key == accentColor;
                  return InkWell(
                    onTap: () => onAccentChanged(entry.key),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('النظام')),
              ButtonSegment(value: 'light', label: Text('فاتح')),
              ButtonSegment(value: 'dark', label: Text('داكن')),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) => onThemeModeChanged(value.first),
          ),
          const SizedBox(height: 14),
          Text('حجم الخط ${(textScale * 100).round()}%'),
          Slider(
            value: textScale,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            onChanged: onTextScaleChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: showCountdown,
            title: const Text('إظهار العد التنازلي'),
            onChanged: onShowCountdownChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: showAllPrayers,
            title: const Text('إظهار كل مواقيت الصلاة'),
            onChanged: onShowAllPrayersChanged,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.52,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemainingPrayersCard extends StatelessWidget {
  const _RemainingPrayersCard({
    required this.times,
    required this.title,
    required this.qiyamLabel,
    required this.currentPrayerKey,
    required this.nextPrayerKey,
    required this.completedPrayerKeys,
    required this.missedPrayerKeys,
    required this.referenceNow,
    required this.onPrayerTap,
  });

  final DailyPrayerTimes times;
  final String title;
  final String qiyamLabel;
  final String? currentPrayerKey;
  final String? nextPrayerKey;
  final Set<String> completedPrayerKeys;
  final Set<String> missedPrayerKeys;
  final DateTime referenceNow;
  final ValueChanged<PrayerTimeEntry> onPrayerTap;

  @override
  Widget build(BuildContext context) {
    final prayerEntries = times.entries;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...prayerEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RemainingPrayerTileV2(
                  entry: entry,
                  isCurrent: entry.key == currentPrayerKey,
                  isNext: entry.key == nextPrayerKey,
                  isCompleted: completedPrayerKeys.contains(entry.key),
                  isMissed: missedPrayerKeys.contains(entry.key),
                  hasPassed: entry.time.isBefore(referenceNow),
                  canInteract: true,
                  onTap: () => onPrayerTap(entry),
                ),
              );
            }),
            const SizedBox(height: 6),
            _SpecialUpcomingPrayerTile(
              label: 'قيام الليل',
              timeLabel: qiyamLabel,
              subtitle: 'اقتراح مبني على تفضيلك الحالي',
              icon: Icons.nightlight_round,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _RemainingPrayerTileLegacy extends StatelessWidget {
  const _RemainingPrayerTileLegacy({
    required this.entry,
    required this.isCurrent,
    required this.isNext,
    required this.isCompleted,
    required this.isMissed,
    required this.hasPassed,
    required this.canInteract,
    required this.onTap,
  });

  final PrayerTimeEntry entry;
  final bool isCurrent;
  final bool isNext;
  final bool isCompleted;
  final bool isMissed;
  final bool hasPassed;
  final bool canInteract;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? Colors.green
        : isMissed
        ? theme.colorScheme.error
        : isNext
        ? theme.colorScheme.primary
        : isCurrent
        ? theme.colorScheme.secondary
        : entry.key == 'sunrise'
        ? Colors.blueGrey
        : hasPassed
        ? Colors.orange
        : theme.colorScheme.outline;
    final label = isCompleted
        ? 'مكتملة'
        : isMissed
        ? 'لم أصل'
        : isNext
        ? 'القادمة'
        : isCurrent
        ? 'الحالية'
        : entry.key == 'sunrise'
        ? 'الشروق'
        : hasPassed
        ? '-1 عند عدم التسجيل'
        : 'لاحقاً';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(
                isMissed
                    ? Icons.do_not_disturb_on_outlined
                    : entry.key == 'sunrise'
                    ? Icons.wb_sunny_outlined
                    : Icons.access_time_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(TimeOfDay.fromDateTime(entry.time).format(context)),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
            if (canInteract) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemainingPrayerTileV2 extends StatelessWidget {
  const _RemainingPrayerTileV2({
    required this.entry,
    required this.isCurrent,
    required this.isNext,
    required this.isCompleted,
    required this.isMissed,
    required this.hasPassed,
    required this.canInteract,
    required this.onTap,
  });

  final PrayerTimeEntry entry;
  final bool isCurrent;
  final bool isNext;
  final bool isCompleted;
  final bool isMissed;
  final bool hasPassed;
  final bool canInteract;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? const Color(0xFF1F9D62)
        : isMissed
        ? theme.colorScheme.error
        : isNext
        ? const Color(0xFF2F78BD)
        : isCurrent
        ? const Color(0xFFF5A524)
        : entry.key == 'sunrise'
        ? Colors.blueGrey
        : hasPassed
        ? const Color(0xFFE5484D)
        : const Color(0xFF9CA3AF);
    final label = isCompleted
        ? 'مكتملة'
        : isMissed
        ? 'فائتة'
        : isNext
        ? 'الصلاة القادمة'
        : isCurrent
        ? 'حان وقتها'
        : entry.key == 'sunrise'
        ? 'الشروق'
        : hasPassed
        ? 'تحتاج تسجيل'
        : 'قادمة';
    final backgroundColor = isNext || isCurrent
        ? color.withValues(alpha: 0.10)
        : isCompleted
        ? const Color(0xFFEAF8F0)
        : isMissed
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.42)
        : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: backgroundColor,
          border: Border.all(
            color: color.withValues(alpha: isNext || isCurrent ? 0.44 : 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isMissed
                    ? Icons.do_not_disturb_on_outlined
                    : entry.key == 'sunrise'
                    ? Icons.wb_sunny_outlined
                    : Icons.access_time_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1F2937),
                      fontWeight: isNext || isCurrent
                          ? FontWeight.w900
                          : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              TimeOfDay.fromDateTime(entry.time).format(context),
              textDirection: TextDirection.ltr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isNext || isCurrent ? color : const Color(0xFF1F2937),
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (canInteract) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left_rounded,
                color: color.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpecialUpcomingPrayerTile extends StatelessWidget {
  const _SpecialUpcomingPrayerTile({
    required this.label,
    required this.timeLabel,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String timeLabel;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.secondaryContainer.withAlpha(96),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondary.withAlpha(24),
            child: Icon(icon, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            timeLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyResultCard extends StatelessWidget {
  const _DailyResultCard({
    required this.summary,
    required this.streakDays,
    required this.quranProgressLabel,
    required this.adhkarProgressLabel,
    required this.onTap,
  });

  final _PrayerOverviewSummary summary;
  final int streakDays;
  final String quranProgressLabel;
  final String adhkarProgressLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreLabel = summary.score >= 0
        ? '+${summary.score.toStringAsFixed(2)}'
        : summary.score.toStringAsFixed(2);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.insights_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نتيجة اليوم',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('عرض خفيف للتقييم اليومي ثم تفاصيل كل صلاة'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                scoreLabel,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: summary.score >= 0
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ResultChip(label: 'المكتمل ${summary.completedCount}'),
                  _ResultChip(label: 'المفوّت ${summary.missedCount}'),
                  _ResultChip(label: 'غير المسجل ${summary.pendingCount}'),
                  _ResultChip(label: 'سلسلة $streakDays يوم'),
                  _ResultChip(label: quranProgressLabel),
                  _ResultChip(label: adhkarProgressLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrayerReflectionSheet extends StatefulWidget {
  const _PrayerReflectionSheet({
    required this.prompt,
    required this.existingEntry,
    required this.onSubmit,
  });

  final PrayerReflectionPrompt prompt;
  final PrayerReflectionEntry? existingEntry;
  final Future<PrayerReflectionEntry?> Function(Map<String, String> answers)
  onSubmit;

  @override
  State<_PrayerReflectionSheet> createState() => _PrayerReflectionSheetState();
}

class _PrayerReflectionSheetState extends State<_PrayerReflectionSheet> {
  late final TextEditingController _textController;
  final Map<String, String> _answers = <String, String>{};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final textQuestion = widget.prompt.questions
        .where((question) => question.acceptsText)
        .firstOrNull;
    _textController = TextEditingController(
      text:
          widget.existingEntry?.answers
              .firstWhere(
                (answer) => answer.questionId == textQuestion?.id,
                orElse: () => const PrayerReflectionAnswer(
                  questionId: '',
                  question: '',
                  answer: '',
                ),
              )
              .answer ??
          '',
    );

    for (final answer
        in widget.existingEntry?.answers ?? const <PrayerReflectionAnswer>[]) {
      _answers[answer.questionId] = answer.answer;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingEntry = widget.existingEntry;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.prompt.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(widget.prompt.supportingMessage),
            const SizedBox(height: 16),
            if (existingEntry != null)
              _SubmittedReflectionView(entry: existingEntry)
            else ...[
              ...widget.prompt.questions.map(_buildQuestionCard),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                  child: Text(_isSubmitting ? 'جارٍ الحفظ...' : 'حفظ الإجابة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(PrayerReflectionQuestion question) {
    final selectedValue = _answers[question.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.prompt,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.options
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: selectedValue == option,
                        onSelected: (_) {
                          setState(() {
                            _answers[question.id] = option;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            if (question.acceptsText) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(hintText: question.placeholder),
                onChanged: (value) {
                  setState(() {
                    _answers[question.id] = value.trim();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    for (final question in widget.prompt.questions) {
      final answer =
          (question.acceptsText
                  ? _textController.text.trim()
                  : _answers[question.id] ?? '')
              .trim();
      if (answer.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    final answers = <String, String>{};
    for (final question in widget.prompt.questions) {
      answers[question.id] = question.acceptsText
          ? _textController.text.trim()
          : (_answers[question.id] ?? '').trim();
    }

    setState(() {
      _isSubmitting = true;
    });

    final savedEntry = await widget.onSubmit(answers);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (savedEntry == null) {
      return;
    }

    Navigator.of(context).pop();
  }
}

class _SubmittedReflectionView extends StatelessWidget {
  const _SubmittedReflectionView({required this.entry});

  final PrayerReflectionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'تم حفظ إجابتك مسبقًا، وتركناها كما هي بدون تعديل.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'النتيجة وقت الإجابة: ${entry.scoreAtMoment}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        ...entry.answers.map(
          (answer) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    answer.question,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(answer.answer),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
