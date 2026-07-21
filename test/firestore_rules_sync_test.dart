import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firestore rules allow owners to access safe sync/settings docs', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /sync/{docId}'));
    expect(rules, contains('match /settings/{docId}'));
    expect(rules, contains('function safePrivateDoc()'));
    expect(rules, contains('isOwner(userId) &&'));
    expect(rules, contains('safePrivateDoc()'));
    expect(rules, contains('isSuperAdmin();'));
  });
}
