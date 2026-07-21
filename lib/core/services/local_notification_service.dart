import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  static final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  static String? _pendingPayload;

  static Stream<String> get notificationPayloads => _payloadController.stream;

  static String? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    _emitPayload(response.payload);
  }

  static void _emitPayload(String? payload) {
    final normalized = payload?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    _pendingPayload = normalized;
    if (!_payloadController.isClosed) {
      _payloadController.add(normalized);
    }
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _emitPayload(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return false;
    }

    try {
      await initialize();
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        final notificationsAllowed =
            await androidImplementation.requestNotificationsPermission() ??
            false;
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } on PlatformException catch (error) {
          debugPrint('[Notifications] exact alarm permission skipped: $error');
        }
        return notificationsAllowed;
      }

      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        return await iosImplementation.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      debugPrint('[Notifications] permission request failed: $error');
    }

    return false;
  }

  @override
  Future<void> cancelPrayerNotifications() async {
    if (kIsWeb) {
      return;
    }

    await _plugin.cancelAll();
  }

  @override
  Future<void> showOngoingPrayerStatus({
    required String title,
    required String body,
    String? nextPrayerName,
    DateTime? nextPrayerTime,
    Duration? remaining,
  }) async {
    if (kIsWeb) {
      return;
    }

    final prayerName = nextPrayerName?.trim();
    final resolvedTitle = prayerName == null || prayerName.isEmpty
        ? title
        : 'Next prayer: $prayerName';
    final resolvedBody = nextPrayerTime == null
        ? body
        : [
            'Time: ${_formatClock(nextPrayerTime)}',
            if (remaining != null) 'Remaining: ${_formatDuration(remaining)}',
          ].join('  ');

    await initialize();
    await _plugin.show(
      id: 88001,
      title: resolvedTitle,
      body: resolvedBody,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'salati_prayer_status_v1',
          'Prayer Status',
          channelDescription: 'حالة الصلاة القادمة من صلاتي',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          showWhen: false,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: 'open:prayer',
    );
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration value) {
    final clamped = value.isNegative ? Duration.zero : value;
    final hours = clamped.inHours;
    final minutes = clamped.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  @override
  Future<void> schedulePrayerReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? androidSound,
    String? payload,
    bool useAlarmAudio = true,
  }) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    final scheduleDate = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduleDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    try {
      await _scheduleAndroidPrayerNotification(
        id: id,
        title: title,
        body: body,
        scheduleDate: scheduleDate,
        scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        androidSound: androidSound,
        payload: payload,
        useAlarmAudio: useAlarmAudio,
      );
    } on PlatformException catch (error) {
      debugPrint('[Notifications] exact schedule failed: $error');
      try {
        await _scheduleAndroidPrayerNotification(
          id: id,
          title: title,
          body: body,
          scheduleDate: scheduleDate,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          androidSound: androidSound,
          payload: payload,
          useAlarmAudio: useAlarmAudio,
        );
      } catch (fallbackError) {
        debugPrint('[Notifications] inexact schedule failed: $fallbackError');
      }
    } catch (error) {
      debugPrint('[Notifications] schedule failed: $error');
    }
  }

  Future<void> _scheduleAndroidPrayerNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduleDate,
    required AndroidScheduleMode scheduleMode,
    required String? androidSound,
    required String? payload,
    required bool useAlarmAudio,
  }) async {
    final sound = _normalizedRawSound(androidSound);
    final channelId = sound == null
        ? useAlarmAudio
              ? 'salati_reminders_v3_default_alarm'
              : 'salati_reminders_v3_default_notification'
        : 'salati_reminders_v3_$sound';
    final channelName = switch (sound) {
      'adhan_default' || 'adhan_fajr_default' => 'Adhan Reminders',
      'azkar_morning' || 'azkar_evening' => 'Adhkar Reminders',
      _ => 'Salati Reminders',
    };
    final audioUsage = useAlarmAudio
        ? AudioAttributesUsage.alarm
        : AudioAttributesUsage.notification;
    final category = useAlarmAudio
        ? AndroidNotificationCategory.alarm
        : AndroidNotificationCategory.reminder;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduleDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'تنبيهات صلاتي',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          category: category,
          audioAttributesUsage: audioUsage,
          sound: sound == null
              ? null
              : RawResourceAndroidNotificationSound(sound),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          sound: sound == null ? null : '$sound.mp3',
          threadIdentifier: 'salati_reminders',
        ),
      ),
      androidScheduleMode: scheduleMode,
      payload: payload,
    );
  }

  String? _normalizedRawSound(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    const allowedSounds = {
      'adhan_default',
      'adhan_fajr_default',
      'azkar_morning',
      'azkar_evening',
    };
    return allowedSounds.contains(normalized) ? normalized : null;
  }
}
