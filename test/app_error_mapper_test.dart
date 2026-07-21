import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/utils/app_error_mapper.dart';

void main() {
  test('maps permission errors to helpful Arabic permission copy', () {
    expect(
      mapAppErrorToArabic(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      'لا توجد صلاحية كافية لهذه العملية.',
    );
  });

  test('maps network errors to concise Arabic network copy', () {
    expect(
      mapAppErrorToArabic(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      'تعذر الاتصال',
    );
  });

  test('maps config errors to concise Arabic config copy', () {
    expect(
      mapAppErrorToArabic(
        FirebaseException(plugin: 'salati', code: 'firebase-not-configured'),
      ),
      'بيانات غير مكتملة',
    );
  });

  test('maps missing sessions to a useful login retry message', () {
    expect(
      mapAppErrorToArabic(
        FirebaseException(plugin: 'salati', code: 'missing-session'),
      ),
      'تم فقد جلسة الدخول. أعد تسجيل الدخول ثم حاول مرة أخرى.',
    );
  });

  test('maps unknown errors to concise Arabic fallback copy', () {
    expect(mapAppErrorToArabic(Exception('boom')), 'حدث خطأ غير متوقع');
  });
}
