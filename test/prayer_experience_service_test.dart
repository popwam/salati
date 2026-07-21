import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salati/features/prayer/models/daily_prayer_times.dart';
import 'package:salati/features/prayer/models/qiyam_preference.dart';
import 'package:salati/features/prayer/services/prayer_experience_service.dart';

void main() {
  const service = PrayerExperienceService();

  DailyPrayerTimes buildDailyTimes() {
    return DailyPrayerTimes(
      locationLabel: 'مصر - القاهرة',
      calculationLabel: 'egyptian',
      entries: [
        PrayerTimeEntry(
          key: 'fajr',
          label: 'الفجر',
          time: DateTime(2026, 4, 26, 4, 15),
        ),
        PrayerTimeEntry(
          key: 'sunrise',
          label: 'الشروق',
          time: DateTime(2026, 4, 26, 5, 40),
        ),
        PrayerTimeEntry(
          key: 'dhuhr',
          label: 'الظهر',
          time: DateTime(2026, 4, 26, 12, 1),
        ),
        PrayerTimeEntry(
          key: 'asr',
          label: 'العصر',
          time: DateTime(2026, 4, 26, 15, 30),
        ),
        PrayerTimeEntry(
          key: 'maghrib',
          label: 'المغرب',
          time: DateTime(2026, 4, 26, 18, 22),
        ),
        PrayerTimeEntry(
          key: 'isha',
          label: 'العشاء',
          time: DateTime(2026, 4, 26, 19, 45),
        ),
      ],
    );
  }

  test('next prayer calculation returns maghrib in late afternoon', () {
    final info = service.buildPrayerTimeInfo(
      dailyTimes: buildDailyTimes(),
      qiyamPreference: QiyamPreference.lastThird,
      now: DateTime(2026, 4, 26, 17, 2),
    );

    expect(info.nextPrayer.key, 'maghrib');
    expect(info.guide.prayerKey, 'maghrib');
  });

  test('prayer visual style mapping returns sunset palette for maghrib', () {
    final style = service.visualStyleFor('maghrib');

    expect(style.key, 'maghrib');
    expect(style.icon, Icons.sunny_snowing);
  });

  test('qiyam segment calculation returns later time for last third', () {
    final suggestion = service.calculateQiyamSuggestion(
      dailyTimes: buildDailyTimes(),
      preference: QiyamPreference.lastThird,
    );

    expect(suggestion.isApproximate, isTrue);
    expect(suggestion.suggestedAt.hour, greaterThanOrEqualTo(0));
  });

  test('prayer guide lookup returns general reading guidance for maghrib', () {
    final guide = service.guideFor('maghrib');

    expect(guide.fardRakaat, 3);
    expect(guide.recitationGuidance.first, contains('الفاتحة'));
    expect(guide.notes.last, contains('إرشادات عامة'));
    expect(guide.beforeNote, 'لا سنة قبلها');
  });

  test('reflection prompt returns multiple supportive questions', () {
    final prompt = service.reflectionPromptForMissedPrayer(
      'maghrib',
      seedTime: DateTime(2026, 4, 26, 17),
    );

    expect(prompt, isNotNull);
    expect(prompt!.questions.length, inInclusiveRange(3, 5));
    expect(service.reflectionQuestionPool.length, 20);
    expect(
      prompt.questions.map((question) => question.id).toSet().length,
      prompt.questions.length,
    );
  });
}
