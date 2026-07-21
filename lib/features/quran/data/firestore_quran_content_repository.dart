import 'package:cloud_firestore/cloud_firestore.dart';

class QuranDailyEntry {
  const QuranDailyEntry({
    required this.docId,
    required this.ayahText,
    required this.tafsir,
    required this.reflection,
    required this.word,
    required this.locale,
    required this.sortOrder,
  });

  final String docId;
  final String ayahText;
  final String tafsir;
  final String reflection;
  final String word;
  final String locale;
  final int sortOrder;

  factory QuranDailyEntry.fromMap(String id, Map<String, dynamic> map) {
    return QuranDailyEntry(
      docId: id,
      ayahText: map['ayahText'] as String? ?? '',
      tafsir: map['tafsir'] as String? ?? '',
      reflection: map['reflection'] as String? ?? '',
      word: map['word'] as String? ?? '',
      locale: map['locale'] as String? ?? 'ar',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class FirestoreQuranContentRepository {
  FirestoreQuranContentRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  Future<List<QuranDailyEntry>> loadDailyEntries(String locale) async {
    if (!_firebaseConfigured) {
      return const [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('content')
        .doc('quran')
        .collection('daily')
        .where('isActive', isEqualTo: true)
        .where('locale', isEqualTo: locale)
        .orderBy('sortOrder')
        .get();

    return snapshot.docs
        .map((doc) => QuranDailyEntry.fromMap(doc.id, doc.data()))
        .toList();
  }
}
