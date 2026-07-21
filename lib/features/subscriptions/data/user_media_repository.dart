import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

abstract class UserMediaRepository {
  Future<String> uploadProfileAvatar({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  Future<void> deleteProfileAvatar({required String uid});
}

class FirebaseUserMediaRepository implements UserMediaRepository {
  FirebaseUserMediaRepository({required bool firebaseConfigured})
    : _firebaseConfigured = firebaseConfigured;

  final bool _firebaseConfigured;

  Reference _avatarRef(String uid) {
    return FirebaseStorage.instance.ref('users/$uid/profile/avatar.jpg');
  }

  @override
  Future<String> uploadProfileAvatar({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      throw StateError('Firebase Storage is not configured.');
    }

    final ref = _avatarRef(uid.trim());
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=86400',
        customMetadata: const {'owner': 'profile_avatar'},
      ),
    );
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteProfileAvatar({required String uid}) async {
    if (!_firebaseConfigured || uid.trim().isEmpty) {
      return;
    }

    try {
      await _avatarRef(uid.trim()).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
