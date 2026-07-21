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

class FeaturesManagementScreen extends StatefulWidget {
  const FeaturesManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<FeaturesManagementScreen> createState() =>
      _FeaturesManagementScreenState();
}

class _FeaturesManagementScreenState extends State<FeaturesManagementScreen> {
  String? _selectedPlanId;
  String? _updatingFeatureKey;

  Future<void> _toggleFeature({
    required String planId,
    required String featureKey,
    required bool currentValue,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد تحديث الميزة'),
          content: Text(
            currentValue
                ? 'سيتم تعطيل هذه الميزة للخطة المحددة. هل تريد المتابعة؟'
                : 'سيتم تفعيل هذه الميزة للخطة المحددة. هل تريد المتابعة؟',
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
      _updatingFeatureKey = featureKey;
    });

    try {
      await widget.services.planFeatureRepository.updateFeatureEnabled(
        planId: planId,
        featureKey: featureKey,
        enabled: !currentValue,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الميزة')));
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
          _updatingFeatureKey = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة الميزات',
      currentRoute: AppRouter.adminFeaturesRoute,
      services: widget.services,
      firebaseConfigured: widget.firebaseConfigured,
      child: AdminGuard(
        services: widget.services,
        firebaseConfigured: widget.firebaseConfigured,
        child: StreamBuilder(
          stream: widget.services.planRepository.watchPlans(
            includeInactive: true,
          ),
          builder: (context, plansSnapshot) {
            if (!widget.firebaseConfigured) {
              return const ErrorStateView(
                title: 'Firebase غير مهيأ',
                message: 'لا يمكن قراءة ميزات الخطط قبل تفعيل Firebase.',
              );
            }

            if (plansSnapshot.hasError) {
              return ErrorStateView(
                title: 'تعذر تحميل الخطط',
                message: mapAppErrorToArabic(plansSnapshot.error!),
              );
            }

            if (!plansSnapshot.hasData) {
              return const LoadingStateView(label: 'جارٍ تحميل الخطط');
            }

            final plans = plansSnapshot.data!;
            if (plans.isEmpty) {
              return const EmptyStateView(
                title: 'لا توجد خطط',
                message: 'أضف الخطط أولاً حتى نقرأ ميزاتها.',
              );
            }

            _selectedPlanId ??= plans.first.id;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedPlanId,
                  decoration: const InputDecoration(labelText: 'اختر الخطة'),
                  items: plans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text(plan.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPlanId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder(
                  stream: widget.services.planFeatureRepository
                      .watchFeaturesForPlan(
                        _selectedPlanId ?? '',
                        includeDisabled: true,
                      ),
                  builder: (context, featuresSnapshot) {
                    if (featuresSnapshot.hasError) {
                      return ErrorStateView(
                        title: 'تعذر تحميل الميزات',
                        message: mapAppErrorToArabic(featuresSnapshot.error!),
                      );
                    }

                    if (!featuresSnapshot.hasData) {
                      return const LoadingStateView(
                        label: 'جارٍ تحميل ميزات الخطة',
                      );
                    }

                    final features = featuresSnapshot.data!;
                    if (features.isEmpty) {
                      return const EmptyStateView(
                        title: 'لا توجد ميزات',
                        message:
                            'أضف مستندات plans/{planId}/features/{featureKey} لتظهر هنا.',
                      );
                    }

                    return Column(
                      children: features
                          .map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InfoCard(
                                title: feature.title ?? feature.featureKey,
                                body:
                                    'المفتاح: ${feature.featureKey}\nالحالة: ${feature.enabled ? 'مفعلة' : 'غير مفعلة'}\nالمصدر: ${feature.source}',
                                trailing: Switch.adaptive(
                                  value: feature.enabled,
                                  onChanged:
                                      _updatingFeatureKey == feature.featureKey
                                      ? null
                                      : (_) => _toggleFeature(
                                          planId: _selectedPlanId ?? '',
                                          featureKey: feature.featureKey,
                                          currentValue: feature.enabled,
                                        ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
