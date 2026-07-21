import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_subscriptions_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_subscription_plan.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminSubscriptionsManagementScreen extends StatefulWidget {
  const AdminSubscriptionsManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminSubscriptionsManagementScreen> createState() =>
      _AdminSubscriptionsManagementScreenState();
}

class _AdminSubscriptionsManagementScreenState
    extends State<AdminSubscriptionsManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminSubscriptionsRepository _subscriptionsRepository;

  String? _busyPlanId;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _subscriptionsRepository = FirestoreAdminSubscriptionsRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _subscriptionsRepository.ensureDefaults();
  }

  Future<void> _openPlanEditor(AdminSubscriptionPlan plan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PlanEditorDialog(plan: plan),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    setState(() {
      _busyPlanId = plan.id;
    });

    try {
      await _subscriptionsRepository.updatePlan(
        planId: plan.id,
        updates: result,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث الباقة.',
          en: 'Plan updated.',
          fr: 'Abonnement mis a jour.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPlanId = null;
        });
      }
    }
  }

  String _formatPrice(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDashboardGuard(
      accessRepository: _accessRepository,
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
      requiredPermission: AdminDashboardPermission.dashboardView,
      builder: (context, access) {
        return AdminDashboardScaffold(
          title: adminDashText(
            context,
            ar: 'الاشتراكات',
            en: 'Subscriptions',
            fr: 'Abonnements',
          ),
          currentRoute: AppRouter.adminDashboardSubscriptionsRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminSubscriptionPlan>>(
            stream: _subscriptionsRepository.watchPlans(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _SubscriptionsStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل الخطط',
                    en: 'Unable to load plans',
                    fr: 'Impossible de charger les abonnements',
                  ),
                  message: mapAppErrorToArabic(snapshot.error!),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final plans = snapshot.data!;
              if (plans.isEmpty) {
                return _SubscriptionsStateCard(
                  title: adminDashText(
                    context,
                    ar: 'لم يتم العثور على خطط',
                    en: 'No plans found',
                    fr: 'Aucun abonnement trouve',
                  ),
                  message: adminDashText(
                    context,
                    ar: 'يجري إعداد الخطط الافتراضية. أعد فتح الصفحة إذا لم تظهر على الفور.',
                    en: 'Default plans are being prepared. Reopen the page if they do not appear immediately.',
                    fr: 'Les abonnements par defaut sont en cours de preparation. Rouvrez la page si necessaire.',
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1320
                      ? (constraints.maxWidth - 32) / 3
                      : constraints.maxWidth >= 900
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return ListView(
                    children: [
                      AdminDashboardGridWrap(
                        children: plans
                            .map((plan) {
                              final isBusy = _busyPlanId == plan.id;
                              return SizedBox(
                                width: cardWidth.clamp(280.0, 408.0).toDouble(),
                                child: AdminDashboardSurfaceCard(
                                  minHeight: 352,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              plan.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Chip(label: Text(plan.id)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _PlanInfoChip(
                                            label: plan.isActive
                                                ? adminDashText(
                                                    context,
                                                    ar: 'مفعلة',
                                                    en: 'Active',
                                                    fr: 'Active',
                                                  )
                                                : adminDashText(
                                                    context,
                                                    ar: 'متوقفة',
                                                    en: 'Inactive',
                                                    fr: 'Inactive',
                                                  ),
                                            color: plan.isActive
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                          ),
                                          _PlanInfoChip(
                                            label: adminDashText(
                                              context,
                                              ar: 'AI/يوم: ${plan.aiDailyLimit}',
                                              en: 'AI/day: ${plan.aiDailyLimit}',
                                              fr: 'IA/jour: ${plan.aiDailyLimit}',
                                            ),
                                          ),
                                          _PlanInfoChip(
                                            label: adminDashText(
                                              context,
                                              ar: 'المفضلة: ${plan.maxFavorites}',
                                              en: 'Favorites: ${plan.maxFavorites}',
                                              fr: 'Favoris: ${plan.maxFavorites}',
                                            ),
                                          ),
                                          _PlanInfoChip(
                                            label: adminDashText(
                                              context,
                                              ar: 'التأملات: ${plan.maxReflections}',
                                              en: 'Reflections: ${plan.maxReflections}',
                                              fr: 'Reflexions: ${plan.maxReflections}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        adminDashText(
                                          context,
                                          ar: 'شهري: ${_formatPrice(plan.priceMonthly)}\nسنوي: ${_formatPrice(plan.priceYearly)}',
                                          en: 'Monthly: ${_formatPrice(plan.priceMonthly)}\nYearly: ${_formatPrice(plan.priceYearly)}',
                                          fr: 'Mensuel: ${_formatPrice(plan.priceMonthly)}\nAnnuel: ${_formatPrice(plan.priceYearly)}',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        adminDashText(
                                          context,
                                          ar: 'آية القرآن: ${plan.allowQuranAyahMode ? 'مفعل' : 'متوقف'}\nكلمة القرآن: ${plan.allowQuranWordMode ? 'مفعل' : 'متوقف'}\nAI القرآن: ${plan.allowQuranAi ? 'مفعل' : 'متوقف'}\nالثيمات المميزة: ${plan.allowPremiumThemes ? 'مفعل' : 'متوقف'}',
                                          en: 'Quran ayah mode: ${plan.allowQuranAyahMode ? 'Enabled' : 'Disabled'}\nQuran word mode: ${plan.allowQuranWordMode ? 'Enabled' : 'Disabled'}\nQuran AI: ${plan.allowQuranAi ? 'Enabled' : 'Disabled'}\nPremium themes: ${plan.allowPremiumThemes ? 'Enabled' : 'Disabled'}',
                                          fr: 'Mode verset Coran: ${plan.allowQuranAyahMode ? 'Active' : 'Desactive'}\nMode mot Coran: ${plan.allowQuranWordMode ? 'Active' : 'Desactive'}\nIA Coran: ${plan.allowQuranAi ? 'Active' : 'Desactive'}\nThemes premium: ${plan.allowPremiumThemes ? 'Actifs' : 'Desactives'}',
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: FilledButton.tonalIcon(
                                          onPressed: isBusy
                                              ? null
                                              : () => _openPlanEditor(plan),
                                          icon: isBusy
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.edit_outlined),
                                          label: Text(
                                            adminDashText(
                                              context,
                                              ar: 'تعديل',
                                              en: 'Edit',
                                              fr: 'Modifier',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _PlanEditorDialog extends StatefulWidget {
  const _PlanEditorDialog({required this.plan});

  final AdminSubscriptionPlan plan;

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _monthlyController;
  late final TextEditingController _yearlyController;
  late final TextEditingController _aiLimitController;
  late final TextEditingController _favoritesController;
  late final TextEditingController _reflectionsController;
  late final TextEditingController _dhikrCategoriesController;
  late final TextEditingController _dhikrItemsController;
  late final TextEditingController _duaCategoriesController;
  late final TextEditingController _duaItemsController;
  late bool _allowQuranAyahMode;
  late bool _allowQuranWordMode;
  late bool _allowQuranAi;
  late bool _allowPremiumThemes;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan.title);
    _monthlyController = TextEditingController(
      text: widget.plan.priceMonthly.toStringAsFixed(
        widget.plan.priceMonthly.truncateToDouble() == widget.plan.priceMonthly
            ? 0
            : 2,
      ),
    );
    _yearlyController = TextEditingController(
      text: widget.plan.priceYearly.toStringAsFixed(
        widget.plan.priceYearly.truncateToDouble() == widget.plan.priceYearly
            ? 0
            : 2,
      ),
    );
    _aiLimitController = TextEditingController(
      text: '${widget.plan.aiDailyLimit}',
    );
    _favoritesController = TextEditingController(
      text: '${widget.plan.maxFavorites}',
    );
    _reflectionsController = TextEditingController(
      text: '${widget.plan.maxReflections}',
    );
    _dhikrCategoriesController = TextEditingController(
      text: '${widget.plan.maxCustomDhikrCategories}',
    );
    _dhikrItemsController = TextEditingController(
      text: '${widget.plan.maxCustomDhikrItemsPerCategory}',
    );
    _duaCategoriesController = TextEditingController(
      text: '${widget.plan.maxCustomDuaCategories}',
    );
    _duaItemsController = TextEditingController(
      text: '${widget.plan.maxCustomDuaItemsPerCategory}',
    );
    _allowQuranAyahMode = widget.plan.allowQuranAyahMode;
    _allowQuranWordMode = widget.plan.allowQuranWordMode;
    _allowQuranAi = widget.plan.allowQuranAi;
    _allowPremiumThemes = widget.plan.allowPremiumThemes;
    _isActive = widget.plan.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _monthlyController.dispose();
    _yearlyController.dispose();
    _aiLimitController.dispose();
    _favoritesController.dispose();
    _reflectionsController.dispose();
    _dhikrCategoriesController.dispose();
    _dhikrItemsController.dispose();
    _duaCategoriesController.dispose();
    _duaItemsController.dispose();
    super.dispose();
  }

  void _showValidationMessage(String message) {
    showAdminDashboardSnackBar(context, message: message, isError: true);
  }

  String _buildLegacyPriceLabel({
    required double monthly,
    required double yearly,
  }) {
    if (monthly == 0 && yearly == 0) {
      return '0';
    }
    if (yearly == 0) {
      return monthly.toStringAsFixed(
        monthly.truncateToDouble() == monthly ? 0 : 2,
      );
    }
    return '${monthly.toStringAsFixed(monthly.truncateToDouble() == monthly ? 0 : 2)} / ${yearly.toStringAsFixed(yearly.truncateToDouble() == yearly ? 0 : 2)}';
  }

  void _submit() {
    final title = _titleController.text.trim();
    final monthly = double.tryParse(_monthlyController.text.trim());
    final yearly = double.tryParse(_yearlyController.text.trim());
    final aiLimit = int.tryParse(_aiLimitController.text.trim());
    final maxFavorites = int.tryParse(_favoritesController.text.trim());
    final maxReflections = int.tryParse(_reflectionsController.text.trim());
    final maxDhikrCategories = int.tryParse(
      _dhikrCategoriesController.text.trim(),
    );
    final maxDhikrItems = int.tryParse(_dhikrItemsController.text.trim());
    final maxDuaCategories = int.tryParse(_duaCategoriesController.text.trim());
    final maxDuaItems = int.tryParse(_duaItemsController.text.trim());

    if (title.isEmpty) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'العنوان مطلوب.',
          en: 'Title is required.',
          fr: 'Le titre est requis.',
        ),
      );
      return;
    }
    if (monthly == null || monthly < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل سعرًا شهريًا صحيحًا.',
          en: 'Enter a valid monthly price.',
          fr: 'Saisissez un prix mensuel valide.',
        ),
      );
      return;
    }
    if (yearly == null || yearly < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل سعرًا سنويًا صحيحًا.',
          en: 'Enter a valid yearly price.',
          fr: 'Saisissez un prix annuel valide.',
        ),
      );
      return;
    }
    if (aiLimit == null || aiLimit < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل حدًا يوميًا صحيحًا.',
          en: 'Enter a valid AI daily limit.',
          fr: 'Saisissez une limite IA valide.',
        ),
      );
      return;
    }
    if (maxFavorites == null || maxFavorites < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل حدًا صحيحًا للمفضلة.',
          en: 'Enter a valid favorites limit.',
          fr: 'Saisissez une limite de favoris valide.',
        ),
      );
      return;
    }
    if (maxReflections == null || maxReflections < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل حدًا صحيحًا للتأملات.',
          en: 'Enter a valid reflections limit.',
          fr: 'Saisissez une limite de reflexions valide.',
        ),
      );
      return;
    }
    if (maxDhikrCategories == null ||
        maxDhikrItems == null ||
        maxDuaCategories == null ||
        maxDuaItems == null ||
        maxDhikrCategories < 0 ||
        maxDhikrItems < 0 ||
        maxDuaCategories < 0 ||
        maxDuaItems < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل حدودًا صحيحة للأذكار والأدعية المخصصة.',
          en: 'Enter valid custom dhikr and dua limits.',
          fr: 'Saisissez des limites valides.',
        ),
      );
      return;
    }

    final updates = <String, dynamic>{};
    if (title != widget.plan.title) {
      updates['title'] = title;
      updates['name'] = title;
    }
    if (monthly != widget.plan.priceMonthly) {
      updates['priceMonthly'] = monthly;
    }
    if (yearly != widget.plan.priceYearly) {
      updates['priceYearly'] = yearly;
    }
    final nextPriceLabel = _buildLegacyPriceLabel(
      monthly: monthly,
      yearly: yearly,
    );
    if (nextPriceLabel !=
        _buildLegacyPriceLabel(
          monthly: widget.plan.priceMonthly,
          yearly: widget.plan.priceYearly,
        )) {
      updates['priceLabel'] = nextPriceLabel;
    }
    if (aiLimit != widget.plan.aiDailyLimit) {
      updates['aiDailyLimit'] = aiLimit;
    }
    if (maxFavorites != widget.plan.maxFavorites) {
      updates['maxFavorites'] = maxFavorites;
    }
    if (maxReflections != widget.plan.maxReflections) {
      updates['maxReflections'] = maxReflections;
    }
    if (maxDhikrCategories != widget.plan.maxCustomDhikrCategories) {
      updates['maxCustomDhikrCategories'] = maxDhikrCategories;
    }
    if (maxDhikrItems != widget.plan.maxCustomDhikrItemsPerCategory) {
      updates['maxCustomDhikrItemsPerCategory'] = maxDhikrItems;
    }
    if (maxDuaCategories != widget.plan.maxCustomDuaCategories) {
      updates['maxCustomDuaCategories'] = maxDuaCategories;
    }
    if (maxDuaItems != widget.plan.maxCustomDuaItemsPerCategory) {
      updates['maxCustomDuaItemsPerCategory'] = maxDuaItems;
    }
    if (_allowQuranAyahMode != widget.plan.allowQuranAyahMode) {
      updates['allowQuranAyahMode'] = _allowQuranAyahMode;
    }
    if (_allowQuranWordMode != widget.plan.allowQuranWordMode) {
      updates['allowQuranWordMode'] = _allowQuranWordMode;
    }
    if (_allowQuranAi != widget.plan.allowQuranAi) {
      updates['allowQuranAi'] = _allowQuranAi;
    }
    if (_allowPremiumThemes != widget.plan.allowPremiumThemes) {
      updates['allowPremiumThemes'] = _allowPremiumThemes;
    }
    if (_isActive != widget.plan.isActive) {
      updates['isActive'] = _isActive;
    }

    Navigator.of(context).pop(updates);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        adminDashText(
          context,
          ar: 'تعديل ${widget.plan.id}',
          en: 'Edit ${widget.plan.id}',
          fr: 'Modifier ${widget.plan.id}',
        ),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'العنوان',
                    en: 'Title',
                    fr: 'Titre',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _monthlyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'السعر الشهري',
                    en: 'Price monthly',
                    fr: 'Prix mensuel',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _yearlyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'السعر السنوي',
                    en: 'Price yearly',
                    fr: 'Prix annuel',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aiLimitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'حد AI اليومي',
                    en: 'AI daily limit',
                    fr: 'Limite IA quotidienne',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _favoritesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'حد المفضلة',
                    en: 'Max favorites',
                    fr: 'Max favoris',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reflectionsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'حد التأملات',
                    en: 'Max reflections',
                    fr: 'Max reflexions',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                adminDashText(
                  context,
                  ar: 'حدود الأذكار والأدعية المخصصة',
                  en: 'Custom dhikr and dua limits',
                  fr: 'Limites dhikr et douaa',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dhikrItemsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'عدد أذكاري',
                          en: 'Dhikr items',
                          fr: 'Dhikr',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duaItemsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'عدد أدعيتي',
                          en: 'Dua items',
                          fr: 'Douaa',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dhikrCategoriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'أقسام الأذكار',
                          en: 'Dhikr groups',
                          fr: 'Groupes dhikr',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duaCategoriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'أقسام الأدعية',
                          en: 'Dua groups',
                          fr: 'Groupes douaa',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'تفعيل وضع آية القرآن',
                    en: 'Allow Quran ayah mode',
                    fr: 'Activer le mode verset',
                  ),
                ),
                value: _allowQuranAyahMode,
                onChanged: (value) {
                  setState(() {
                    _allowQuranAyahMode = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'تفعيل وضع كلمة القرآن',
                    en: 'Allow Quran word mode',
                    fr: 'Activer le mode mot',
                  ),
                ),
                value: _allowQuranWordMode,
                onChanged: (value) {
                  setState(() {
                    _allowQuranWordMode = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'تفعيل AI القرآن',
                    en: 'Allow Quran AI',
                    fr: 'Activer IA Coran',
                  ),
                ),
                value: _allowQuranAi,
                onChanged: (value) {
                  setState(() {
                    _allowQuranAi = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'تفعيل الثيمات المميزة',
                    en: 'Allow premium themes',
                    fr: 'Activer les themes premium',
                  ),
                ),
                value: _allowPremiumThemes,
                onChanged: (value) {
                  setState(() {
                    _allowPremiumThemes = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'الباقة مفعلة',
                    en: 'Plan is active',
                    fr: 'Abonnement actif',
                  ),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            adminDashText(context, ar: 'إلغاء', en: 'Cancel', fr: 'Annuler'),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            adminDashText(context, ar: 'حفظ', en: 'Save', fr: 'Enregistrer'),
          ),
        ),
      ],
    );
  }
}

class _PlanInfoChip extends StatelessWidget {
  const _PlanInfoChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SubscriptionsStateCard extends StatelessWidget {
  const _SubscriptionsStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardCenteredBody(
      maxWidth: 560,
      child: AdminDashboardSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
