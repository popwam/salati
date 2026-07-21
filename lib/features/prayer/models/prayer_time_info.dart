import 'daily_prayer_times.dart';
import 'prayer_guide.dart';
import 'prayer_reflection_prompt.dart';
import 'prayer_visual_style.dart';

class QiyamTimeSuggestion {
  const QiyamTimeSuggestion({
    required this.label,
    required this.suggestedAt,
    required this.isApproximate,
  });

  final String label;
  final DateTime suggestedAt;
  final bool isApproximate;
}

class PrayerTimeInfo {
  const PrayerTimeInfo({
    required this.nextPrayer,
    required this.currentPrayer,
    required this.lastPassedPrayer,
    required this.timeRemaining,
    required this.visualStyle,
    required this.guide,
    required this.message,
    required this.qiyamSuggestion,
    this.reflectionPrompt,
  });

  final PrayerTimeEntry nextPrayer;
  final PrayerTimeEntry? currentPrayer;
  final PrayerTimeEntry? lastPassedPrayer;
  final Duration timeRemaining;
  final PrayerVisualStyle visualStyle;
  final PrayerGuide guide;
  final String message;
  final QiyamTimeSuggestion qiyamSuggestion;
  final PrayerReflectionPrompt? reflectionPrompt;
}
