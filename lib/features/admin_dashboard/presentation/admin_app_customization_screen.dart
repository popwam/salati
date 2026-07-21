import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/points_config.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_app_config_repository.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../models/admin_app_config.dart';
import '../models/admin_dashboard_access.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminAppCustomizationScreen extends StatefulWidget {
  const AdminAppCustomizationScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminAppCustomizationScreen> createState() =>
      _AdminAppCustomizationScreenState();
}

class _AdminAppCustomizationScreenState
    extends State<AdminAppCustomizationScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminAppConfigRepository _repository;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _repository = FirestoreAdminAppConfigRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
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
          title: 'تخصيص التطبيق',
          currentRoute: AppRouter.adminDashboardAppConfigRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<AdminAppConfig>(
            stream: _repository.watchDraft(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _StateCard(
                  title: 'تعذر تحميل التخصيص',
                  message: mapAppErrorToArabic(snapshot.error!),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _AppCustomizationEditor(
                initialConfig: snapshot.data!,
                repository: _repository,
              );
            },
          ),
        );
      },
    );
  }
}

class _AppCustomizationEditor extends StatefulWidget {
  const _AppCustomizationEditor({
    required this.initialConfig,
    required this.repository,
  });

  final AdminAppConfig initialConfig;
  final FirestoreAdminAppConfigRepository repository;

  @override
  State<_AppCustomizationEditor> createState() =>
      _AppCustomizationEditorState();
}

class _AppCustomizationEditorState extends State<_AppCustomizationEditor> {
  late final TextEditingController _onboardingTitleController;
  late final TextEditingController _onboardingBodyController;
  late final TextEditingController _paywallTitleController;
  late final TextEditingController _paywallBodyController;
  late final TextEditingController _globalMessageController;
  late final TextEditingController _themeNameController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _backgroundColorController;
  late final TextEditingController _surfaceColorController;
  late final TextEditingController _textColorController;
  late final TextEditingController _availableAiTokensController;
  late String _primaryColorHex;
  late String _defaultWidgetStyle;
  late List<String> _homeCardOrder;
  late Set<String> _hiddenHomeSections;
  late Map<String, bool> _featureFlags;
  late PointsRulesConfig _pointsRules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _onboardingTitleController = TextEditingController(
      text: config.onboardingTitle,
    );
    _onboardingBodyController = TextEditingController(
      text: config.onboardingBody,
    );
    _paywallTitleController = TextEditingController(text: config.paywallTitle);
    _paywallBodyController = TextEditingController(text: config.paywallBody);
    _globalMessageController = TextEditingController(
      text: config.globalMessage,
    );
    _themeNameController = TextEditingController(text: config.themeName);
    _primaryColorController = TextEditingController(
      text: config.primaryColorHex,
    );
    _secondaryColorController = TextEditingController(
      text: config.secondaryColorHex,
    );
    _backgroundColorController = TextEditingController(
      text: config.backgroundColorHex,
    );
    _surfaceColorController = TextEditingController(
      text: config.surfaceColorHex,
    );
    _textColorController = TextEditingController(text: config.textColorHex);
    _availableAiTokensController = TextEditingController(
      text: '${config.availableAiTokens}',
    );
    _primaryColorHex = config.primaryColorHex;
    _defaultWidgetStyle = config.defaultWidgetStyle;
    _homeCardOrder = [...config.homeCardOrder];
    _hiddenHomeSections = {...config.hiddenHomeSections};
    _featureFlags = {...config.featureFlags};
    _pointsRules = config.pointsRules;
  }

  @override
  void dispose() {
    _onboardingTitleController.dispose();
    _onboardingBodyController.dispose();
    _paywallTitleController.dispose();
    _paywallBodyController.dispose();
    _globalMessageController.dispose();
    _themeNameController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _backgroundColorController.dispose();
    _surfaceColorController.dispose();
    _textColorController.dispose();
    _availableAiTokensController.dispose();
    super.dispose();
  }

  AdminAppConfig _buildConfig() {
    return widget.initialConfig.copyWith(
      status: 'draft',
      onboardingTitle: _onboardingTitleController.text.trim(),
      onboardingBody: _onboardingBodyController.text.trim(),
      paywallTitle: _paywallTitleController.text.trim(),
      paywallBody: _paywallBodyController.text.trim(),
      globalMessage: _globalMessageController.text.trim(),
      themeName: _themeNameController.text.trim(),
      primaryColorHex: _normalizeHex(_primaryColorController.text),
      secondaryColorHex: _normalizeHex(_secondaryColorController.text),
      backgroundColorHex: _normalizeHex(_backgroundColorController.text),
      surfaceColorHex: _normalizeHex(_surfaceColorController.text),
      textColorHex: _normalizeHex(_textColorController.text),
      defaultWidgetStyle: _defaultWidgetStyle,
      availableAiTokens:
          int.tryParse(_availableAiTokensController.text.trim()) ??
          widget.initialConfig.availableAiTokens,
      homeCardOrder: _homeCardOrder,
      hiddenHomeSections: _hiddenHomeSections,
      featureFlags: _featureFlags,
      pointsRules: _pointsRules,
    );
  }

  String _normalizeHex(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return '#1F9D62';
    }
    return clean.startsWith('#') ? clean : '#$clean';
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _isSaving = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(context, message: 'تم حفظ التخصيص بنجاح.');
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          'تخصيص التطبيق',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'عدّل شكل البداية، رسائل الدفع، أقسام الرئيسية، والميزات التجريبية بدون إصدار جديد.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        AdminDashboardFormSection(
          title: 'معاينة قبل النشر',
          subtitle: 'هذه المعاينة مبنية على draft الحالي.',
          child: _AppConfigPreview(config: _buildConfig()),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'نصوص البداية والدفع',
          child: Column(
            children: [
              TextField(
                controller: _onboardingTitleController,
                decoration: const InputDecoration(labelText: 'عنوان البداية'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _onboardingBodyController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'وصف البداية'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _paywallTitleController,
                decoration: const InputDecoration(labelText: 'عنوان الاشتراك'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _paywallBodyController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'وصف الاشتراك'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _globalMessageController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'رسالة عامة داخل التطبيق',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'الشكل والودجات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    const {
                          '#1F9D62': Color(0xFF1F9D62),
                          '#F5A524': Color(0xFFF5A524),
                          '#4F46E5': Color(0xFF4F46E5),
                          '#E5484D': Color(0xFFE5484D),
                        }.entries
                        .map((entry) {
                          final selected = _primaryColorHex == entry.key;
                          return InkWell(
                            onTap: () => setState(() {
                              _primaryColorHex = entry.key;
                              _primaryColorController.text = entry.key;
                            }),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _themeNameController,
                decoration: const InputDecoration(labelText: 'اسم الثيم'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AdminHexField(
                    controller: _primaryColorController,
                    label: 'Primary',
                    onChanged: (value) => setState(() {
                      _primaryColorHex = _normalizeHex(value);
                    }),
                  ),
                  _AdminHexField(
                    controller: _secondaryColorController,
                    label: 'Secondary',
                    onChanged: (_) => setState(() {}),
                  ),
                  _AdminHexField(
                    controller: _backgroundColorController,
                    label: 'Background',
                    onChanged: (_) => setState(() {}),
                  ),
                  _AdminHexField(
                    controller: _surfaceColorController,
                    label: 'Surface',
                    onChanged: (_) => setState(() {}),
                  ),
                  _AdminHexField(
                    controller: _textColorController,
                    label: 'Text',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ios_soft', label: Text('iOS Soft')),
                  ButtonSegment(value: 'compact', label: Text('Compact')),
                  ButtonSegment(value: 'bold', label: Text('Bold')),
                ],
                selected: {_defaultWidgetStyle},
                onSelectionChanged: (value) {
                  setState(() => _defaultWidgetStyle = value.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'أقسام الرئيسية',
          subtitle: 'رتب الأقسام أو اخف ما لا تريد إظهاره.',
          child: Column(
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _homeCardOrder.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _homeCardOrder.removeAt(oldIndex);
                    _homeCardOrder.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final section = _homeCardOrder[index];
                  return SwitchListTile.adaptive(
                    key: ValueKey(section),
                    value: !_hiddenHomeSections.contains(section),
                    title: Text(_sectionLabel(section)),
                    secondary: const Icon(Icons.drag_indicator_rounded),
                    onChanged: (visible) {
                      setState(() {
                        if (visible) {
                          _hiddenHomeSections.remove(section);
                        } else {
                          _hiddenHomeSections.add(section);
                        }
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'إعدادات الذكاء والتوكن',
          child: TextField(
            controller: _availableAiTokensController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'التوكن المتاح في الصفحة الرئيسية',
              prefixIcon: Icon(Icons.generating_tokens_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'Feature Flags',
          child: Column(
            children: _featureFlags.entries
                .map((entry) {
                  return SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: entry.value,
                    title: Text(_featureLabel(entry.key)),
                    onChanged: (value) {
                      setState(() => _featureFlags[entry.key] = value);
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 16),
        AdminDashboardFormSection(
          title: 'Points Rules',
          subtitle:
              'Manage plan-based rewards used by prayer, adhkar, dua, store, and dashboard flows.',
          child: Column(
            children: ['free', 'plus', 'pro']
                .map((planId) {
                  return _PlanPointsRuleEditor(
                    planId: planId,
                    rule: _pointsRules.ruleForPlan(planId),
                    onChanged: (rule) {
                      setState(() {
                        _pointsRules = PointsRulesConfig(
                          rulesByPlan: {
                            ..._pointsRules.rulesByPlan,
                            planId: rule,
                          },
                        );
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _runAction(
                      () => widget.repository.saveDraft(_buildConfig()),
                    ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ Draft'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isSaving
                  ? null
                  : () => _runAction(
                      () => widget.repository.publishDraft(_buildConfig()),
                    ),
              icon: const Icon(Icons.publish_outlined),
              label: const Text('نشر الآن'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _runAction(
                      widget.repository.rollbackToPreviousPublished,
                    ),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Rollback'),
            ),
          ],
        ),
      ],
    );
  }

  String _sectionLabel(String key) {
    switch (key) {
      case 'next_prayer':
        return 'الصلاة القادمة';
      case 'quick_actions':
        return 'اختصارات اليوم';
      case 'prayer_times':
        return 'مواقيت الصلاة';
      case 'progress':
        return 'تقدم اليوم';
      default:
        return key;
    }
  }

  String _featureLabel(String key) {
    switch (key) {
      case 'quran_ai':
        return 'Quran AI';
      case 'premium_widgets':
        return 'Premium Widgets';
      case 'custom_content':
        return 'Custom Content';
      default:
        return key;
    }
  }
}

class _AppConfigPreview extends StatelessWidget {
  const _AppConfigPreview({required this.config});

  final AdminAppConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _colorFromHex(config.primaryColorHex);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            config.onboardingTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(config.onboardingBody),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(config.defaultWidgetStyle)),
              Chip(label: Text(config.themeName)),
              Chip(label: Text(config.primaryColorHex)),
              Chip(label: Text(config.secondaryColorHex)),
              Chip(label: Text('${config.featureFlags.length} flags')),
              Chip(
                label: Text(
                  'Free prayer +${config.pointsRules.ruleForPlan('free').prayerOnTime}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanPointsRuleEditor extends StatelessWidget {
  const _PlanPointsRuleEditor({
    required this.planId,
    required this.rule,
    required this.onChanged,
  });

  final String planId;
  final PlanPointsRule rule;
  final ValueChanged<PlanPointsRule> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planId.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PointsNumberField(
                label: 'Prayer on-time',
                value: rule.prayerOnTime,
                min: 0,
                max: 1000,
                onChanged: (value) =>
                    onChanged(rule.copyWith(prayerOnTime: value)),
              ),
              _PointsNumberField(
                label: 'Prayer late',
                value: rule.prayerLate,
                min: 0,
                max: 1000,
                onChanged: (value) =>
                    onChanged(rule.copyWith(prayerLate: value)),
              ),
              _PointsNumberField(
                label: 'Missed penalty',
                value: rule.prayerMissed,
                min: -1000,
                max: 0,
                onChanged: (value) =>
                    onChanged(rule.copyWith(prayerMissed: value)),
              ),
              _PointsNumberField(
                label: 'Adhkar',
                value: rule.adhkarCompletion,
                min: 0,
                max: 1000,
                onChanged: (value) =>
                    onChanged(rule.copyWith(adhkarCompletion: value)),
              ),
              _PointsNumberField(
                label: 'Dua',
                value: rule.duaCompletion,
                min: 0,
                max: 1000,
                onChanged: (value) =>
                    onChanged(rule.copyWith(duaCompletion: value)),
              ),
              _PointsNumberField(
                label: 'Qiyam',
                value: rule.qiyamCompletion,
                min: 0,
                max: 1000,
                onChanged: (value) =>
                    onChanged(rule.copyWith(qiyamCompletion: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointsNumberField extends StatelessWidget {
  const _PointsNumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: '$value',
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: false,
        ),
        decoration: InputDecoration(labelText: label),
        onChanged: (text) {
          final parsed = int.tryParse(text.trim());
          if (parsed != null && parsed >= min && parsed <= max) {
            onChanged(parsed);
          }
        },
        validator: (text) {
          final parsed = int.tryParse(text?.trim() ?? '');
          if (parsed == null) {
            return 'Enter a number';
          }
          if (parsed < min || parsed > max) {
            return 'Allowed: $min to $max';
          }
          return null;
        },
      ),
    );
  }
}

class _AdminHexField extends StatelessWidget {
  const _AdminHexField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: '#1F9D62',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _colorFromHex(controller.text),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const SizedBox(width: 18, height: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final clean = value.replaceAll('#', '').trim();
  final parsed = int.tryParse(
    clean.length == 6 ? 'FF$clean' : clean,
    radix: 16,
  );
  return parsed == null ? const Color(0xFF1F9D62) : Color(parsed);
}
