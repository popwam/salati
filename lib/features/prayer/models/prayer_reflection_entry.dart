import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerReflectionAnswer {
  const PrayerReflectionAnswer({
    required this.questionId,
    required this.question,
    required this.answer,
  });

  final String questionId;
  final String question;
  final String answer;

  Map<String, dynamic> toMap() {
    return {'questionId': questionId, 'question': question, 'answer': answer};
  }

  factory PrayerReflectionAnswer.fromMap(Map<String, dynamic> map) {
    return PrayerReflectionAnswer(
      questionId: map['questionId'] as String? ?? '',
      question: map['question'] as String? ?? '',
      answer: map['answer'] as String? ?? '',
    );
  }
}

class PrayerReflectionEntry {
  const PrayerReflectionEntry({
    required this.docId,
    required this.prayerKey,
    required this.prayerName,
    required this.answeredAt,
    required this.answers,
    required this.questionIds,
    required this.scoreAtMoment,
  });

  final String docId;
  final String prayerKey;
  final String prayerName;
  final DateTime answeredAt;
  final List<PrayerReflectionAnswer> answers;
  final List<String> questionIds;
  final int scoreAtMoment;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'recordType': 'prayer_reflection',
      'prayerKey': prayerKey,
      'prayerName': prayerName,
      'answeredAt': FieldValue.serverTimestamp(),
      'answers': answers.map((item) => item.toMap()).toList(),
      'questionIds': questionIds,
      'scoreAtMoment': scoreAtMoment,
    };
  }

  factory PrayerReflectionEntry.fromMap(
    String docId,
    Map<String, dynamic> map,
  ) {
    final answeredAtValue = map['answeredAt'];
    final answeredAt = answeredAtValue is Timestamp
        ? answeredAtValue.toDate()
        : DateTime.now();
    final answers = (map['answers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PrayerReflectionAnswer.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    final questionIds =
        (map['questionIds'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        answers.map((item) => item.questionId).toList();

    return PrayerReflectionEntry(
      docId: docId,
      prayerKey: map['prayerKey'] as String? ?? '',
      prayerName: map['prayerName'] as String? ?? '',
      answeredAt: answeredAt,
      answers: answers,
      questionIds: questionIds,
      scoreAtMoment: (map['scoreAtMoment'] as num?)?.toInt() ?? 0,
    );
  }
}
