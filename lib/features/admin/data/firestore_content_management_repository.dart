import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreContentManagementRepository {
  FirestoreContentManagementRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  Future<void> saveContent({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    if (!_firebaseConfigured || path.isEmpty) {
      return;
    }

    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length.isOdd) {
      throw ArgumentError('Path must point to a document.');
    }

    DocumentReference<Map<String, dynamic>>? reference;
    CollectionReference<Map<String, dynamic>>? collection;
    for (var index = 0; index < segments.length; index += 2) {
      final collectionName = segments[index];
      final documentId = segments[index + 1];
      if (reference == null) {
        collection = FirebaseFirestore.instance.collection(collectionName);
      } else {
        collection = reference.collection(collectionName);
      }
      reference = collection.doc(documentId);
    }

    await reference!.set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
