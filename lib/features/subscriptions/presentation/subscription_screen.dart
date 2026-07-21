import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/points_config.dart';
import '../../../core/services/app_services.dart';
import '../data/billing_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/info_card.dart';
import '../../../shared/widgets/loading_state_view.dart';
import 'subscription_controller.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراك')),
      body: _SubscriptionScreenBody(services: services),
    );
  }
}

class _BillingStoreCard extends StatefulWidget {
  const _BillingStoreCard({required this.services});

  final AppServices services;

  @override
  State<_BillingStoreCard> createState() => _BillingStoreCardState();
}

class _BillingStoreCardState extends State<_BillingStoreCard> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<BillingProduct> _products = const [];
  bool _isLoading = true;
  bool _isBusy = false;
  bool _storeAvailable = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _purchaseSub = widget.services.billingService.purchases.listen(
      _handlePurchases,
      onError: (error, stackTrace) {
        widget.services.crashReportingService.recordError(error, stackTrace);
      },
    );
    _loadProducts();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final available = await widget.services.billingService.isAvailable();
      final products = available
          ? await widget.services.billingService.loadProducts()
          : const <BillingProduct>[];
      if (!mounted) {
        return;
      }
      setState(() {
        _storeAvailable = available;
        _products = products;
        _isLoading = false;
        _message = available && products.isEmpty
            ? 'المتجر متاح، لكن منتجات الاشتراك لم تُضبط بعد في Google Play أو App Store.'
            : null;
      });
    } catch (error, stackTrace) {
      await widget.services.crashReportingService.recordError(
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _message = 'تعذر تحميل منتجات المتجر الرسمية الآن.';
      });
    }
  }

  Future<void> _buy(BillingProduct product) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      final result = await widget.services.billingService.buy(product);
      await widget.services.analyticsService.trackEvent(
        'purchase_started',
        parameters: {
          'product_id': product.id,
          'started': result.started ? 1 : 0,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = result.started
            ? 'تم فتح نافذة الشراء الرسمية. التفعيل النهائي يحتاج تحقق المتجر أو الخادم.'
            : result.message ?? 'لم يبدأ الشراء من المتجر.';
      });
    } catch (error, stackTrace) {
      await widget.services.crashReportingService.recordError(
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'تعذر بدء عملية الشراء.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      await widget.services.billingService.restorePurchases();
      await widget.services.analyticsService.trackEvent(
        'purchase_restore_requested',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'تم طلب استعادة المشتريات من المتجر الرسمي.';
      });
    } catch (error, stackTrace) {
      await widget.services.crashReportingService.recordError(
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'تعذر طلب استعادة المشتريات.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await widget.services.analyticsService.trackEvent(
        'purchase_status',
        parameters: {
          'product_id': purchase.productID,
          'status': purchase.status.name,
        },
      );

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _message = purchase.error?.message ?? 'حدث خطأ أثناء الشراء.';
          });
        }
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verification = await widget.services.purchaseVerificationService
            .verify(purchase);
        await widget.services.analyticsService.trackEvent(
          'purchase_verification_result',
          parameters: {
            'product_id': purchase.productID,
            'verified': verification.verified ? 1 : 0,
          },
        );

        if (mounted) {
          setState(() {
            _message = verification.verified
                ? 'Purchase verified. Your entitlement will refresh from the server.'
                : 'Purchase detected, but server verification failed: ${verification.message}';
          });
        }

        if (!verification.verified) {
          continue;
        }
      }

      await widget.services.billingService.completePurchase(purchase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined),
              title: const Text('الشراء من المتجر الرسمي'),
              subtitle: Text(
                _storeAvailable
                    ? 'Google Play Billing وApp Store IAP جاهزان من جهة التطبيق، والتفعيل ينتظر ضبط المنتجات.'
                    : 'المتجر غير متاح على هذا الجهاز أو هذه البيئة.',
              ),
              trailing: IconButton(
                onPressed: _isBusy ? null : _loadProducts,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث',
              ),
            ),
            if (_isLoading)
              const LinearProgressIndicator()
            else if (_products.isNotEmpty)
              ..._products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : () => _buy(product),
                    child: Text('${product.title} - ${product.price}'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _isBusy ? null : _restore,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('استعادة المشتريات'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionScreenBody extends StatefulWidget {
  const _SubscriptionScreenBody({required this.services});

  final AppServices services;

  @override
  State<_SubscriptionScreenBody> createState() =>
      _SubscriptionScreenBodyState();
}

class _SubscriptionScreenBodyState extends State<_SubscriptionScreenBody> {
  late final SubscriptionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SubscriptionController(services: widget.services);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final currentPlan = widget.services.entitlementChecker.activePlanFor(
          planId: state.currentUser?.effectivePlanId ?? 'free',
          plans: state.plans,
        );

        if (state.isLoading) {
          return const LoadingStateView(label: 'جارٍ تحميل بيانات الاشتراك');
        }

        if (state.error != null) {
          return ErrorStateView(
            title: 'تعذر تحميل بيانات الاشتراك',
            message: state.error!,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InfoCard(
              title: 'الباقة الحالية',
              body: currentPlan != null
                  ? '${currentPlan.name}\nالسعر: ${currentPlan.priceLabel}\n${_buildLimitsText(currentPlan)}'
                  : 'لم يتم العثور على باقة حالية للحساب.',
              trailing: currentPlan?.id == 'free'
                  ? OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('راجع تفاصيل الباقة قبل المتابعة.'),
                          ),
                        );
                      },
                      child: const Text('ترقية الحدود'),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            const InfoCard(
              title: 'الترقية والحدود',
              body:
                  'الشات متاح حسب حدود كل باقة. الترقية لا تعني فتح الشات من الصفر، بل رفع الحدود اليومية وحدود المحتوى المخصص عند اكتمال تدفق الدفع.',
            ),
            const SizedBox(height: 12),
            const InfoCard(
              title: 'جلسة Pro مؤقتة',
              body:
                  'يمكن فتح Pro لمدة 3 أيام بعد مشاهدة 5 إعلانات مكافأة. Plus متوقفة حالياً وستظهر كقريباً لحين إطلاقها رسمياً.',
            ),
            const SizedBox(height: 12),
            InfoCard(
              title: 'شروط الشراء والاشتراك',
              body:
                  'قبل تفعيل أي شراء تجاري، يجب أن يتم الدفع عبر متجر المنصة الرسمي مع توضيح ما هو مجاني وما هو مدفوع.',
              trailing: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.termsRoute),
                child: const Text('الشروط'),
              ),
            ),
            const SizedBox(height: 12),
            _BillingStoreCard(services: widget.services),
            const SizedBox(height: 12),
            if (_paidPlans(state.plans).isEmpty)
              const SizedBox(
                height: 180,
                child: EmptyStateView(
                  title: 'لا توجد خطط متاحة',
                  message: 'أضف مستندات plans في Firestore لتظهر هنا.',
                ),
              )
            else
              ..._paidPlans(
                state.plans,
              ).map((plan) => _buildPlanCard(plan, state.pointsRules)),
            const SizedBox(height: 12),
            if (state.entitlements.isEmpty)
              const SizedBox(
                height: 180,
                child: EmptyStateView(
                  title: 'لا توجد استحقاقات مفعلة',
                  message: 'ستظهر هنا الميزات المتاحة لهذا الحساب عند توفرها.',
                  icon: Icons.lock_open_outlined,
                ),
              )
            else
              ...state.entitlements.map(_buildEntitlementCard),
          ],
        );
      },
    );
  }

  List<Plan> _paidPlans(List<Plan> plans) {
    final paid = plans
        .where((plan) => {'plus', 'pro'}.contains(plan.id.toLowerCase()))
        .toList(growable: false);
    if (paid.isNotEmpty) {
      return paid;
    }
    return const [
      Plan(
        id: 'plus',
        name: 'Plus',
        priceLabel: 'Needs setup',
        isActive: false,
      ),
      Plan(id: 'pro', name: 'Pro', priceLabel: 'Needs setup', isActive: false),
    ];
  }

  Widget _buildPlanCard(Plan plan, PointsRulesConfig pointsRules) {
    final rule = pointsRules.ruleForPlan(plan.id);
    final localeCode = Localizations.localeOf(context).languageCode;
    final planName = plan.displayName(localeCode);
    final planDescription = plan.displayDescription(localeCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          leading: Icon(
            plan.isActive
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
          ),
          title: Text(planName),
          subtitle: Text(
            '${plan.priceLabel} - ${plan.isActive ? 'Active' : 'Inactive'}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _RewardRulesView(rule: rule),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(_buildLimitsText(plan)),
            ),
            if (planDescription != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(planDescription),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildLimitsText(Plan plan) {
    return 'حد الشات اليومي: ${plan.aiDailyLimit}\n'
        'المفضلة: ${plan.maxFavorites}\n'
        'التأملات: ${plan.maxReflections}\n'
        'أقسام الأذكار المخصصة: ${plan.maxCustomDhikrCategories}\n'
        'أقسام الأدعية المخصصة: ${plan.maxCustomDuaCategories}';
  }

  Widget _buildEntitlementCard(FeatureEntitlement entitlement) {
    final isEnabled = widget.services.entitlementChecker.isEnabled(
      featureKey: entitlement.featureKey,
      entitlements: [entitlement],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        title: entitlement.title ?? entitlement.featureKey,
        body:
            'المفتاح: ${entitlement.featureKey}\nالحالة: ${isEnabled ? 'مفعلة' : 'غير مفعلة'}\nالمصدر: ${entitlement.source}${entitlement.description == null ? '' : '\n${entitlement.description}'}',
        trailing: Icon(
          isEnabled ? Icons.verified_outlined : Icons.block_outlined,
        ),
      ),
    );
  }
}

class _RewardRulesView extends StatelessWidget {
  const _RewardRulesView({required this.rule});

  final PlanPointsRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      ('Prayer on time', '+${rule.prayerOnTime}'),
      ('Prayer late', '+${rule.prayerLate}'),
      ('Missed prayer', '${rule.prayerMissed}'),
      ('Adhkar complete', '+${rule.adhkarCompletion}'),
      ('Dua complete', '+${rule.duaCompletion}'),
      ('Qiyam complete', '+${rule.qiyamCompletion}'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) {
            return Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${item.$1}: ${item.$2}'),
              labelStyle: theme.textTheme.labelMedium,
            );
          })
          .toList(growable: false),
    );
  }
}
