import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/info_card.dart';
import '../../../shared/widgets/loading_state_view.dart';
import 'admin_guard.dart';
import 'admin_scaffold.dart';

class PlansManagementScreen extends StatefulWidget {
  const PlansManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<PlansManagementScreen> createState() => _PlansManagementScreenState();
}

class _PlansManagementScreenState extends State<PlansManagementScreen> {
  String? _updatingPlanId;

  Future<void> _togglePlan({
    required String planId,
    required bool currentValue,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد تحديث الخطة'),
          content: Text(
            currentValue
                ? 'سيتم إيقاف هذه الخطة. هل تريد المتابعة؟'
                : 'سيتم تفعيل هذه الخطة. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _updatingPlanId = planId;
    });

    try {
      await widget.services.planRepository.updatePlanStatus(
        planId: planId,
        isActive: !currentValue,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الخطة')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingPlanId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة الخطط',
      currentRoute: AppRouter.adminPlansRoute,
      services: widget.services,
      firebaseConfigured: widget.firebaseConfigured,
      child: AdminGuard(
        services: widget.services,
        firebaseConfigured: widget.firebaseConfigured,
        child: StreamBuilder(
          stream: widget.services.planRepository.watchPlans(
            includeInactive: true,
          ),
          builder: (context, snapshot) {
            if (!widget.firebaseConfigured) {
              return const ErrorStateView(
                title: 'Firebase غير مهيأ',
                message: 'لا يمكن قراءة الخطط قبل تفعيل Firebase.',
              );
            }

            if (snapshot.hasError) {
              return ErrorStateView(
                title: 'تعذر تحميل الخطط',
                message: mapAppErrorToArabic(snapshot.error!),
              );
            }

            if (!snapshot.hasData) {
              return const LoadingStateView(label: 'جارٍ تحميل الخطط');
            }

            final plans = snapshot.data!;
            if (plans.isEmpty) {
              return const EmptyStateView(
                title: 'لا توجد خطط',
                message: 'أضف مستندات plans في Firestore لتظهر هنا.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: plans
                  .map(
                    (plan) => InfoCard(
                      title: plan.name,
                      body:
                          'المعرف: ${plan.id}\nالسعر: ${plan.priceLabel}\nالترتيب: ${plan.sortOrder}\nالحالة: ${plan.isActive ? 'مفعلة' : 'متوقفة'}',
                      trailing: Switch.adaptive(
                        value: plan.isActive,
                        onChanged: _updatingPlanId == plan.id
                            ? null
                            : (_) => _togglePlan(
                                planId: plan.id,
                                currentValue: plan.isActive,
                              ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
