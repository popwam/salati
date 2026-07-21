import 'package:cloud_functions/cloud_functions.dart';

import '../models/points_config.dart';

typedef PointsAwardCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

class PointsAwardResult {
  const PointsAwardResult({
    required this.applied,
    required this.delta,
    this.before,
    this.after,
    this.ledgerId,
    this.duplicate = false,
    this.message = '',
    this.reason = '',
  });

  final bool applied;
  final int delta;
  final int? before;
  final int? after;
  final String? ledgerId;
  final bool duplicate;
  final String message;
  final String reason;
}

class PointsAwardService {
  PointsAwardService({
    required bool firebaseConfigured,
    PointsAwardCallable? callable,
  }) : _firebaseConfigured = firebaseConfigured,
       _callable = callable ?? _defaultCallable;

  final bool _firebaseConfigured;
  final PointsAwardCallable _callable;

  Future<PointsAwardResult> awardPrayer({
    required String prayerKey,
    required DateTime date,
    required PrayerPointResult result,
    String? prayerName,
  }) async {
    final normalizedPrayerKey = prayerKey.trim().toLowerCase();
    if (!_firebaseConfigured || normalizedPrayerKey.isEmpty) {
      return const PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'missing-firebase-or-event',
        message: 'Firebase is not configured or prayer key is missing.',
      );
    }

    try {
      final response = await _callable({
        'source': 'prayer',
        'eventId': normalizedPrayerKey,
        'status': _statusName(result),
        'dateKey': _dateStamp(date),
        if (prayerName != null && prayerName.trim().isNotEmpty)
          'prayerName': prayerName.trim(),
      });
      return _resultFromResponse(response);
    } on FirebaseFunctionsException catch (error) {
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: error.code,
        message: error.message ?? 'Points award request failed.',
      );
    } catch (error) {
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'unknown-error',
        message: error.toString(),
      );
    }
  }

  Future<PointsAwardResult> awardAdhkarCompletion({
    required String categoryId,
    required DateTime date,
    String? title,
  }) {
    return _awardCompletion(
      source: 'adhkar',
      eventId: categoryId,
      date: date,
      title: title,
    );
  }

  Future<PointsAwardResult> awardDuaCompletion({
    required String categoryId,
    required DateTime date,
    String? title,
  }) {
    return _awardCompletion(
      source: 'dua',
      eventId: categoryId,
      date: date,
      title: title,
    );
  }

  Future<PointsAwardResult> awardQiyamCompletion({
    required DateTime date,
    String eventId = 'night',
    String? title,
  }) {
    return _awardCompletion(
      source: 'qiyam',
      eventId: eventId,
      date: date,
      title: title,
    );
  }

  Future<PointsAwardResult> _awardCompletion({
    required String source,
    required String eventId,
    required DateTime date,
    String? title,
  }) async {
    final normalizedEventId = eventId.trim().toLowerCase();
    if (!_firebaseConfigured || normalizedEventId.isEmpty) {
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'missing-firebase-or-event',
        message: 'Firebase is not configured or $source event is missing.',
      );
    }

    try {
      final response = await _callable({
        'source': source,
        'eventId': normalizedEventId,
        'dateKey': _dateStamp(date),
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      });
      return _resultFromResponse(response);
    } on FirebaseFunctionsException catch (error) {
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: error.code,
        message: error.message ?? 'Points award request failed.',
      );
    } catch (error) {
      return PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'unknown-error',
        message: error.toString(),
      );
    }
  }

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('awardPoints');
    final result = await callable.call<Map<String, dynamic>>(data);
    return result.data;
  }

  static PointsAwardResult _resultFromResponse(Map<String, dynamic> response) {
    final duplicate = _boolValue(response['duplicate']);
    return PointsAwardResult(
      applied: _boolValue(response['awarded']),
      delta: _intValue(response['amount']) ?? 0,
      before: _intValue(response['before']),
      after: _intValue(response['after']),
      ledgerId: _stringValue(response['ledgerId']),
      duplicate: duplicate,
      message: _stringValue(response['message']) ?? '',
      reason: duplicate ? 'duplicate-ledger' : '',
    );
  }

  static String _statusName(PrayerPointResult result) {
    return switch (result) {
      PrayerPointResult.onTime => 'onTime',
      PrayerPointResult.late => 'late',
      PrayerPointResult.missed => 'missed',
    };
  }

  static String _dateStamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static bool _boolValue(dynamic value) {
    return value == true;
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
