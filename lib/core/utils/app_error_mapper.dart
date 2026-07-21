import 'package:firebase_core/firebase_core.dart';

String mapAppErrorToArabic(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'not-admin':
        return 'هذا الحساب لا يملك صلاحية دخول لوحة الإدارة.';
      case 'cloud-config-defaults':
        return 'تعذر تحميل إعدادات السحابة مؤقتًا، سيتم استخدام الإعدادات الافتراضية.';
      case 'permission-denied':
        return 'لا توجد صلاحية كافية لهذه العملية.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
      case 'aborted':
        return 'تعذر الاتصال';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح.';
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح. اكتب الرقم بصيغة دولية مثل +201000000000.';
      case 'too-many-requests':
        return 'تمت محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
      case 'popup-closed-by-user':
      case 'canceled':
        return 'تم إلغاء تسجيل الدخول.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'بيانات الدخول غير صحيحة.';
      case 'firebase-not-configured':
      case 'anonymous-auth-disabled':
      case 'failed-precondition':
      case 'invalid-argument':
        return 'بيانات غير مكتملة';
      case 'missing-session':
        return 'تم فقد جلسة الدخول. أعد تسجيل الدخول ثم حاول مرة أخرى.';
      case 'missing-phone-flow':
        return 'ابدأ بإرسال رمز الهاتف أولاً.';
      case 'missing-verification-id':
        return 'لم يتم تجهيز رمز الهاتف بعد. أعد إرسال الرمز.';
      case 'user-profile-setup-failed':
      case 'not-found':
        return 'بيانات غير مكتملة';
      case 'credential-already-in-use':
      case 'email-already-in-use':
      case 'account-exists-with-credential':
      case 'account-exists-with-different-credential':
      case 'provider-already-linked':
        return 'هذا الحساب مربوط بالفعل، سنستخدم جلسة الحساب الموجودة';
      default:
        return 'حدث خطأ غير متوقع';
    }
  }

  if (error is StateError || error is FormatException) {
    return 'بيانات غير مكتملة';
  }

  return 'حدث خطأ غير متوقع';
}
