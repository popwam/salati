import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerPointsService {
  PrayerPointsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> setUserPoints({
    required String uid,
    required double points,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'points': points,
      'pointsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementUserPoints({
    required String uid,
    required double delta,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'points': FieldValue.increment(delta),
      'pointsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
