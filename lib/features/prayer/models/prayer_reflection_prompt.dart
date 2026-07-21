class PrayerReflectionQuestion {
  const PrayerReflectionQuestion({
    required this.id,
    required this.prompt,
    this.options = const <String>[],
    this.acceptsText = false,
    this.placeholder,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final bool acceptsText;
  final String? placeholder;
}

class PrayerReflectionPrompt {
  const PrayerReflectionPrompt({
    required this.prayerKey,
    required this.prayerName,
    required this.title,
    required this.supportingMessage,
    required this.questions,
  });

  final String prayerKey;
  final String prayerName;
  final String title;
  final String supportingMessage;
  final List<PrayerReflectionQuestion> questions;
}
