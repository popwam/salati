import 'package:cloud_functions/cloud_functions.dart';

class AdminDashboardFunctions {
  AdminDashboardFunctions({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name, {
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    try {
      final callable = _functions.httpsCallable(name);
      final response = await callable.call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(response.data);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(_messageForFunctionError(error));
    }
  }

  String _messageForFunctionError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'يجب تسجيل الدخول بحساب مشرف قبل تنفيذ العملية.';
      case 'permission-denied':
        return 'لا توجد صلاحية كافية لتنفيذ هذه العملية.';
      case 'invalid-argument':
        return error.message?.trim().isNotEmpty == true
            ? 'بيانات غير صالحة: ${error.message}'
            : 'بيانات غير صالحة. راجع الحقول وحاول مرة أخرى.';
      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'لا يمكن تنفيذ العملية قبل استكمال المتطلبات.';
      case 'unavailable':
        return 'خدمة الداشبورد غير متاحة الآن. حاول مرة أخرى لاحقًا.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'تعذر تنفيذ عملية الداشبورد.';
    }
  }
}
