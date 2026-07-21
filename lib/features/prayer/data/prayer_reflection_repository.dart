import '../models/prayer_reflection_entry.dart';

abstract class PrayerReflectionRepository {
  Future<PrayerReflectionEntry?> loadReflection({
    required String uid,
    required String docId,
  });

  Future<bool> saveReflectionOnce({
    required String uid,
    required PrayerReflectionEntry entry,
  });
}
