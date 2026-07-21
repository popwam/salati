import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_state_view.dart';

class AdminGuard extends StatelessWidget {
  const AdminGuard({
    super.key,
    required this.services,
    required this.firebaseConfigured,
    required this.child,
  });

  final AppServices services;
  final bool firebaseConfigured;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!firebaseConfigured) {
      return const ErrorStateView(
        title: 'Firebase غير مهيأ',
        message: 'حماية الإدارة تحتاج Firebase مفعلاً حتى تعمل فعلياً.',
      );
    }

    return StreamBuilder(
      stream: services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateView(label: 'جارٍ التحقق من جلسة الإدارة');
        }

        if (authSnapshot.hasError) {
          return ErrorStateView(
            title: 'تعذر التحقق من الجلسة',
            message: mapAppErrorToArabic(authSnapshot.error!),
          );
        }

        if (authSnapshot.data == null) {
          return const ErrorStateView(
            title: 'يلزم تسجيل الدخول',
            message: 'يجب تسجيل دخول إداري قبل الوصول إلى صفحات الإدارة.',
          );
        }

        final session = authSnapshot.data!;
        if (session.isAnonymous) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ErrorStateView(
                    title: 'لا توجد صلاحية للوصول لهذا الجزء',
                    message:
                        'الدخول المجهول غير مسموح للوحات الإدارة. استخدم حساب إدارة حقيقي.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await services.authService.signOut();
                    },
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder(
          stream: services.userProfileRepository.watchCurrentUser(session.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateView(
                label: 'جارٍ التحقق من صلاحية الإدارة',
              );
            }

            if (userSnapshot.hasError) {
              return ErrorStateView(
                title: 'تعذر قراءة ملف المستخدم',
                message: mapAppErrorToArabic(userSnapshot.error!),
              );
            }

            final user = userSnapshot.data;
            if (user == null || !user.isAdmin) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ErrorStateView(
                        title: 'وصول مرفوض',
                        message:
                            'هذا الحساب مسجل، لكنه غير مصنف كحساب إداري داخل users/{uid}.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          await services.authService.signOut();
                        },
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return child;
          },
        );
      },
    );
  }
}
