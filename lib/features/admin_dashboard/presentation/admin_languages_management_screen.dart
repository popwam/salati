import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_languages_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_language.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminLanguagesManagementScreen extends StatefulWidget {
  const AdminLanguagesManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminLanguagesManagementScreen> createState() =>
      _AdminLanguagesManagementScreenState();
}

class _AdminLanguagesManagementScreenState
    extends State<AdminLanguagesManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminLanguagesRepository _languagesRepository;

  String? _busyLanguageId;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _languagesRepository = FirestoreAdminLanguagesRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _languagesRepository.ensureDefaults();
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_LanguageDialogResult>(
      context: context,
      builder: (context) => const _LanguageDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      await _languagesRepository.createLanguage(
        code: result.code,
        data: result.toCreateData(),
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم إنشاء اللغة.',
          en: 'Language created.',
          fr: 'Langue creee.',
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
    }
  }

  Future<void> _openEditDialog(AdminLanguage language) async {
    final result = await showDialog<_LanguageDialogResult>(
      context: context,
      builder: (context) => _LanguageDialog(initialLanguage: language),
    );
    if (result == null) {
      return;
    }

    final updates = result.toUpdateData(previous: language);
    if (updates.isEmpty) {
      return;
    }

    setState(() {
      _busyLanguageId = language.id;
    });

    try {
      await _languagesRepository.updateLanguage(
        languageId: language.id,
        updates: updates,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث اللغة.',
          en: 'Language updated.',
          fr: 'Langue mise a jour.',
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
          _busyLanguageId = null;
        });
      }
    }
  }

  Future<void> _toggleActive(AdminLanguage language) async {
    if (language.isDefault && language.isActive) {
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'عيّن لغة افتراضية أخرى أولًا.',
          en: 'Set another default language first.',
          fr: 'Definissez dabord une autre langue par defaut.',
        ),
        isError: true,
      );
      return;
    }

    setState(() {
      _busyLanguageId = language.id;
    });

    try {
      await _languagesRepository.updateLanguage(
        languageId: language.id,
        updates: {'isActive': !language.isActive},
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
          _busyLanguageId = null;
        });
      }
    }
  }

  Future<void> _setDefault(AdminLanguage language) async {
    if (language.isDefault) {
      return;
    }

    setState(() {
      _busyLanguageId = language.id;
    });

    try {
      await _languagesRepository.setDefaultLanguage(languageId: language.id);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تعيين ${language.code} كلغة افتراضية.',
          en: '${language.code} is now default.',
          fr: '${language.code} est maintenant la langue par defaut.',
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
          _busyLanguageId = null;
        });
      }
    }
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
            ar: 'اللغات',
            en: 'Languages',
            fr: 'Langues',
          ),
          currentRoute: AppRouter.adminDashboardLanguagesRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminLanguage>>(
            stream: _languagesRepository.watchLanguages(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _LanguagesStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل اللغات',
                    en: 'Unable to load languages',
                    fr: 'Impossible de charger les langues',
                  ),
                  message: mapAppErrorToArabic(snapshot.error!),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final languages = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 760;
                  final cardWidth = constraints.maxWidth >= 1180
                      ? ((constraints.maxWidth - 16) / 2).clamp(320.0, 460.0)
                      : constraints.maxWidth >= 760
                      ? ((constraints.maxWidth - 16) / 2).clamp(300.0, 420.0)
                      : constraints.maxWidth.toDouble();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isCompact)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              adminDashText(
                                context,
                                ar: 'إدارة اللغات النشطة واللغة الافتراضية.',
                                en: 'Manage active languages and the default locale.',
                                fr: 'Gerer les langues actives et la langue par defaut.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _openCreateDialog,
                              icon: const Icon(Icons.add),
                              label: Text(
                                adminDashText(
                                  context,
                                  ar: 'إضافة لغة',
                                  en: 'Add language',
                                  fr: 'Ajouter une langue',
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                adminDashText(
                                  context,
                                  ar: 'إدارة اللغات النشطة واللغة الافتراضية.',
                                  en: 'Manage active languages and the default locale.',
                                  fr: 'Gerer les langues actives et la langue par defaut.',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: _openCreateDialog,
                              icon: const Icon(Icons.add),
                              label: Text(
                                adminDashText(
                                  context,
                                  ar: 'إضافة لغة',
                                  en: 'Add language',
                                  fr: 'Ajouter une langue',
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: languages.isEmpty
                            ? _LanguagesStateCard(
                                title: adminDashText(
                                  context,
                                  ar: 'لا توجد لغات',
                                  en: 'No languages found',
                                  fr: 'Aucune langue trouvee',
                                ),
                                message: adminDashText(
                                  context,
                                  ar: 'أضف أول لغة داخل collection languages.',
                                  en: 'Add the first language in the languages collection.',
                                  fr: 'Ajoutez la premiere langue dans la collection languages.',
                                ),
                              )
                            : ListView(
                                children: [
                                  AdminDashboardGridWrap(
                                    children: languages
                                        .map((language) {
                                          return SizedBox(
                                            width: cardWidth.toDouble(),
                                            child: _LanguageCard(
                                              language: language,
                                              isBusy:
                                                  _busyLanguageId ==
                                                  language.id,
                                              onEdit: _openEditDialog,
                                              onToggleActive: _toggleActive,
                                              onSetDefault: _setDefault,
                                            ),
                                          );
                                        })
                                        .toList(growable: false),
                                  ),
                                ],
                              ),
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

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.isBusy,
    required this.onEdit,
    required this.onToggleActive,
    required this.onSetDefault,
  });

  final AdminLanguage language;
  final bool isBusy;
  final Future<void> Function(AdminLanguage language) onEdit;
  final Future<void> Function(AdminLanguage language) onToggleActive;
  final Future<void> Function(AdminLanguage language) onSetDefault;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      minHeight: 248,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${language.code} - ${language.displayName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(language.nameEnglish),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LanguageChip(
                label: adminLanguageDirectionLabel(language.direction),
              ),
              _LanguageChip(
                label: adminDashText(
                  context,
                  ar: 'ترتيب ${language.order}',
                  en: 'Order ${language.order}',
                  fr: 'Ordre ${language.order}',
                ),
              ),
              _LanguageChip(
                label: language.isActive
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
                color: language.isActive
                    ? Colors.green.shade100
                    : Colors.red.shade100,
              ),
              if (language.isDefault)
                _LanguageChip(
                  label: adminDashText(
                    context,
                    ar: 'افتراضية',
                    en: 'Default',
                    fr: 'Defaut',
                  ),
                  color: Colors.blue.shade100,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : () => onEdit(language),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  adminDashText(
                    context,
                    ar: 'تعديل',
                    en: 'Edit',
                    fr: 'Modifier',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isBusy || language.isDefault
                    ? null
                    : () => onSetDefault(language),
                icon: const Icon(Icons.star_outline),
                label: Text(
                  adminDashText(
                    context,
                    ar: 'افتراضية',
                    en: 'Default',
                    fr: 'Defaut',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : () => onToggleActive(language),
                icon: Icon(
                  language.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                label: Text(
                  language.isActive
                      ? adminDashText(
                          context,
                          ar: 'إيقاف',
                          en: 'Deactivate',
                          fr: 'Desactiver',
                        )
                      : adminDashText(
                          context,
                          ar: 'تفعيل',
                          en: 'Activate',
                          fr: 'Activer',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageDialog extends StatefulWidget {
  const _LanguageDialog({this.initialLanguage});

  final AdminLanguage? initialLanguage;

  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameNativeController;
  late final TextEditingController _nameEnglishController;
  late final TextEditingController _orderController;
  late AdminLanguageDirection _direction;
  late bool _isActive;
  late bool _isDefault;

  bool get _isEditing => widget.initialLanguage != null;

  @override
  void initState() {
    super.initState();
    final initialLanguage = widget.initialLanguage;
    _codeController = TextEditingController(text: initialLanguage?.code ?? '');
    _nameNativeController = TextEditingController(
      text: initialLanguage?.nameNative ?? '',
    );
    _nameEnglishController = TextEditingController(
      text: initialLanguage?.nameEnglish ?? '',
    );
    _orderController = TextEditingController(
      text: '${initialLanguage?.order ?? 0}',
    );
    _direction = initialLanguage?.direction ?? AdminLanguageDirection.rtl;
    _isActive = initialLanguage?.isActive ?? true;
    _isDefault = initialLanguage?.isDefault ?? false;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameNativeController.dispose();
    _nameEnglishController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _showValidationMessage(String message) {
    showAdminDashboardSnackBar(context, message: message, isError: true);
  }

  void _submit() {
    final code = _codeController.text.trim().toLowerCase();
    final nameNative = _nameNativeController.text.trim();
    final nameEnglish = _nameEnglishController.text.trim();
    final order = int.tryParse(_orderController.text.trim());

    if (code.isEmpty) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل كود اللغة.',
          en: 'Enter a valid code.',
          fr: 'Saisissez un code valide.',
        ),
      );
      return;
    }
    if (nameNative.isEmpty && nameEnglish.isEmpty) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل اسم اللغة.',
          en: 'Enter a language name.',
          fr: 'Saisissez un nom de langue.',
        ),
      );
      return;
    }
    if (order == null) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل ترتيبًا صحيحًا.',
          en: 'Enter a valid order.',
          fr: 'Saisissez un ordre valide.',
        ),
      );
      return;
    }
    if (widget.initialLanguage?.isDefault == true && !_isDefault) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'غيّر اللغة الافتراضية أولًا من لغة أخرى.',
          en: 'Change the default from another language first.',
          fr: 'Changez dabord la langue par defaut depuis une autre langue.',
        ),
      );
      return;
    }
    if (_isDefault && !_isActive) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'اللغة الافتراضية يجب أن تكون مفعلة.',
          en: 'Default language must stay active.',
          fr: 'La langue par defaut doit rester active.',
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _LanguageDialogResult(
        code: code,
        nameNative: nameNative,
        nameEnglish: nameEnglish,
        direction: _direction,
        order: order,
        isActive: _isActive,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        adminDashText(
          context,
          ar: _isEditing ? 'تعديل لغة' : 'إضافة لغة',
          en: _isEditing ? 'Edit language' : 'Create language',
          fr: _isEditing ? 'Modifier la langue' : 'Creer une langue',
        ),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                enabled: !_isEditing,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الكود',
                    en: 'Code',
                    fr: 'Code',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameNativeController,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الاسم المحلي',
                    en: 'Native name',
                    fr: 'Nom natif',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEnglishController,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الاسم الإنجليزي',
                    en: 'English name',
                    fr: 'Nom anglais',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdminLanguageDirection>(
                initialValue: _direction,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الاتجاه',
                    en: 'Direction',
                    fr: 'Direction',
                  ),
                ),
                items: AdminLanguageDirection.values
                    .map(
                      (direction) => DropdownMenuItem<AdminLanguageDirection>(
                        value: direction,
                        child: Text(adminLanguageDirectionLabel(direction)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _direction = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الترتيب',
                    en: 'Order',
                    fr: 'Ordre',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'مفعلة',
                    en: 'Active',
                    fr: 'Active',
                  ),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'افتراضية',
                    en: 'Default',
                    fr: 'Defaut',
                  ),
                ),
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value;
                    if (value) {
                      _isActive = true;
                    }
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

class _LanguageDialogResult {
  const _LanguageDialogResult({
    required this.code,
    required this.nameNative,
    required this.nameEnglish,
    required this.direction,
    required this.order,
    required this.isActive,
    required this.isDefault,
  });

  final String code;
  final String nameNative;
  final String nameEnglish;
  final AdminLanguageDirection direction;
  final int order;
  final bool isActive;
  final bool isDefault;

  Map<String, dynamic> toCreateData() {
    return {
      'code': code,
      'nameNative': nameNative,
      'nameEnglish': nameEnglish,
      'direction': adminLanguageDirectionValue(direction),
      'order': order,
      'isActive': isActive,
      'isDefault': isDefault,
    };
  }

  Map<String, dynamic> toUpdateData({required AdminLanguage previous}) {
    final updates = <String, dynamic>{};
    if (nameNative != previous.nameNative) {
      updates['nameNative'] = nameNative;
    }
    if (nameEnglish != previous.nameEnglish) {
      updates['nameEnglish'] = nameEnglish;
    }
    final directionValue = adminLanguageDirectionValue(direction);
    if (directionValue != adminLanguageDirectionValue(previous.direction)) {
      updates['direction'] = directionValue;
    }
    if (order != previous.order) {
      updates['order'] = order;
    }
    if (isActive != previous.isActive) {
      updates['isActive'] = isActive;
    }
    if (isDefault != previous.isDefault) {
      updates['isDefault'] = isDefault;
    }
    return updates;
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, this.color});

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

class _LanguagesStateCard extends StatelessWidget {
  const _LanguagesStateCard({required this.title, required this.message});

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
