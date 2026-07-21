import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/models/points_config.dart';
import 'package:salati/core/services/points_award_service.dart';

void main() {
  test('awardPrayer sends server-calculated callable payload', () async {
    Map<String, dynamic>? captured;
    final service = PointsAwardService(
      firebaseConfigured: true,
      callable: (data) async {
        captured = data;
        return {
          'awarded': true,
          'amount': 10,
          'before': 4,
          'after': 14,
          'ledgerId': 'prayer:2026-04-28:fajr:onTime',
          'duplicate': false,
          'message': 'Points awarded.',
        };
      },
    );

    final result = await service.awardPrayer(
      prayerKey: 'Fajr',
      date: DateTime(2026, 4, 28),
      result: PrayerPointResult.onTime,
      prayerName: 'Fajr',
    );

    expect(result.applied, isTrue);
    expect(result.delta, 10);
    expect(result.after, 14);
    expect(captured, {
      'source': 'prayer',
      'eventId': 'fajr',
      'status': 'onTime',
      'dateKey': '2026-04-28',
      'prayerName': 'Fajr',
    });
    expect(captured!.containsKey('uid'), isFalse);
    expect(captured!.containsKey('amount'), isFalse);
    expect(captured!.containsKey('points'), isFalse);
    expect(captured!.containsKey('rules'), isFalse);
  });

  test('awardPrayer maps duplicate callable responses gracefully', () async {
    final service = PointsAwardService(
      firebaseConfigured: true,
      callable: (_) async {
        return {
          'awarded': false,
          'amount': 5,
          'before': 10,
          'after': 15,
          'ledgerId': 'prayer:2026-04-28:fajr:late',
          'duplicate': true,
          'message': 'Points were already awarded for this event.',
        };
      },
    );

    final result = await service.awardPrayer(
      prayerKey: 'fajr',
      date: DateTime(2026, 4, 28),
      result: PrayerPointResult.late,
    );

    expect(result.applied, isFalse);
    expect(result.duplicate, isTrue);
    expect(result.reason, 'duplicate-ledger');
    expect(result.delta, 5);
    expect(result.after, 15);
  });

  test('awardAdhkarCompletion sends safe callable payload', () async {
    Map<String, dynamic>? captured;
    final service = PointsAwardService(
      firebaseConfigured: true,
      callable: (data) async {
        captured = data;
        return {
          'awarded': true,
          'amount': 10,
          'before': 20,
          'after': 30,
          'ledgerId': 'adhkar:2026-04-28:morning',
          'duplicate': false,
          'message': 'Points awarded.',
        };
      },
    );

    final result = await service.awardAdhkarCompletion(
      categoryId: 'Morning',
      date: DateTime(2026, 4, 28),
      title: 'Morning adhkar',
    );

    expect(result.applied, isTrue);
    expect(captured, {
      'source': 'adhkar',
      'eventId': 'morning',
      'dateKey': '2026-04-28',
      'title': 'Morning adhkar',
    });
    expect(captured!.containsKey('uid'), isFalse);
    expect(captured!.containsKey('amount'), isFalse);
    expect(captured!.containsKey('plan'), isFalse);
    expect(captured!.containsKey('rules'), isFalse);
  });

  test('awardDuaCompletion sends safe callable payload', () async {
    Map<String, dynamic>? captured;
    final service = PointsAwardService(
      firebaseConfigured: true,
      callable: (data) async {
        captured = data;
        return {
          'awarded': true,
          'amount': 10,
          'before': 5,
          'after': 15,
          'ledgerId': 'dua:2026-04-28:daily',
          'duplicate': false,
          'message': 'Points awarded.',
        };
      },
    );

    final result = await service.awardDuaCompletion(
      categoryId: 'Daily',
      date: DateTime(2026, 4, 28),
      title: 'Daily duas',
    );

    expect(result.applied, isTrue);
    expect(captured, {
      'source': 'dua',
      'eventId': 'daily',
      'dateKey': '2026-04-28',
      'title': 'Daily duas',
    });
    expect(captured!.containsKey('uid'), isFalse);
    expect(captured!.containsKey('amount'), isFalse);
    expect(captured!.containsKey('plan'), isFalse);
    expect(captured!.containsKey('rules'), isFalse);
  });

  test('awardQiyamCompletion sends safe callable payload', () async {
    Map<String, dynamic>? captured;
    final service = PointsAwardService(
      firebaseConfigured: true,
      callable: (data) async {
        captured = data;
        return {
          'awarded': true,
          'amount': 50,
          'before': 7,
          'after': 57,
          'ledgerId': 'qiyam:2026-04-28:night',
          'duplicate': false,
          'message': 'Points awarded.',
        };
      },
    );

    final result = await service.awardQiyamCompletion(
      date: DateTime(2026, 4, 28),
      title: 'Qiyam completion',
    );

    expect(result.applied, isTrue);
    expect(result.delta, 50);
    expect(captured, {
      'source': 'qiyam',
      'eventId': 'night',
      'dateKey': '2026-04-28',
      'title': 'Qiyam completion',
    });
    expect(captured!.containsKey('uid'), isFalse);
    expect(captured!.containsKey('amount'), isFalse);
    expect(captured!.containsKey('plan'), isFalse);
    expect(captured!.containsKey('rules'), isFalse);
  });
}
