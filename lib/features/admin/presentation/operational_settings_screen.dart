import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/models/operational_config.dart';
import '../../../core/models/points_config.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_state_view.dart';
import 'admin_guard.dart';
import 'admin_scaffold.dart';

class OperationalSettingsScreen extends StatefulWidget {
  const OperationalSettingsScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<OperationalSettingsScreen> createState() =>
      _OperationalSettingsScreenState();
}

class _OperationalSettingsScreenState extends State<OperationalSettingsScreen> {
  final _defaultCountryController = TextEditingController();
  final _defaultCityController = TextEditingController();
  final _apiBaseUrlController = TextEditingController();
  final _countriesController = TextEditingController();
  final _defaultLatitudeController = TextEditingController();
  final _defaultLongitudeController = TextEditingController();
  final _adhkarSourceController = TextEditingController();
  final _hadithSourceController = TextEditingController();
  final _textSourceController = TextEditingController();
  final _ayahFreeMinutesController = TextEditingController();
  final _wordFreeMinutesController = TextEditingController();
  final _rewardedAyahMinutesController = TextEditingController();
  final _rewardedWordMinutesController = TextEditingController();

  bool _anonymousEnabled = true;
  bool _googleEnabled = true;
  bool _phoneEnabled = true;
  bool _emailPasswordEnabled = true;
  String _providerType = 'local_calculation';
  String _calculationMethod = 'egyptian';
  String _defaultPlanId = 'free';
  PointsRulesConfig _pointsRules = PointsRulesConfig.defaults;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _defaultCountryController.dispose();
    _defaultCityController.dispose();
    _apiBaseUrlController.dispose();
    _countriesController.dispose();
    _defaultLatitudeController.dispose();
    _defaultLongitudeController.dispose();
    _adhkarSourceController.dispose();
    _hadithSourceController.dispose();
    _textSourceController.dispose();
    _ayahFreeMinutesController.dispose();
    _wordFreeMinutesController.dispose();
    _rewardedAyahMinutesController.dispose();
    _rewardedWordMinutesController.dispose();
    super.dispose();
  }

  void _applyConfig(OperationalConfig config) {
    if (_initialized) {
      return;
    }

    _defaultPlanId = config.defaultUserPlanId;
    _anonymousEnabled = config.authAvailability.anonymousEnabled;
    _googleEnabled = config.authAvailability.googleEnabled;
    _phoneEnabled = config.authAvailability.phoneEnabled;
    _emailPasswordEnabled = config.authAvailability.emailPasswordEnabled;
    _providerType = config.prayerProvider.providerType;
    _calculationMethod = config.prayerProvider.calculationMethod;
    _pointsRules = config.pointsRules;
    _defaultCountryController.text = config.prayerProvider.defaultCountry;
    _defaultCityController.text = config.prayerProvider.defaultCity;
    _apiBaseUrlController.text = config.prayerProvider.apiBaseUrl;
    _countriesController.text = config.prayerProvider.availableCountries.join(
      ', ',
    );
    _defaultLatitudeController.text = config.prayerProvider.defaultLatitude
        .toString();
    _defaultLongitudeController.text = config.prayerProvider.defaultLongitude
        .toString();
    _adhkarSourceController.text = config.contentSources.adhkarSource;
    _hadithSourceController.text = config.contentSources.hadithSource;
    _textSourceController.text = config.contentSources.textSource;
    _ayahFreeMinutesController.text = '${config.quranLimits.ayahFreeMinutes}';
    _wordFreeMinutesController.text = '${config.quranLimits.wordFreeMinutes}';
    _rewardedAyahMinutesController.text =
        '${config.quranLimits.rewardedAyahMinutes}';
    _rewardedWordMinutesController.text =
        '${config.quranLimits.rewardedWordMinutes}';
    _initialized = true;
  }

  int _minutesFromController(TextEditingController controller, int fallback) {
    return (int.tryParse(controller.text.trim()) ?? fallback)
        .clamp(1, 240)
        .toInt();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final config = OperationalConfig(
        defaultUserPlanId: _defaultPlanId,
        pointsRules: _pointsRules,
        authAvailability: AuthAvailability(
          anonymousEnabled: _anonymousEnabled,
          googleEnabled: _googleEnabled,
          phoneEnabled: _phoneEnabled,
          emailPasswordEnabled: _emailPasswordEnabled,
        ),
        prayerProvider: PrayerProviderConfig(
          providerType: _providerType,
          calculationMethod: _calculationMethod,
          apiBaseUrl: _apiBaseUrlController.text.trim(),
          availableCountries: _countriesController.text
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
          defaultCountry: _defaultCountryController.text.trim(),
          defaultCity: _defaultCityController.text.trim(),
          defaultLatitude:
              double.tryParse(_defaultLatitudeController.text.trim()) ??
              30.0444,
          defaultLongitude:
              double.tryParse(_defaultLongitudeController.text.trim()) ??
              31.2357,
        ),
        contentSources: ContentSourcesConfig(
          adhkarSource: _adhkarSourceController.text.trim(),
          hadithSource: _hadithSourceController.text.trim(),
          textSource: _textSourceController.text.trim(),
        ),
        quranLimits: QuranLimitsConfig(
          ayahFreeMinutes: _minutesFromController(
            _ayahFreeMinutesController,
            30,
          ),
          wordFreeMinutes: _minutesFromController(
            _wordFreeMinutesController,
            15,
          ),
          rewardedAyahMinutes: _minutesFromController(
            _rewardedAyahMinutesController,
            30,
          ),
          rewardedWordMinutes: _minutesFromController(
            _rewardedWordMinutesController,
            15,
          ),
        ),
      );

      await widget.services.appConfigRepository.saveOperationalConfig(config);
      await widget.services.analyticsService.trackEvent(
        'admin_operational_config_saved',
        parameters: {'default_plan': _defaultPlanId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات التشغيل بنجاح')),
        );
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
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إعدادات التشغيل',
      currentRoute: AppRouter.adminSettingsRoute,
      services: widget.services,
      firebaseConfigured: widget.firebaseConfigured,
      child: AdminGuard(
        services: widget.services,
        firebaseConfigured: widget.firebaseConfigured,
        child: StreamBuilder(
          stream: widget.services.appConfigRepository.watchOperationalConfig(),
          builder: (context, configSnapshot) {
            if (!widget.firebaseConfigured) {
              return const ErrorStateView(
                title: 'Firebase غير مهيأ',
                message: 'إعدادات التشغيل تحتاج اتصالاً فعلياً بـ Firebase.',
              );
            }

            if (configSnapshot.hasError) {
              return ErrorStateView(
                title: 'تعذر تحميل إعدادات التشغيل',
                message: mapAppErrorToArabic(configSnapshot.error!),
              );
            }

            if (!configSnapshot.hasData) {
              return const LoadingStateView(
                label: 'جارٍ تحميل إعدادات التشغيل',
              );
            }

            final config = configSnapshot.data!;
            _applyConfig(config);

            return StreamBuilder(
              stream: widget.services.planRepository.watchPlans(
                includeInactive: true,
              ),
              builder: (context, plansSnapshot) {
                final plans = plansSnapshot.data ?? const [];

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'هذه الصفحة هي نقطة التشغيل الأولى للإدارة: منها نضبط الخطة الافتراضية، وسائل الدخول، ومصدر إعدادات المواقيت.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _defaultPlanId,
                      decoration: const InputDecoration(
                        labelText: 'الخطة الافتراضية للمستخدم الجديد',
                      ),
                      items:
                          (plans.isEmpty
                                  ? const [
                                      DropdownMenuItem(
                                        value: 'free',
                                        child: Text('free'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'pro',
                                        child: Text('pro'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'plus',
                                        child: Text('plus'),
                                      ),
                                    ]
                                  : plans
                                        .map(
                                          (plan) => DropdownMenuItem(
                                            value: plan.id,
                                            child: Text(plan.name),
                                          ),
                                        )
                                        .toList())
                              .cast<DropdownMenuItem<String>>(),
                      onChanged: (value) {
                        setState(() {
                          _defaultPlanId = value ?? 'free';
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تفعيل وسائل الدخول',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SwitchListTile.adaptive(
                      value: _anonymousEnabled,
                      title: const Text('Anonymous'),
                      onChanged: (value) {
                        setState(() {
                          _anonymousEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: _googleEnabled,
                      title: const Text('Google'),
                      onChanged: (value) {
                        setState(() {
                          _googleEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: _phoneEnabled,
                      title: const Text('Phone'),
                      onChanged: (value) {
                        setState(() {
                          _phoneEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: _emailPasswordEnabled,
                      title: const Text('Email / Password'),
                      onChanged: (value) {
                        setState(() {
                          _emailPasswordEnabled = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'إعدادات مزود المواقيت',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _providerType,
                      decoration: const InputDecoration(
                        labelText: 'نوع المزود',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'local_calculation',
                          child: Text('Local Calculation'),
                        ),
                        DropdownMenuItem(value: 'api', child: Text('API')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _providerType = value ?? 'local_calculation';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _calculationMethod,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الحساب الافتراضية',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'egyptian',
                          child: Text('Egyptian'),
                        ),
                        DropdownMenuItem(
                          value: 'ummAlQura',
                          child: Text('Umm Al-Qura'),
                        ),
                        DropdownMenuItem(
                          value: 'karachi',
                          child: Text('Karachi'),
                        ),
                        DropdownMenuItem(
                          value: 'muslimWorldLeague',
                          child: Text('Muslim World League'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _calculationMethod = value ?? 'egyptian';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'رابط API إن وجد',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countriesController,
                      decoration: const InputDecoration(
                        labelText: 'الدول المتاحة (CSV)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _defaultCountryController,
                      decoration: const InputDecoration(
                        labelText: 'الدولة الافتراضية',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _defaultCityController,
                      decoration: const InputDecoration(
                        labelText: 'المدينة الافتراضية',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _defaultLatitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'خط العرض الافتراضي',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _defaultLongitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'خط الطول الافتراضي',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'مصادر المحتوى',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _adhkarSourceController,
                      decoration: const InputDecoration(
                        labelText: 'مصدر الأذكار',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hadithSourceController,
                      decoration: const InputDecoration(
                        labelText: 'مصدر الحديث',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textSourceController,
                      decoration: const InputDecoration(
                        labelText: 'مصدر النصوص',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'حدود القرآن المجانية',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ayahFreeMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'آيات/اليوم بالدقائق',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _wordFreeMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'كلمات/اليوم بالدقائق',
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
                            controller: _rewardedAyahMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إعلان الآيات بالدقائق',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _rewardedWordMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إعلان الكلمات بالدقائق',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(
                        _isSaving ? 'جارٍ الحفظ...' : 'حفظ إعدادات التشغيل',
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
