import 'dart:math';

import 'package:flutter/material.dart';

import '../models/daily_prayer_times.dart';
import '../models/prayer_guide.dart';
import '../models/prayer_reflection_prompt.dart';
import '../models/prayer_time_info.dart';
import '../models/prayer_visual_style.dart';
import '../models/qiyam_preference.dart';

class PrayerExperienceService {
  const PrayerExperienceService();

  static const List<String> _obligatoryPrayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static const List<PrayerReflectionQuestion> _reflectionQuestionPool = [
    PrayerReflectionQuestion(
      id: 'reason_busy',
      prompt: 'ما أكثر شيء شغلك وقت الصلاة؟',
      options: ['عمل أو دراسة', 'مشوار', 'انشغال في البيت'],
    ),
    PrayerReflectionQuestion(
      id: 'reason_tired',
      prompt: 'هل كان التعب سبباً في التأخير؟',
      options: ['نعم', 'قليلاً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'reason_sleep',
      prompt: 'هل غلبك النوم أو النعاس؟',
      options: ['نعم', 'كنت مرهقاً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'reason_forget',
      prompt: 'هل نسيت الوقت؟',
      options: ['نعم', 'تذكرت متأخراً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'place_ready',
      prompt: 'هل كان المكان مناسباً للصلاة؟',
      options: ['نعم', 'لم يكن مناسباً', 'كنت خارج البيت'],
    ),
    PrayerReflectionQuestion(
      id: 'wudu_ready',
      prompt: 'هل كان الوضوء متاحاً بسهولة؟',
      options: ['نعم', 'احتجت وقتاً', 'لم يكن سهلاً'],
    ),
    PrayerReflectionQuestion(
      id: 'intention',
      prompt: 'هل كنت ناوياً تصلي ثم تأخرت؟',
      options: ['نعم', 'إلى حد ما', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'reminder_helped',
      prompt: 'هل كان وجود تذكير سيساعدك؟',
      options: ['نعم', 'ربما', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'next_step_time',
      prompt: 'ما أفضل خطوة صغيرة للمرّة القادمة؟',
      options: ['تحديد وقت واضح', 'الوضوء مبكراً', 'اختيار مكان ثابت'],
    ),
    PrayerReflectionQuestion(
      id: 'next_step_environment',
      prompt: 'ما الذي يجعل الصلاة أسهل في يومك؟',
      options: ['هدوء أكثر', 'وقت أبكر', 'تقليل الانشغال'],
    ),
    PrayerReflectionQuestion(
      id: 'emotion',
      prompt: 'كيف كان شعورك بعد فوات الصلاة؟',
      options: ['ندم هادئ', 'ضيق', 'رغبة في التعويض'],
    ),
    PrayerReflectionQuestion(
      id: 'pattern',
      prompt: 'هل يتكرر هذا مع نفس الوقت غالباً؟',
      options: ['نعم', 'أحياناً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'barrier_short',
      prompt: 'اكتب سبباً قصيراً لو تحب.',
      acceptsText: true,
      placeholder: 'مثلاً: كنت في الطريق',
    ),
    PrayerReflectionQuestion(
      id: 'support_short',
      prompt: 'ما شيء واحد يساعدك في الصلاة القادمة؟',
      acceptsText: true,
      placeholder: 'فكرة بسيطة تكفي',
    ),
    PrayerReflectionQuestion(
      id: 'duaa_short',
      prompt: 'اكتب نية صغيرة للعودة بهدوء.',
      acceptsText: true,
      placeholder: 'مثلاً: سأستعد قبل الوقت',
    ),
    PrayerReflectionQuestion(
      id: 'schedule',
      prompt: 'هل جدولك اليوم كان مزدحماً؟',
      options: ['نعم جداً', 'متوسط', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'phone',
      prompt: 'هل الهاتف أو التشتت أخذ وقتك؟',
      options: ['نعم', 'قليلاً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'social',
      prompt: 'هل كنت مع أشخاص أو في موقف اجتماعي؟',
      options: ['نعم', 'جزئياً', 'لا'],
    ),
    PrayerReflectionQuestion(
      id: 'preparation',
      prompt: 'هل الاستعداد قبل الأذان سيساعد؟',
      options: ['نعم', 'ربما', 'لا أعرف'],
    ),
    PrayerReflectionQuestion(
      id: 'recovery',
      prompt: 'ما أهدأ طريقة للتعويض الآن؟',
      options: ['الاستغفار', 'صلاة قريبة', 'ترتيب الوقت القادم'],
    ),
  ];

  List<PrayerReflectionQuestion> get reflectionQuestionPool =>
      _reflectionQuestionPool;

  PrayerTimeInfo buildPrayerTimeInfo({
    required DailyPrayerTimes dailyTimes,
    required QiyamPreference qiyamPreference,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final nextPrayer = _nextObligatoryPrayer(dailyTimes, reference);
    final currentPrayer = _currentPrayer(dailyTimes, reference);
    final lastPassedPrayer = _lastPassedObligatoryPrayer(dailyTimes, reference);
    final guide = guideFor(nextPrayer.key);
    final style = visualStyleFor(nextPrayer.key);
    final qiyamSuggestion = calculateQiyamSuggestion(
      dailyTimes: dailyTimes,
      preference: qiyamPreference,
    );

    return PrayerTimeInfo(
      nextPrayer: nextPrayer,
      currentPrayer: currentPrayer,
      lastPassedPrayer: lastPassedPrayer,
      timeRemaining: nextPrayer.time.difference(reference),
      visualStyle: style,
      guide: guide,
      message: _messageFor(nextPrayer.key),
      qiyamSuggestion: qiyamSuggestion,
      reflectionPrompt: reflectionPromptFor(lastPassedPrayer?.key),
    );
  }

  PrayerTimeEntry _nextObligatoryPrayer(
    DailyPrayerTimes dailyTimes,
    DateTime now,
  ) {
    final obligatory = dailyTimes.entries
        .where((entry) => _obligatoryPrayerKeys.contains(entry.key))
        .toList();

    for (final entry in obligatory) {
      if (entry.time.isAfter(now)) {
        return entry;
      }
    }

    final fajr = dailyTimes.entryFor('fajr');
    if (fajr != null) {
      return PrayerTimeEntry(
        key: fajr.key,
        label: fajr.label,
        time: fajr.time.add(const Duration(days: 1)),
      );
    }

    return obligatory.first;
  }

  PrayerTimeEntry? _currentPrayer(DailyPrayerTimes dailyTimes, DateTime now) {
    final lastPassed = _lastPassedObligatoryPrayer(dailyTimes, now);
    if (lastPassed == null) {
      return null;
    }

    final next = _nextObligatoryPrayer(dailyTimes, now);
    if (lastPassed.time.isBefore(now) && next.time.isAfter(now)) {
      return lastPassed;
    }
    return null;
  }

  PrayerTimeEntry? _lastPassedObligatoryPrayer(
    DailyPrayerTimes dailyTimes,
    DateTime now,
  ) {
    final obligatory = dailyTimes.entries
        .where((entry) => _obligatoryPrayerKeys.contains(entry.key))
        .toList();
    for (final entry in obligatory.reversed) {
      if (!entry.time.isAfter(now)) {
        return entry;
      }
    }
    return null;
  }

  PrayerGuide guideFor(String prayerKey) {
    switch (prayerKey) {
      case 'sunrise':
        return const PrayerGuide(
          prayerKey: 'sunrise',
          prayerName: 'الشروق',
          beforeRakaat: 0,
          beforeNote: 'ليس قبل الشروق صلاة مفروضة',
          fardRakaat: 0,
          fardNote: 'الشروق وقت وليس صلاة مفروضة',
          afterRakaat: 2,
          afterNote: 'يمكن صلاة الضحى بعد ارتفاع الشمس',
          recitationGuidance: [
            'الشروق نفسه ليس صلاة.',
            'إذا أردت صلاة الضحى فاقرأ الفاتحة وما تيسر في كل ركعة.',
            'ابدأ بعد ارتفاع الشمس بوقت يسير، وليس عند لحظة الشروق مباشرة.',
          ],
          simpleSteps: [
            'انتظر حتى ترتفع الشمس بعد الشروق.',
            'توضأ واستقبل القبلة.',
            'صل ركعتين بنية الضحى، ويمكن الزيادة حسب القدرة.',
            'اختم بالتشهد والسلام بهدوء.',
          ],
          wuduGuidance: [
            'اغسل الوجه.',
            'اغسل اليدين إلى المرفقين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين إلى الكعبين.',
          ],
          notes: [
            'الشروق علامة زمنية مهمة، أما الصلاة المشهورة بعدها فهي الضحى.',
            'هذه إرشادات عامة، وراجع أهل العلم في التفاصيل.',
          ],
        );
      case 'fajr':
        return const PrayerGuide(
          prayerKey: 'fajr',
          prayerName: 'الفجر',
          beforeRakaat: 2,
          beforeNote: 'سنة قبلها',
          fardRakaat: 2,
          fardNote: 'فرض أساسي',
          afterRakaat: 0,
          afterNote: 'لا سنة بعدها',
          recitationGuidance: [
            'الفاتحة في كل ركعة.',
            'بعد الفاتحة اقرأ ما تيسر من القرآن، خاصة في أول ركعتين.',
            'يمكنك القراءة من قصار السور مثل الإخلاص والفلق والناس والكافرون.',
          ],
          simpleSteps: [
            'استقبل القبلة وانوِ الصلاة.',
            'كبّر تكبيرة الإحرام.',
            'اقرأ الفاتحة ثم ما تيسر.',
            'أتم الركوع والسجود بهدوء في كل ركعة.',
            'اختم بالتشهد ثم السلام.',
          ],
          wuduGuidance: [
            'اغسل الوجه.',
            'اغسل اليدين إلى المرفقين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين إلى الكعبين.',
          ],
          notes: ['هذه إرشادات عامة، ويمكنك الرجوع لأهل العلم في التفاصيل.'],
        );
      case 'dhuhr':
        return const PrayerGuide(
          prayerKey: 'dhuhr',
          prayerName: 'الظهر',
          beforeRakaat: 2,
          beforeNote: 'سنة قبلها',
          fardRakaat: 4,
          fardNote: 'فرض أساسي',
          afterRakaat: 2,
          afterNote: 'سنة بعدها',
          recitationGuidance: [
            'الفاتحة في كل ركعة.',
            'بعد الفاتحة اقرأ ما تيسر من القرآن، خاصة في أول ركعتين.',
            'يمكنك القراءة من الإخلاص أو الفلق أو الناس أو الكافرون.',
          ],
          simpleSteps: [
            'انوِ الصلاة ثم كبّر.',
            'اقرأ الفاتحة وما تيسر في أول ركعتين.',
            'حافظ على الطمأنينة في الركوع والسجود.',
            'اجلس للتشهد الأوسط ثم أكمل الركعات.',
            'اختم بالتشهد والسلام.',
          ],
          wuduGuidance: [
            'ابدأ بالنية والتسمية.',
            'اغسل الوجه واليدين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين.',
          ],
          notes: ['هذه إرشادات عامة، ويمكنك الرجوع لأهل العلم في التفاصيل.'],
        );
      case 'asr':
        return const PrayerGuide(
          prayerKey: 'asr',
          prayerName: 'العصر',
          beforeRakaat: 0,
          beforeNote: 'لا سنة قبلها',
          fardRakaat: 4,
          fardNote: 'فرض أساسي',
          afterRakaat: 0,
          afterNote: 'لا سنة بعدها',
          recitationGuidance: [
            'الفاتحة في كل ركعة.',
            'بعد الفاتحة اقرأ ما تيسر من القرآن، خاصة في أول ركعتين.',
            'يمكنك القراءة من الإخلاص والفلق والناس والكافرون.',
          ],
          simpleSteps: [
            'استقبل القبلة وانوِ الصلاة.',
            'كبّر ثم اقرأ الفاتحة وما تيسر.',
            'اركع واسجد بخشوع وهدوء.',
            'أتم الركعات الأربع بالتشهد والسلام.',
          ],
          wuduGuidance: [
            'اغسل الوجه واليدين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين جيداً.',
          ],
          notes: ['هذه إرشادات عامة، ويمكنك الرجوع لأهل العلم في التفاصيل.'],
        );
      case 'maghrib':
        return const PrayerGuide(
          prayerKey: 'maghrib',
          prayerName: 'المغرب',
          beforeRakaat: 0,
          beforeNote: 'لا سنة قبلها',
          fardRakaat: 3,
          fardNote: 'فرض أساسي',
          afterRakaat: 2,
          afterNote: 'سنة بعدها',
          recitationGuidance: [
            'الفاتحة في كل ركعة.',
            'بعد الفاتحة اقرأ ما تيسر من القرآن، خاصة في أول ركعتين.',
            'يمكنك القراءة من الإخلاص أو الفلق أو الناس أو الكافرون.',
          ],
          simpleSteps: [
            'انْوِ صلاة المغرب ثم كبّر.',
            'صلِّ الركعتين الأوليين بالفاتحة وما تيسر من القرآن.',
            'في الركعة الثالثة اقرأ الفاتحة ثم أتم الصلاة.',
            'اختم بالتشهد والسلام.',
          ],
          wuduGuidance: [
            'اغسل الوجه.',
            'اغسل اليدين إلى المرفقين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين إلى الكعبين.',
          ],
          notes: ['هذه إرشادات عامة، ويمكنك الرجوع لأهل العلم في التفاصيل.'],
        );
      case 'isha':
      default:
        return const PrayerGuide(
          prayerKey: 'isha',
          prayerName: 'العشاء',
          beforeRakaat: 0,
          beforeNote: 'لا سنة قبلها',
          fardRakaat: 4,
          fardNote: 'فرض أساسي',
          afterRakaat: 2,
          afterNote: 'سنة بعدها، والوتر بعد العشاء حسن',
          recitationGuidance: [
            'الفاتحة في كل ركعة.',
            'بعد الفاتحة اقرأ ما تيسر من القرآن، خاصة في أول ركعتين.',
            'يمكنك القراءة من الإخلاص والفلق والناس والكافرون.',
          ],
          simpleSteps: [
            'انوِ الصلاة ثم كبّر.',
            'اقرأ الفاتحة وما تيسر في أول ركعتين.',
            'أكمل الركعات الأربع بخشوع وطمأنينة.',
            'اختم بالتشهد والسلام.',
          ],
          wuduGuidance: [
            'اغسل الوجه واليدين.',
            'امسح الرأس والأذنين.',
            'اغسل القدمين.',
          ],
          notes: ['هذه إرشادات عامة، ويمكنك الرجوع لأهل العلم في التفاصيل.'],
        );
    }
  }

  PrayerVisualStyle visualStyleFor(String prayerKey) {
    switch (prayerKey) {
      case 'fajr':
        return const PrayerVisualStyle(
          key: 'fajr',
          label: 'فجر هادئ',
          icon: Icons.nightlight_round,
          startColor: Color(0xFF13203F),
          endColor: Color(0xFF4C7BD9),
          highlightColor: Color(0xFFF9D889),
        );
      case 'dhuhr':
        return const PrayerVisualStyle(
          key: 'dhuhr',
          label: 'نهار صافٍ',
          icon: Icons.light_mode_rounded,
          startColor: Color(0xFFFFD46A),
          endColor: Color(0xFFFFF2BE),
          highlightColor: Color(0xFFEA8F00),
        );
      case 'asr':
        return const PrayerVisualStyle(
          key: 'asr',
          label: 'دفء العصر',
          icon: Icons.wb_sunny_outlined,
          startColor: Color(0xFFEAA15B),
          endColor: Color(0xFFF6D6A5),
          highlightColor: Color(0xFFB45A1D),
        );
      case 'maghrib':
        return const PrayerVisualStyle(
          key: 'maghrib',
          label: 'غروب مطمئن',
          icon: Icons.sunny_snowing,
          startColor: Color(0xFFB94C5A),
          endColor: Color(0xFFF3A860),
          highlightColor: Color(0xFFFFF0C2),
        );
      case 'isha':
      default:
        return const PrayerVisualStyle(
          key: 'isha',
          label: 'ليل ساكن',
          icon: Icons.dark_mode_rounded,
          startColor: Color(0xFF0E1832),
          endColor: Color(0xFF283E6D),
          highlightColor: Color(0xFFBFD2FF),
        );
    }
  }

  QiyamTimeSuggestion calculateQiyamSuggestion({
    required DailyPrayerTimes dailyTimes,
    required QiyamPreference preference,
  }) {
    final isha = dailyTimes.entryFor('isha');
    final fajr = dailyTimes.entryFor('fajr');
    final maghrib = dailyTimes.entryFor('maghrib');

    final nightStart = isha?.time ?? maghrib?.time;
    final initialFajr = fajr?.time;
    if (nightStart == null || initialFajr == null) {
      return QiyamTimeSuggestion(
        label: preference.label,
        suggestedAt: DateTime.now(),
        isApproximate: true,
      );
    }

    final nightEnd = initialFajr.isAfter(nightStart)
        ? initialFajr
        : initialFajr.add(const Duration(days: 1));
    final nightDuration = nightEnd.difference(nightStart);
    final third = Duration(milliseconds: nightDuration.inMilliseconds ~/ 3);

    late final DateTime suggestedAt;
    switch (preference) {
      case QiyamPreference.firstThird:
        suggestedAt = nightStart.add(third ~/ 2);
        break;
      case QiyamPreference.secondThird:
        suggestedAt = nightStart.add(third + (third ~/ 2));
        break;
      case QiyamPreference.lastThird:
        suggestedAt = nightStart.add((third * 2) + (third ~/ 2));
        break;
    }

    return QiyamTimeSuggestion(
      label: preference.label,
      suggestedAt: suggestedAt,
      isApproximate: true,
    );
  }

  PrayerReflectionPrompt? reflectionPromptFor(String? prayerKey) {
    return reflectionPromptForMissedPrayer(prayerKey);
  }

  PrayerReflectionPrompt? reflectionPromptForMissedPrayer(
    String? prayerKey, {
    DateTime? seedTime,
  }) {
    if (prayerKey == null || !_obligatoryPrayerKeys.contains(prayerKey)) {
      return null;
    }

    final guide = guideFor(prayerKey);
    final random = Random((seedTime ?? DateTime.now()).microsecondsSinceEpoch);
    final questionCount = 3 + random.nextInt(3);
    final questions = List<PrayerReflectionQuestion>.of(_reflectionQuestionPool)
      ..shuffle(random);

    return PrayerReflectionPrompt(
      prayerKey: prayerKey,
      prayerName: guide.prayerName,
      title: 'مراجعة هادئة',
      supportingMessage: 'اخترنا لك أسئلة قليلة تساعدنا نفهم اليوم بدون لوم.',
      questions: questions.take(questionCount).toList(growable: false),
    );
  }

  String formatRemaining(Duration duration) {
    final positive = duration.isNegative ? Duration.zero : duration;
    final hours = positive.inHours;
    final minutes = positive.inMinutes.remainder(60);

    if (hours == 0 && minutes == 0) {
      return 'باقي أقل من دقيقة';
    }
    if (hours == 0) {
      return 'باقي ${_toArabicDigits('$minutes')} دقيقة';
    }
    if (minutes == 0) {
      return 'باقي ${_toArabicDigits('$hours')} ساعة';
    }
    return 'باقي ${_toArabicDigits('$hours')} ساعة و${_toArabicDigits('$minutes')} دقيقة';
  }

  String _messageFor(String prayerKey) {
    switch (prayerKey) {
      case 'fajr':
        return 'فاصل هادئ لبداية اليوم بنية أوضح وقلب أخف.';
      case 'dhuhr':
        return 'خذ وقفة قصيرة الآن، وستشعر أن بقية اليوم أخف.';
      case 'asr':
        return 'دفء العصر يذكّرك أن الباقي من اليوم ما زال فيه بركة.';
      case 'maghrib':
        return 'الغروب وقت جميل لترتيب النفس والدخول للصلاة بهدوء.';
      case 'isha':
      default:
        return 'استقبل الليل بصلاة هادئة، واترك بعدها مساحة للسكينة.';
    }
  }

  String _toArabicDigits(String value) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = value;
    for (var index = 0; index < western.length; index += 1) {
      result = result.replaceAll(western[index], arabic[index]);
    }
    return result;
  }
}
