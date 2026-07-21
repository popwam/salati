import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/content_locale_fallback.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_content_repository.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_languages_repository.dart';
import '../models/admin_content_models.dart';
import '../models/admin_language.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminContentManagementConfig {
  const AdminContentManagementConfig({
    required this.title,
    required this.currentRoute,
    required this.requiredPermission,
    required this.collectionPath,
    required this.categoryLabel,
    required this.itemLabel,
    required this.itemTitleEnabled,
    required this.repeatCountEnabled,
  });

  final String title;
  final String currentRoute;
  final String requiredPermission;
  final String collectionPath;
  final String categoryLabel;
  final String itemLabel;
  final bool itemTitleEnabled;
  final bool repeatCountEnabled;
}

class AdminContentManagementScreen extends StatefulWidget {
  const AdminContentManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
    required this.config,
  });

  final AppServices services;
  final bool firebaseConfigured;
  final AdminContentManagementConfig config;

  @override
  State<AdminContentManagementScreen> createState() =>
      _AdminContentManagementScreenState();
}

class _AdminContentManagementScreenState
    extends State<AdminContentManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminContentRepository _contentRepository;
  late final FirestoreAdminLanguagesRepository _languagesRepository;

  String? _selectedCategoryId;
  String? _busyCategoryId;
  String? _busyItemId;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _contentRepository = FirestoreAdminContentRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _languagesRepository = FirestoreAdminLanguagesRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
  }

  void _syncSelectedCategory(List<AdminContentCategory> categories) {
    final nextSelectedId = categories.isEmpty
        ? null
        : categories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : categories.first.id;

    if (nextSelectedId == _selectedCategoryId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCategoryId = nextSelectedId;
      });
    });
  }

  List<AdminLanguage> _effectiveFormLanguages(List<AdminLanguage> languages) {
    final supported = languages
        .where(
          (language) => ContentLocaleFallback.supportedDashboardContentLocales
              .contains(language.code.trim().toLowerCase()),
        )
        .toList(growable: false);
    if (supported.isNotEmpty) {
      return supported;
    }
    return const [
      AdminLanguage(
        id: 'ar',
        code: 'ar',
        nameNative: '\u0627\u0644\u0639\u0631\u0628\u064a\u0629',
        nameEnglish: 'Arabic',
        direction: AdminLanguageDirection.rtl,
        order: 0,
        isActive: true,
        isDefault: true,
        createdAt: null,
        updatedAt: null,
      ),
      AdminLanguage(
        id: 'en',
        code: 'en',
        nameNative: 'English',
        nameEnglish: 'English',
        direction: AdminLanguageDirection.ltr,
        order: 1,
        isActive: true,
        isDefault: false,
        createdAt: null,
        updatedAt: null,
      ),
      AdminLanguage(
        id: 'fr',
        code: 'fr',
        nameNative: 'Fran\u00e7ais',
        nameEnglish: 'French',
        direction: AdminLanguageDirection.ltr,
        order: 2,
        isActive: true,
        isDefault: false,
        createdAt: null,
        updatedAt: null,
      ),
    ];
  }

  Future<void> _createCategory(List<AdminLanguage> languages) async {
    final result = await showDialog<_CategoryDialogResult>(
      context: context,
      builder: (context) => _CategoryDialog(
        categoryLabel: widget.config.categoryLabel,
        languages: languages,
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await _contentRepository.createCategory(
        collectionPath: widget.config.collectionPath,
        data: result.toCreateData(),
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم إنشاء ${widget.config.categoryLabel}.',
          en: '${widget.config.categoryLabel} created.',
          fr: '${widget.config.categoryLabel} cree.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    }
  }

  Future<void> _editCategory(
    AdminContentCategory category,
    List<AdminLanguage> languages,
  ) async {
    final result = await showDialog<_CategoryDialogResult>(
      context: context,
      builder: (context) => _CategoryDialog(
        categoryLabel: widget.config.categoryLabel,
        languages: languages,
        initialCategory: category,
      ),
    );

    if (result == null) {
      return;
    }

    final updates = result.toUpdateData(previous: category);
    if (updates.isEmpty) {
      return;
    }

    setState(() {
      _busyCategoryId = category.id;
    });

    try {
      await _contentRepository.updateCategory(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        updates: updates,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث ${widget.config.categoryLabel}.',
          en: '${widget.config.categoryLabel} updated.',
          fr: '${widget.config.categoryLabel} mis a jour.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyCategoryId = null;
        });
      }
    }
  }

  Future<void> _toggleCategoryStatus(AdminContentCategory category) async {
    setState(() {
      _busyCategoryId = category.id;
    });

    try {
      await _contentRepository.updateCategory(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        updates: {'isActive': !category.isActive},
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyCategoryId = null;
        });
      }
    }
  }

  Future<void> _deleteCategory(AdminContentCategory category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            adminDashText(
              context,
              ar: '­° ${widget.config.categoryLabel}',
              en: 'Delete ${widget.config.categoryLabel}',
              fr: 'Supprimer ${widget.config.categoryLabel}',
            ),
          ),
          content: Text(
            adminDashText(
              context,
              ar: ' ª±Š¯ ­° "${category.displayTitle}"  ${widgetArabicPlural(widget.config.itemLabel)} §ª§¨¹© Ÿ',
              en: 'Delete "${category.displayTitle}" and all nested ${widget.config.itemLabel.toLowerCase()} items?',
              fr: 'Supprimer "${category.displayTitle}" et tous les elements lies ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                adminDashText(
                  context,
                  ar: 'إلغاء',
                  en: 'Cancel',
                  fr: 'Annuler',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                adminDashText(
                  context,
                  ar: '­°',
                  en: 'Delete',
                  fr: 'Supprimer',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _busyCategoryId = category.id;
    });

    try {
      await _contentRepository.deleteCategory(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'ª ­° ${widget.config.categoryLabel}.',
          en: '${widget.config.categoryLabel} deleted.',
          fr: '${widget.config.categoryLabel} supprime.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyCategoryId = null;
        });
      }
    }
  }

  Future<void> _createItem(
    AdminContentCategory category,
    List<AdminLanguage> languages,
  ) async {
    final result = await showDialog<_ItemDialogResult>(
      context: context,
      builder: (context) =>
          _ItemDialog(config: widget.config, languages: languages),
    );

    if (result == null) {
      return;
    }

    try {
      await _contentRepository.createItem(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        data: result.toCreateData(config: widget.config),
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم إنشاء ${widget.config.itemLabel}.',
          en: '${widget.config.itemLabel} created.',
          fr: '${widget.config.itemLabel} cree.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    }
  }

  Future<void> _editItem({
    required AdminContentCategory category,
    required AdminContentItem item,
    required List<AdminLanguage> languages,
  }) async {
    final result = await showDialog<_ItemDialogResult>(
      context: context,
      builder: (context) => _ItemDialog(
        config: widget.config,
        languages: languages,
        initialItem: item,
      ),
    );

    if (result == null) {
      return;
    }

    final updates = result.toUpdateData(config: widget.config, previous: item);
    if (updates.isEmpty) {
      return;
    }

    setState(() {
      _busyItemId = item.id;
    });

    try {
      await _contentRepository.updateItem(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        itemId: item.id,
        updates: updates,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث ${widget.config.itemLabel}.',
          en: '${widget.config.itemLabel} updated.',
          fr: '${widget.config.itemLabel} mis a jour.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _toggleItemStatus({
    required AdminContentCategory category,
    required AdminContentItem item,
  }) async {
    setState(() {
      _busyItemId = item.id;
    });

    try {
      await _contentRepository.updateItem(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        itemId: item.id,
        updates: {'isActive': !item.isActive},
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _deleteItem({
    required AdminContentCategory category,
    required AdminContentItem item,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            adminDashText(
              context,
              ar: '­° ${widget.config.itemLabel}',
              en: 'Delete ${widget.config.itemLabel}',
              fr: 'Supprimer ${widget.config.itemLabel}',
            ),
          ),
          content: Text(
            adminDashText(
              context,
              ar: ' ª±Š¯ ­° "${item.displayTitle}" §¦Š§Ÿ',
              en: 'Delete "${item.displayTitle}" permanently?',
              fr: 'Supprimer definitivement "${item.displayTitle}" ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                adminDashText(
                  context,
                  ar: 'إلغاء',
                  en: 'Cancel',
                  fr: 'Annuler',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                adminDashText(
                  context,
                  ar: '­°',
                  en: 'Delete',
                  fr: 'Supprimer',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _busyItemId = item.id;
    });

    try {
      await _contentRepository.deleteItem(
        collectionPath: widget.config.collectionPath,
        categoryId: category.id,
        itemId: item.id,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'ª ­° ${widget.config.itemLabel}.',
          en: '${widget.config.itemLabel} deleted.',
          fr: '${widget.config.itemLabel} supprime.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
    } finally {
      if (mounted) {
        setState(() {
          _busyItemId = null;
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
      requiredPermission: widget.config.requiredPermission,
      builder: (context, access) {
        return AdminDashboardScaffold(
          title: widget.config.title,
          currentRoute: widget.config.currentRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminLanguage>>(
            stream: _languagesRepository.watchLanguages(activeOnly: true),
            builder: (context, languageSnapshot) {
              if (languageSnapshot.hasError) {
                return _ContentStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل اللغات النشطة',
                    en: 'Unable to load active languages',
                    fr: 'Impossible de charger les langues actives',
                  ),
                  message: mapAppErrorToArabic(languageSnapshot.error!),
                );
              }

              final formLanguages = _effectiveFormLanguages(
                languageSnapshot.data ?? const [],
              );

              return StreamBuilder<List<AdminContentCategory>>(
                stream: _contentRepository.watchCategories(
                  collectionPath: widget.config.collectionPath,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ContentStateCard(
                      title: adminDashText(
                        context,
                        ar: 'تعذر تحميل ${widget.config.categoryLabel}',
                        en: 'Unable to load ${widget.config.categoryLabel.toLowerCase()}s',
                        fr: 'Impossible de charger ${widget.config.categoryLabel}',
                      ),
                      message: mapAppErrorToArabic(snapshot.error!),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = snapshot.data!;
                  _syncSelectedCategory(categories);
                  final selectedCategory = categories
                      .where((category) => category.id == _selectedCategoryId)
                      .firstOrNull;

                  return _FigmaContentBody(
                    config: widget.config,
                    repository: _contentRepository,
                    categories: categories,
                    selectedCategory: selectedCategory,
                    selectedCategoryId: _selectedCategoryId,
                    busyCategoryId: _busyCategoryId,
                    busyItemId: _busyItemId,
                    onCreateCategory: () => _createCategory(formLanguages),
                    onSelectCategory: (category) {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                    },
                    onEditCategory: (category) =>
                        _editCategory(category, formLanguages),
                    onToggleCategoryStatus: _toggleCategoryStatus,
                    onDeleteCategory: _deleteCategory,
                    onCreateItem: (category) =>
                        _createItem(category, formLanguages),
                    onEditItem: ({required category, required item}) =>
                        _editItem(
                          category: category,
                          item: item,
                          languages: formLanguages,
                        ),
                    onToggleItemStatus: _toggleItemStatus,
                    onDeleteItem: _deleteItem,
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

class _FigmaContentBody extends StatelessWidget {
  const _FigmaContentBody({
    required this.config,
    required this.repository,
    required this.categories,
    required this.selectedCategory,
    required this.selectedCategoryId,
    required this.busyCategoryId,
    required this.busyItemId,
    required this.onCreateCategory,
    required this.onSelectCategory,
    required this.onEditCategory,
    required this.onToggleCategoryStatus,
    required this.onDeleteCategory,
    required this.onCreateItem,
    required this.onEditItem,
    required this.onToggleItemStatus,
    required this.onDeleteItem,
  });

  final AdminContentManagementConfig config;
  final FirestoreAdminContentRepository repository;
  final List<AdminContentCategory> categories;
  final AdminContentCategory? selectedCategory;
  final String? selectedCategoryId;
  final String? busyCategoryId;
  final String? busyItemId;
  final Future<void> Function() onCreateCategory;
  final ValueChanged<AdminContentCategory> onSelectCategory;
  final Future<void> Function(AdminContentCategory category) onEditCategory;
  final Future<void> Function(AdminContentCategory category)
  onToggleCategoryStatus;
  final Future<void> Function(AdminContentCategory category) onDeleteCategory;
  final Future<void> Function(AdminContentCategory category) onCreateItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onEditItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onToggleItemStatus;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onDeleteItem;

  bool get _isDua => config.collectionPath.contains('/dua/');

  @override
  Widget build(BuildContext context) {
    final category = selectedCategory;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 640
            ? 3
            : 2;
        return ListView(
          padding: const EdgeInsets.fromLTRB(36, 58, 36, 36),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 26,
                crossAxisSpacing: 26,
                mainAxisExtent: 150,
              ),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return _FigmaAddContentTile(
                    label: _isDua
                        ? '\u0625\u0636\u0627\u0641\u0629 \u062f\u0639\u0627\u0621'
                        : '\u0625\u0636\u0627\u0641\u0629 \u0630\u0643\u0631',
                    onTap: onCreateCategory,
                  );
                }
                final item = categories[index];
                return _FigmaCategoryTile(
                  category: item,
                  selected: item.id == selectedCategoryId,
                  isBusy: item.id == busyCategoryId,
                  onTap: () => onSelectCategory(item),
                  onEdit: () => onEditCategory(item),
                  onToggle: () => onToggleCategoryStatus(item),
                  onDelete: () => onDeleteCategory(item),
                );
              },
            ),
            const SizedBox(height: 34),
            if (category != null)
              _FigmaItemsSection(
                config: config,
                repository: repository,
                category: category,
                busyItemId: busyItemId,
                onCreateItem: onCreateItem,
                onEditItem: onEditItem,
                onToggleItemStatus: onToggleItemStatus,
                onDeleteItem: onDeleteItem,
              ),
          ],
        );
      },
    );
  }
}

class _FigmaCategoryTile extends StatelessWidget {
  const _FigmaCategoryTile({
    required this.category,
    required this.selected,
    required this.isBusy,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminContentCategory category;
  final bool selected;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1C7DFF)
                  : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _contentIconFor(category.icon),
                      size: 44,
                      color: const Color(0xFF1479FF),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        category.displayTitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF2C2C2C),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: PopupMenuButton<String>(
                  tooltip: '\u0625\u062c\u0631\u0627\u0621\u0627\u062a',
                  enabled: !isBusy,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz, size: 18),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle':
                        onToggle();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('\u062a\u0639\u062f\u064a\u0644'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        category.isActive
                            ? '\u0625\u064a\u0642\u0627\u0641'
                            : '\u062a\u0641\u0639\u064a\u0644',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('\u062d\u0630\u0641'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FigmaAddContentTile extends StatelessWidget {
  const _FigmaAddContentTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 48, color: Color(0xFF1479FF)),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaItemsSection extends StatelessWidget {
  const _FigmaItemsSection({
    required this.config,
    required this.repository,
    required this.category,
    required this.busyItemId,
    required this.onCreateItem,
    required this.onEditItem,
    required this.onToggleItemStatus,
    required this.onDeleteItem,
  });

  final AdminContentManagementConfig config;
  final FirestoreAdminContentRepository repository;
  final AdminContentCategory category;
  final String? busyItemId;
  final Future<void> Function(AdminContentCategory category) onCreateItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onEditItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onToggleItemStatus;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: StreamBuilder<List<AdminContentItem>>(
        stream: repository.watchItems(
          collectionPath: config.collectionPath,
          categoryId: category.id,
        ),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <AdminContentItem>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.displayTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => onCreateItem(category),
                    icon: const Icon(Icons.add),
                    label: Text(
                      '\u0625\u0636\u0627\u0641\u0629 ${config.itemLabel}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                _ContentStateCard(
                  title: 'تعذر تحميل البيانات',
                  message: mapAppErrorToArabic(snapshot.error!),
                )
              else if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد عناصر بعد')),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      _FigmaItemChip(
                        item: item,
                        isBusy: item.id == busyItemId,
                        onEdit: () =>
                            onEditItem(category: category, item: item),
                        onToggle: () =>
                            onToggleItemStatus(category: category, item: item),
                        onDelete: () =>
                            onDeleteItem(category: category, item: item),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FigmaItemChip extends StatelessWidget {
  const _FigmaItemChip({
    required this.item,
    required this.isBusy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminContentItem item;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: isBusy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
          ),
          Expanded(
            child: InkWell(
              onTap: isBusy ? null : onEdit,
              child: Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Text(
            '${item.repeatCount ?? 1}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: isBusy ? null : onToggle,
            icon: Icon(
              item.isActive ? Icons.toggle_on : Icons.toggle_off,
              color: item.isActive ? const Color(0xFF1479FF) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _contentIconFor(String value) {
  switch (value) {
    case 'wb_sunny_outlined':
      return Icons.wb_sunny_outlined;
    case 'light_mode_outlined':
      return Icons.light_mode_outlined;
    case 'dark_mode_outlined':
      return Icons.dark_mode_outlined;
    case 'nights_stay_outlined':
      return Icons.nights_stay_outlined;
    case 'bedtime_outlined':
      return Icons.bedtime_outlined;
    case 'hotel_outlined':
      return Icons.hotel_outlined;
    case 'volunteer_activism_outlined':
      return Icons.volunteer_activism_outlined;
    case 'favorite_outline':
      return Icons.favorite_outline;
    case 'flight_takeoff_outlined':
      return Icons.flight_takeoff_outlined;
    case 'sentiment_dissatisfied_outlined':
      return Icons.sentiment_dissatisfied_outlined;
    case 'emoji_events_outlined':
      return Icons.emoji_events_outlined;
    case 'mosque_outlined':
      return Icons.mosque_outlined;
    case 'menu_book_outlined':
      return Icons.menu_book_outlined;
    case 'water_drop_outlined':
      return Icons.water_drop_outlined;
    case 'restaurant_outlined':
      return Icons.restaurant_outlined;
    case 'home_outlined':
      return Icons.home_outlined;
    case 'shield_outlined':
      return Icons.shield_outlined;
    case 'star_outline':
      return Icons.star_outline;
    case 'eco_outlined':
      return Icons.eco_outlined;
    case 'opacity_outlined':
      return Icons.opacity_outlined;
    case 'groups_outlined':
      return Icons.groups_outlined;
    case 'work_outline':
      return Icons.work_outline;
    case 'local_florist_outlined':
      return Icons.local_florist_outlined;
    case 'waves_outlined':
      return Icons.waves_outlined;
    default:
      return Icons.self_improvement_outlined;
  }
}

class _FigmaLanguageTabs extends StatelessWidget {
  const _FigmaLanguageTabs({
    required this.languages,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<AdminLanguage> languages;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = languages
        .where((language) => const {'ar', 'en', 'fr'}.contains(language.code))
        .toList(growable: false);
    final tabs = visible.isEmpty ? languages : visible;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final language in tabs) ...[
            _FigmaLanguageButton(
              label: _languageLabel(language.code),
              selected: language.code == selectedCode,
              onTap: () => onSelected(language.code),
            ),
            if (language != tabs.last) const SizedBox(width: 18),
          ],
        ],
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'ar':
        return '\u0627\u0644\u0639\u0631\u0628\u064a\u0629';
      case 'fr':
        return 'Fran\u00e7ais';
      default:
        return 'English';
    }
  }
}

class _FigmaLanguageButton extends StatelessWidget {
  const _FigmaLanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF1479FF)
              : const Color(0xFFEAF3FF),
          foregroundColor: selected ? Colors.white : const Color(0xFF111827),
          side: BorderSide(
            color: selected ? const Color(0xFF1479FF) : const Color(0xFF98C5FF),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _FigmaDialogField extends StatelessWidget {
  const _FigmaDialogField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}

// Kept as a fallback for compact admin maintenance flows.
// ignore: unused_element
class _CategoriesPane extends StatelessWidget {
  const _CategoriesPane({
    required this.config,
    required this.categories,
    required this.selectedCategoryId,
    required this.busyCategoryId,
    required this.onCreateCategory,
    required this.onSelectCategory,
    required this.onEditCategory,
    required this.onToggleCategoryStatus,
    required this.onDeleteCategory,
  });

  final AdminContentManagementConfig config;
  final List<AdminContentCategory> categories;
  final String? selectedCategoryId;
  final String? busyCategoryId;
  final Future<void> Function() onCreateCategory;
  final ValueChanged<AdminContentCategory> onSelectCategory;
  final Future<void> Function(AdminContentCategory category) onEditCategory;
  final Future<void> Function(AdminContentCategory category)
  onToggleCategoryStatus;
  final Future<void> Function(AdminContentCategory category) onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    adminDashText(
                      context,
                      ar: widgetArabicPlural(config.categoryLabel),
                      en: '${config.categoryLabel}s',
                      fr: widgetFrenchPlural(config.categoryLabel),
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreateCategory,
                  icon: const Icon(Icons.add),
                  label: Text(
                    adminDashText(
                      context,
                      ar: '¥¶§© ${config.categoryLabel}',
                      en: 'Add ${config.categoryLabel}',
                      fr: 'Ajouter ${config.categoryLabel}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        adminDashText(
                          context,
                          ar: 'لا توجد ${config.categoryLabel} بعد.',
                          en: 'No ${config.categoryLabel.toLowerCase()} categories found yet.',
                          fr: 'Aucune categorie ${config.categoryLabel} pour le moment.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category.id == selectedCategoryId;
                      final isBusy = category.id == busyCategoryId;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelectCategory(category),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withAlpha(40),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.displayTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (isBusy)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ContentInfoChip(
                                    label: adminDashText(
                                      context,
                                      ar: 'ترتيب ${category.order}',
                                      en: 'Order ${category.order}',
                                      fr: 'Ordre ${category.order}',
                                    ),
                                  ),
                                  _ContentInfoChip(
                                    label: category.isActive
                                        ? adminDashText(
                                            context,
                                            ar: '¹©',
                                            en: 'Active',
                                            fr: 'Active',
                                          )
                                        : adminDashText(
                                            context,
                                            ar: 'ª©',
                                            en: 'Inactive',
                                            fr: 'Inactive',
                                          ),
                                    color: category.isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                  ),
                                  if (category.accessPlan != null)
                                    _ContentInfoChip(
                                      label: adminDashText(
                                        context,
                                        ar: 'الخطة ${category.accessPlan}',
                                        en: 'Plan ${category.accessPlan}',
                                        fr: 'Plan ${category.accessPlan}',
                                      ),
                                    ),
                                  if (category.icon.isNotEmpty)
                                    _ContentInfoChip(
                                      label: adminDashText(
                                        context,
                                        ar: 'الأيقونة ${category.icon}',
                                        en: 'Icon ${category.icon}',
                                        fr: 'Icone ${category.icon}',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => onSelectCategory(category),
                                    icon: const Icon(Icons.list_alt_outlined),
                                    label: Text(
                                      adminDashText(
                                        context,
                                        ar: 'عرض ${widgetArabicPlural(config.itemLabel)}',
                                        en: 'View ${config.itemLabel}s',
                                        fr: 'Voir ${widgetFrenchPlural(config.itemLabel)}',
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: isBusy
                                        ? null
                                        : () => onEditCategory(category),
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
                                  IconButton(
                                    tooltip: category.isActive
                                        ? adminDashText(
                                            context,
                                            ar: '¥Š§',
                                            en: 'Disable',
                                            fr: 'Desactiver',
                                          )
                                        : adminDashText(
                                            context,
                                            ar: 'ª¹Š',
                                            en: 'Enable',
                                            fr: 'Activer',
                                          ),
                                    onPressed: isBusy
                                        ? null
                                        : () =>
                                              onToggleCategoryStatus(category),
                                    icon: Icon(
                                      category.isActive
                                          ? Icons.toggle_on_outlined
                                          : Icons.toggle_off_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: adminDashText(
                                      context,
                                      ar: '­°',
                                      en: 'Delete',
                                      fr: 'Supprimer',
                                    ),
                                    onPressed: isBusy
                                        ? null
                                        : () => onDeleteCategory(category),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Kept as a fallback for compact admin maintenance flows.
// ignore: unused_element
class _ItemsPane extends StatelessWidget {
  const _ItemsPane({
    required this.config,
    required this.repository,
    required this.category,
    required this.busyItemId,
    required this.onCreateItem,
    required this.onEditItem,
    required this.onToggleItemStatus,
    required this.onDeleteItem,
  });

  final AdminContentManagementConfig config;
  final FirestoreAdminContentRepository repository;
  final AdminContentCategory? category;
  final String? busyItemId;
  final Future<void> Function(AdminContentCategory category) onCreateItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onEditItem;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onToggleItemStatus;
  final Future<void> Function({
    required AdminContentCategory category,
    required AdminContentItem item,
  })
  onDeleteItem;

  @override
  Widget build(BuildContext context) {
    if (category == null) {
      return _ContentStateCard(
        title: adminDashText(
          context,
          ar: 'اختر ${config.categoryLabel}',
          en: 'Select a ${config.categoryLabel.toLowerCase()}',
          fr: 'Selectionnez ${config.categoryLabel}',
        ),
        message: adminDashText(
          context,
          ar: 'اختر ${config.categoryLabel} لإدارة ${widgetArabicPlural(config.itemLabel)}.',
          en: 'Choose a ${config.categoryLabel.toLowerCase()} to manage its ${config.itemLabel.toLowerCase()} items.',
          fr: 'Choisissez ${config.categoryLabel} pour gerer ses elements.',
        ),
      );
    }

    final selectedCategory = category!;

    return AdminDashboardSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCategory.displayTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminDashText(
                          context,
                          ar: '${widgetArabicPlural(config.itemLabel)} داخل ${config.categoryLabel}',
                          en: 'Items in ${config.categoryLabel.toLowerCase()}',
                          fr: 'Elements dans ${config.categoryLabel}',
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => onCreateItem(selectedCategory),
                  icon: const Icon(Icons.add),
                  label: Text(
                    adminDashText(
                      context,
                      ar: '¥¶§© ${config.itemLabel}',
                      en: 'Add ${config.itemLabel}',
                      fr: 'Ajouter ${config.itemLabel}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<AdminContentItem>>(
              stream: repository.watchItems(
                collectionPath: config.collectionPath,
                categoryId: selectedCategory.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ContentStateCard(
                    title: adminDashText(
                      context,
                      ar: 'تعذر تحميل ${widgetArabicPlural(config.itemLabel)}',
                      en: 'Unable to load ${config.itemLabel.toLowerCase()} items',
                      fr: 'Impossible de charger ${widgetFrenchPlural(config.itemLabel)}',
                    ),
                    message: mapAppErrorToArabic(snapshot.error!),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        adminDashText(
                          context,
                          ar: '§ ª¬¯ ${widgetArabicPlural(config.itemLabel)} Š °§ §³ ¨¹¯.',
                          en: 'No ${config.itemLabel.toLowerCase()} items found in this ${config.categoryLabel.toLowerCase()} yet.',
                          fr: 'Aucun element ${config.itemLabel} dans cette categorie pour le moment.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isBusy = item.id == busyItemId;

                    return AdminDashboardSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.displayTitle,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (isBusy)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          if (item.textAr.isNotEmpty ||
                              item.textEn.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_buildPreview(item.textAr, item.textEn)),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ContentInfoChip(
                                label: adminDashText(
                                  context,
                                  ar: 'ترتيب ${item.order}',
                                  en: 'Order ${item.order}',
                                  fr: 'Ordre ${item.order}',
                                ),
                              ),
                              _ContentInfoChip(
                                label: item.isActive
                                    ? adminDashText(
                                        context,
                                        ar: '¹',
                                        en: 'Active',
                                        fr: 'Active',
                                      )
                                    : adminDashText(
                                        context,
                                        ar: 'ª',
                                        en: 'Inactive',
                                        fr: 'Inactive',
                                      ),
                                color: item.isActive
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                              ),
                              if (config.repeatCountEnabled &&
                                  item.repeatCount != null)
                                _ContentInfoChip(
                                  label: adminDashText(
                                    context,
                                    ar: 'التكرار ${item.repeatCount}',
                                    en: 'Repeat ${item.repeatCount}',
                                    fr: 'Repetition ${item.repeatCount}',
                                  ),
                                ),
                              if (item.source.isNotEmpty)
                                _ContentInfoChip(
                                  label: adminDashText(
                                    context,
                                    ar: 'المصدر ${item.source}',
                                    en: 'Source ${item.source}',
                                    fr: 'Source ${item.source}',
                                  ),
                                ),
                              if (item.accessPlan != null)
                                _ContentInfoChip(
                                  label: adminDashText(
                                    context,
                                    ar: 'الخطة ${item.accessPlan}',
                                    en: 'Plan ${item.accessPlan}',
                                    fr: 'Plan ${item.accessPlan}',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: isBusy
                                    ? null
                                    : () => onEditItem(
                                        category: selectedCategory,
                                        item: item,
                                      ),
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
                              IconButton(
                                tooltip: item.isActive
                                    ? adminDashText(
                                        context,
                                        ar: '¥Š§',
                                        en: 'Disable',
                                        fr: 'Desactiver',
                                      )
                                    : adminDashText(
                                        context,
                                        ar: 'ª¹Š',
                                        en: 'Enable',
                                        fr: 'Activer',
                                      ),
                                onPressed: isBusy
                                    ? null
                                    : () => onToggleItemStatus(
                                        category: selectedCategory,
                                        item: item,
                                      ),
                                icon: Icon(
                                  item.isActive
                                      ? Icons.toggle_on_outlined
                                      : Icons.toggle_off_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: adminDashText(
                                  context,
                                  ar: '­°',
                                  en: 'Delete',
                                  fr: 'Supprimer',
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () => onDeleteItem(
                                        category: selectedCategory,
                                        item: item,
                                      ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildPreview(String arabic, String english) {
    final source = arabic.trim().isNotEmpty ? arabic.trim() : english.trim();
    if (source.length <= 180) {
      return source;
    }
    return '${source.substring(0, 180)}...';
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.categoryLabel,
    required this.languages,
    this.initialCategory,
  });

  final String categoryLabel;
  final List<AdminLanguage> languages;
  final AdminContentCategory? initialCategory;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  static const _categoryIconOptions = <String>[
    'self_improvement_outlined',
    'wb_sunny_outlined',
    'light_mode_outlined',
    'dark_mode_outlined',
    'nights_stay_outlined',
    'bedtime_outlined',
    'hotel_outlined',
    'volunteer_activism_outlined',
    'favorite_outline',
    'flight_takeoff_outlined',
    'sentiment_dissatisfied_outlined',
    'mosque_outlined',
    'menu_book_outlined',
    'water_drop_outlined',
    'restaurant_outlined',
    'home_outlined',
    'shield_outlined',
    'star_outline',
    'eco_outlined',
    'opacity_outlined',
    'groups_outlined',
    'work_outline',
    'local_florist_outlined',
    'waves_outlined',
  ];

  late final Map<String, TextEditingController> _titleControllers;
  late final Map<String, TextEditingController> _descriptionControllers;
  late final TextEditingController _iconController;
  late final TextEditingController _orderController;
  late final TextEditingController _accessPlanController;
  late bool _isActive;
  late String _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initialCategory;
    _titleControllers = {
      for (final language in widget.languages)
        language.code: TextEditingController(
          text: _initialCategoryTitle(initialCategory, language.code),
        ),
    };
    _descriptionControllers = {
      for (final language in widget.languages)
        language.code: TextEditingController(
          text: initialCategory?.translations[language.code]?.description ?? '',
        ),
    };
    _iconController = TextEditingController(text: initialCategory?.icon ?? '');
    _orderController = TextEditingController(
      text: '${initialCategory?.order ?? 0}',
    );
    _accessPlanController = TextEditingController(
      text: initialCategory?.accessPlan ?? '',
    );
    _isActive = initialCategory?.isActive ?? true;
    _selectedLanguageCode = widget.languages.first.code;
    if (_iconController.text.trim().isEmpty) {
      _iconController.text = _categoryIconOptions.first;
    }
  }

  @override
  void dispose() {
    for (final controller in _titleControllers.values) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers.values) {
      controller.dispose();
    }
    _iconController.dispose();
    _orderController.dispose();
    _accessPlanController.dispose();
    super.dispose();
  }

  String _initialCategoryTitle(
    AdminContentCategory? category,
    String languageCode,
  ) {
    if (category == null) {
      return '';
    }
    final translated = category.translations[languageCode]?.title;
    if (translated?.trim().isNotEmpty == true) {
      return translated!.trim();
    }
    switch (languageCode) {
      case 'ar':
        return category.titleAr;
      case 'en':
        return category.titleEn;
      default:
        return '';
    }
  }

  IconData _iconDataFor(String value) {
    switch (value) {
      case 'wb_sunny_outlined':
        return Icons.wb_sunny_outlined;
      case 'light_mode_outlined':
        return Icons.light_mode_outlined;
      case 'dark_mode_outlined':
        return Icons.dark_mode_outlined;
      case 'nights_stay_outlined':
        return Icons.nights_stay_outlined;
      case 'bedtime_outlined':
        return Icons.bedtime_outlined;
      case 'hotel_outlined':
        return Icons.hotel_outlined;
      case 'volunteer_activism_outlined':
        return Icons.volunteer_activism_outlined;
      case 'favorite_outline':
        return Icons.favorite_outline;
      case 'flight_takeoff_outlined':
        return Icons.flight_takeoff_outlined;
      case 'sentiment_dissatisfied_outlined':
        return Icons.sentiment_dissatisfied_outlined;
      case 'mosque_outlined':
        return Icons.mosque_outlined;
      case 'menu_book_outlined':
        return Icons.menu_book_outlined;
      case 'water_drop_outlined':
        return Icons.water_drop_outlined;
      case 'restaurant_outlined':
        return Icons.restaurant_outlined;
      case 'home_outlined':
        return Icons.home_outlined;
      case 'shield_outlined':
        return Icons.shield_outlined;
      case 'star_outline':
        return Icons.star_outline;
      case 'eco_outlined':
        return Icons.eco_outlined;
      case 'opacity_outlined':
        return Icons.opacity_outlined;
      case 'groups_outlined':
        return Icons.groups_outlined;
      case 'work_outline':
        return Icons.work_outline;
      case 'local_florist_outlined':
        return Icons.local_florist_outlined;
      case 'waves_outlined':
        return Icons.waves_outlined;
      default:
        return Icons.self_improvement_outlined;
    }
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final order = int.tryParse(_orderController.text.trim());
    if (order == null) {
      _showValidationMessage('Enter a valid order value.');
      return;
    }

    final hasAtLeastOneTitle = _titleControllers.values.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (!hasAtLeastOneTitle) {
      _showValidationMessage('Provide at least one category title.');
      return;
    }

    Navigator.of(context).pop(
      _CategoryDialogResult(
        translations: {
          for (final language in widget.languages)
            language.code: AdminContentTranslation(
              title: _titleControllers[language.code]!.text.trim(),
              description: _descriptionControllers[language.code]!.text.trim(),
            ),
        },
        icon: _iconController.text.trim(),
        order: order,
        isActive: _isActive,
        accessPlan: _accessPlanController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialCategory != null;
    final selectedLanguage = widget.languages.firstWhere(
      (language) => language.code == _selectedLanguageCode,
      orElse: () => widget.languages.first,
    );
    if (DateTime.now().microsecondsSinceEpoch != -1) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEditing
              ? '\u062A\u0639\u062F\u064A\u0644 \u0627\u0644\u0642\u0633\u0645'
              : '\u0625\u0636\u0627\u0641\u0629 \u0642\u0633\u0645',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FigmaLanguageTabs(
                  languages: widget.languages,
                  selectedCode: _selectedLanguageCode,
                  onSelected: (code) {
                    setState(() {
                      _selectedLanguageCode = code;
                    });
                  },
                ),
                const SizedBox(height: 28),
                _FigmaDialogField(
                  controller: _titleControllers[selectedLanguage.code]!,
                  label: selectedLanguage.code == 'ar'
                      ? '\u0627\u0633\u0645 \u0627\u0644\u0639\u0631\u0636'
                      : selectedLanguage.code == 'fr'
                      ? 'Nom d\u2019affichage'
                      : 'Display name',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _iconController.text.trim().isEmpty
                      ? _categoryIconOptions.first
                      : _iconController.text.trim(),
                  decoration: const InputDecoration(
                    labelText:
                        '\u0627\u0644\u0623\u064A\u0642\u0648\u0646\u0629',
                  ),
                  items: _categoryIconOptions
                      .map(
                        (iconValue) => DropdownMenuItem(
                          value: iconValue,
                          child: Row(
                            children: [
                              Icon(_iconDataFor(iconValue)),
                              const SizedBox(width: 10),
                              Text(iconValue),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _iconController.text = value ?? _iconController.text;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FigmaDialogField(
                        controller: _orderController,
                        label:
                            '\u0639\u062F\u062F \u0627\u0644\u0646\u0642\u0627\u0637',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _accessPlanController.text.trim().isEmpty
                            ? ''
                            : _accessPlanController.text.trim(),
                        decoration: const InputDecoration(
                          labelText:
                              '\u0627\u0644\u0627\u0634\u062A\u0631\u0627\u0643',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('\u0645\u062C\u0627\u0646\u064A'),
                          ),
                          DropdownMenuItem(value: 'plus', child: Text('Plus')),
                          DropdownMenuItem(value: 'pro', child: Text('Pro')),
                        ],
                        onChanged: (value) {
                          _accessPlanController.text = value ?? '';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('\u0645\u0641\u0639\u0644'),
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
            child: const Text('\u0625\u0644\u063A\u0627\u0621'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('\u062D\u0641\u0638'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({
    required this.config,
    required this.languages,
    this.initialItem,
  });

  final AdminContentManagementConfig config;
  final List<AdminLanguage> languages;
  final AdminContentItem? initialItem;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final Map<String, TextEditingController> _titleControllers;
  late final Map<String, TextEditingController> _textControllers;
  late final Map<String, TextEditingController> _sourceControllers;
  late final TextEditingController _repeatCountController;
  late final TextEditingController _orderController;
  late final TextEditingController _accessPlanController;
  late bool _isActive;
  late String _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleControllers = {
      for (final language in widget.languages)
        language.code: TextEditingController(
          text: _initialItemTitle(item, language.code),
        ),
    };
    _textControllers = {
      for (final language in widget.languages)
        language.code: TextEditingController(
          text: _initialItemText(item, language.code),
        ),
    };
    _sourceControllers = {
      for (final language in widget.languages)
        language.code: TextEditingController(
          text: _initialItemSource(item, language.code),
        ),
    };
    _repeatCountController = TextEditingController(
      text: item?.repeatCount?.toString() ?? '1',
    );
    _orderController = TextEditingController(text: '${item?.order ?? 0}');
    _accessPlanController = TextEditingController(text: item?.accessPlan ?? '');
    _isActive = item?.isActive ?? true;
    _selectedLanguageCode = widget.languages.first.code;
  }

  @override
  void dispose() {
    for (final controller in _titleControllers.values) {
      controller.dispose();
    }
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controller in _sourceControllers.values) {
      controller.dispose();
    }
    _repeatCountController.dispose();
    _orderController.dispose();
    _accessPlanController.dispose();
    super.dispose();
  }

  String _initialItemTitle(AdminContentItem? item, String languageCode) {
    if (item == null) {
      return '';
    }
    final translated = item.translations[languageCode]?.title;
    if (translated?.trim().isNotEmpty == true) {
      return translated!.trim();
    }
    switch (languageCode) {
      case 'ar':
        return item.titleAr;
      case 'en':
        return item.titleEn;
      default:
        return '';
    }
  }

  String _initialItemText(AdminContentItem? item, String languageCode) {
    if (item == null) {
      return '';
    }
    final translated = item.translations[languageCode]?.text;
    if (translated?.trim().isNotEmpty == true) {
      return translated!.trim();
    }
    switch (languageCode) {
      case 'ar':
        return item.textAr;
      case 'en':
        return item.textEn;
      default:
        return '';
    }
  }

  String _initialItemSource(AdminContentItem? item, String languageCode) {
    if (item == null) {
      return '';
    }
    final translated = item.translations[languageCode]?.source;
    if (translated?.trim().isNotEmpty == true) {
      return translated!.trim();
    }
    return item.source;
  }

  void _copySharedSourceToEmptyLanguages() {
    final sharedSource = _sourceControllers['ar']?.text.trim() ?? '';
    if (sharedSource.isEmpty) {
      return;
    }
    for (final entry in _sourceControllers.entries) {
      if (entry.value.text.trim().isEmpty) {
        entry.value.text = sharedSource;
      }
    }
  }

  String get _sourceLabel {
    return widget.config.collectionPath.contains('/dua/')
        ? '\u0641\u0636\u0644 \u0627\u0644\u062f\u0639\u0627\u0621'
        : '\u0641\u0636\u0644 \u0627\u0644\u0630\u0643\u0631';
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    _copySharedSourceToEmptyLanguages();

    final order = int.tryParse(_orderController.text.trim());
    if (order == null) {
      _showValidationMessage('Enter a valid order value.');
      return;
    }

    int? repeatCount;
    if (widget.config.repeatCountEnabled) {
      repeatCount = int.tryParse(_repeatCountController.text.trim());
      if (repeatCount == null || repeatCount <= 0) {
        _showValidationMessage('Enter a valid repeat count.');
        return;
      }
    }

    final hasAtLeastOneText = _textControllers.values.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (!hasAtLeastOneText) {
      _showValidationMessage('Provide text in at least one language.');
      return;
    }

    Navigator.of(context).pop(
      _ItemDialogResult(
        translations: {
          for (final language in widget.languages)
            language.code: AdminContentTranslation(
              title: _titleControllers[language.code]!.text.trim(),
              text: _textControllers[language.code]!.text.trim(),
              source: _sourceControllers[language.code]!.text.trim(),
            ),
        },
        repeatCount: widget.config.repeatCountEnabled ? repeatCount : null,
        order: order,
        isActive: _isActive,
        accessPlan: _accessPlanController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;
    final selectedLanguage = widget.languages.firstWhere(
      (language) => language.code == _selectedLanguageCode,
      orElse: () => widget.languages.first,
    );
    if (DateTime.now().microsecondsSinceEpoch != -1) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          '${isEditing ? '\u062A\u0639\u062F\u064A\u0644' : '\u0625\u0636\u0627\u0641\u0629'} ${widget.config.itemLabel}',
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FigmaLanguageTabs(
                  languages: widget.languages,
                  selectedCode: _selectedLanguageCode,
                  onSelected: (code) {
                    setState(() {
                      _selectedLanguageCode = code;
                    });
                  },
                ),
                const SizedBox(height: 28),
                _FigmaDialogField(
                  controller: _textControllers[selectedLanguage.code]!,
                  label: selectedLanguage.code == 'ar'
                      ? '\u0627\u0633\u0645 \u0627\u0644\u0630\u0643\u0631'
                      : selectedLanguage.code == 'fr'
                      ? 'Nom d\u2019affichage'
                      : 'Display name',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _FigmaDialogField(
                  controller: _sourceControllers[selectedLanguage.code]!,
                  label: _sourceLabel,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                if (widget.config.repeatCountEnabled)
                  _FigmaDialogField(
                    controller: _repeatCountController,
                    label:
                        '\u0639\u062F\u062F \u0627\u0644\u0645\u0631\u0627\u062A',
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('\u0645\u0641\u0639\u0644'),
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
            child: const Text('\u0625\u0644\u063A\u0627\u0621'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('\u062D\u0641\u0638'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(
        adminDashText(
          context,
          ar: '${isEditing ? 'ª¹¯Š' : '¥¶§©'} ${widget.config.itemLabel}',
          en: '${isEditing ? 'Edit' : 'Create'} ${widget.config.itemLabel}',
          fr: '${isEditing ? 'Modifier' : 'Creer'} ${widget.config.itemLabel}',
        ),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(ContentLocaleFallback.dashboardLanguageNote),
              const SizedBox(height: 12),
              AdminDashboardFormSection(
                title: adminDashText(
                  context,
                  ar: 'المحتوى والترجمة',
                  en: 'Content and translation',
                  fr: 'Contenu et traduction',
                ),
                subtitle:
                    '${selectedLanguage.nameNative} / ${selectedLanguage.nameEnglish}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.languages
                          .map((language) {
                            return ChoiceChip(
                              label: Text(language.code.toUpperCase()),
                              selected: language.code == _selectedLanguageCode,
                              onSelected: (_) {
                                setState(() {
                                  _selectedLanguageCode = language.code;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                    if (widget.config.itemTitleEnabled) ...[
                      TextField(
                        controller: _titleControllers[selectedLanguage.code],
                        decoration: InputDecoration(
                          labelText: adminDashText(
                            context,
                            ar: 'العنوان (${selectedLanguage.code})',
                            en: 'Title (${selectedLanguage.code})',
                            fr: 'Titre (${selectedLanguage.code})',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _textControllers[selectedLanguage.code],
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'النص (${selectedLanguage.code})',
                          en: 'Text (${selectedLanguage.code})',
                          fr: 'Texte (${selectedLanguage.code})',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sourceControllers[selectedLanguage.code],
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'المصدر (${selectedLanguage.code})',
                          en: 'Source (${selectedLanguage.code})',
                          fr: 'Source (${selectedLanguage.code})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminDashboardFormSection(
                title: adminDashText(
                  context,
                  ar: 'الإعدادات',
                  en: 'Settings',
                  fr: 'Reglages',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.config.repeatCountEnabled) ...[
                      TextField(
                        controller: _repeatCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: adminDashText(
                            context,
                            ar: 'عدد التكرار',
                            en: 'Repeat count',
                            fr: 'Nombre de repetitions',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
                    Text(
                      adminDashText(
                        context,
                        ar: 'خطة الوصول',
                        en: 'Access plan',
                        fr: 'Plan d acces',
                      ),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['', 'free', 'plus', 'pro']
                          .map((planId) {
                            return ChoiceChip(
                              label: Text(planId.isEmpty ? 'All' : planId),
                              selected:
                                  _accessPlanController.text.trim() == planId,
                              onSelected: (_) {
                                setState(() {
                                  _accessPlanController.text = planId;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _accessPlanController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: '¹± §®·©',
                          en: 'Plan ID',
                          fr: 'Identifiant du plan',
                        ),
                        hintText: adminDashText(
                          context,
                          ar: '§ª± §±º§ ³­',
                          en: 'Leave empty to clear',
                          fr: 'Laissez vide pour supprimer',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        adminDashText(
                          context,
                          ar: '¹',
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
                  ],
                ),
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
            adminDashText(context, ar: '­¸', en: 'Save', fr: 'Enregistrer'),
          ),
        ),
      ],
    );
  }
}

class _ContentInfoChip extends StatelessWidget {
  const _ContentInfoChip({required this.label, this.color});

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

class _ContentStateCard extends StatelessWidget {
  const _ContentStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
        ),
      ),
    );
  }
}

class _CategoryDialogResult {
  const _CategoryDialogResult({
    required this.translations,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.accessPlan,
  });

  final Map<String, AdminContentTranslation> translations;
  final String icon;
  final int order;
  final bool isActive;
  final String accessPlan;

  Map<String, dynamic> toCreateData() {
    final serializedTranslations = _serializeTranslations(translations);
    final titleAr = translations['ar']?.title.trim() ?? '';
    final titleEn = translations['en']?.title.trim() ?? '';
    return {
      if (titleAr.isNotEmpty) 'titleAr': titleAr,
      if (titleEn.isNotEmpty) 'titleEn': titleEn,
      'icon': icon,
      'order': order,
      'isActive': isActive,
      if (serializedTranslations.isNotEmpty)
        'translations': serializedTranslations,
      if (accessPlan.isNotEmpty) 'accessPlan': accessPlan,
    };
  }

  Map<String, dynamic> toUpdateData({required AdminContentCategory previous}) {
    final updates = <String, dynamic>{};
    final nextTranslations = _serializeTranslations(translations);
    final previousTranslations = _serializeTranslations(previous.translations);
    if (!_deepMapEquals(nextTranslations, previousTranslations)) {
      updates['translations'] = nextTranslations.isEmpty
          ? FieldValue.delete()
          : nextTranslations;
    }

    _assignLegacyFieldUpdate(
      updates: updates,
      fieldName: 'titleAr',
      nextValue: translations['ar']?.title.trim() ?? '',
      previousValue: previous.titleAr,
    );
    _assignLegacyFieldUpdate(
      updates: updates,
      fieldName: 'titleEn',
      nextValue: translations['en']?.title.trim() ?? '',
      previousValue: previous.titleEn,
    );
    if (icon != previous.icon) {
      updates['icon'] = icon;
    }
    if (order != previous.order) {
      updates['order'] = order;
    }
    if (isActive != previous.isActive) {
      updates['isActive'] = isActive;
    }
    if (accessPlan != (previous.accessPlan ?? '')) {
      updates['accessPlan'] = accessPlan.isEmpty
          ? FieldValue.delete()
          : accessPlan;
    }
    return updates;
  }
}

class _ItemDialogResult {
  const _ItemDialogResult({
    required this.translations,
    required this.repeatCount,
    required this.order,
    required this.isActive,
    required this.accessPlan,
  });

  final Map<String, AdminContentTranslation> translations;
  final int? repeatCount;
  final int order;
  final bool isActive;
  final String accessPlan;

  Map<String, dynamic> toCreateData({
    required AdminContentManagementConfig config,
  }) {
    final serializedTranslations = _serializeTranslations(translations);
    final titleAr = translations['ar']?.title.trim() ?? '';
    final titleEn = translations['en']?.title.trim() ?? '';
    final textAr = translations['ar']?.text.trim() ?? '';
    final textEn = translations['en']?.text.trim() ?? '';
    final source = _resolveLegacySource(translations);

    return {
      if (config.itemTitleEnabled && titleAr.isNotEmpty) 'titleAr': titleAr,
      if (config.itemTitleEnabled && titleEn.isNotEmpty) 'titleEn': titleEn,
      if (textAr.isNotEmpty) 'textAr': textAr,
      if (textEn.isNotEmpty) 'textEn': textEn,
      if (config.repeatCountEnabled && repeatCount != null)
        'repeatCount': repeatCount,
      if (serializedTranslations.isNotEmpty)
        'translations': serializedTranslations,
      if (source.isNotEmpty) 'source': source,
      'order': order,
      'isActive': isActive,
      if (accessPlan.isNotEmpty) 'accessPlan': accessPlan,
    };
  }

  Map<String, dynamic> toUpdateData({
    required AdminContentManagementConfig config,
    required AdminContentItem previous,
  }) {
    final updates = <String, dynamic>{};
    final nextTranslations = _serializeTranslations(translations);
    final previousTranslations = _serializeTranslations(previous.translations);
    if (!_deepMapEquals(nextTranslations, previousTranslations)) {
      updates['translations'] = nextTranslations.isEmpty
          ? FieldValue.delete()
          : nextTranslations;
    }

    if (config.itemTitleEnabled) {
      _assignLegacyFieldUpdate(
        updates: updates,
        fieldName: 'titleAr',
        nextValue: translations['ar']?.title.trim() ?? '',
        previousValue: previous.titleAr,
      );
      _assignLegacyFieldUpdate(
        updates: updates,
        fieldName: 'titleEn',
        nextValue: translations['en']?.title.trim() ?? '',
        previousValue: previous.titleEn,
      );
    }

    _assignLegacyFieldUpdate(
      updates: updates,
      fieldName: 'textAr',
      nextValue: translations['ar']?.text.trim() ?? '',
      previousValue: previous.textAr,
    );
    _assignLegacyFieldUpdate(
      updates: updates,
      fieldName: 'textEn',
      nextValue: translations['en']?.text.trim() ?? '',
      previousValue: previous.textEn,
    );
    if (config.repeatCountEnabled && repeatCount != previous.repeatCount) {
      updates['repeatCount'] = repeatCount;
    }
    final nextSource = _resolveLegacySource(translations);
    if (nextSource != previous.source) {
      updates['source'] = nextSource.isEmpty ? FieldValue.delete() : nextSource;
    }
    if (order != previous.order) {
      updates['order'] = order;
    }
    if (isActive != previous.isActive) {
      updates['isActive'] = isActive;
    }
    if (accessPlan != (previous.accessPlan ?? '')) {
      updates['accessPlan'] = accessPlan.isEmpty
          ? FieldValue.delete()
          : accessPlan;
    }

    return updates;
  }
}

Map<String, dynamic> _serializeTranslations(
  Map<String, AdminContentTranslation> translations,
) {
  final serialized = <String, dynamic>{};
  final sortedEntries = translations.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));

  for (final entry in sortedEntries) {
    final value = entry.value.toMap();
    if (value.isNotEmpty) {
      serialized[entry.key] = value;
    }
  }
  return serialized;
}

void _assignLegacyFieldUpdate({
  required Map<String, dynamic> updates,
  required String fieldName,
  required String nextValue,
  required String previousValue,
}) {
  if (nextValue == previousValue) {
    return;
  }
  updates[fieldName] = nextValue.isEmpty ? FieldValue.delete() : nextValue;
}

String _resolveLegacySource(Map<String, AdminContentTranslation> translations) {
  final arabic = translations['ar']?.source.trim() ?? '';
  if (arabic.isNotEmpty) {
    return arabic;
  }
  final english = translations['en']?.source.trim() ?? '';
  if (english.isNotEmpty) {
    return english;
  }
  for (final entry in translations.entries) {
    final source = entry.value.source.trim();
    if (source.isNotEmpty) {
      return source;
    }
  }
  return '';
}

bool _deepMapEquals(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key)) {
      return false;
    }
    final leftValue = entry.value;
    final rightValue = right[entry.key];
    if (leftValue is Map<String, dynamic> &&
        rightValue is Map<String, dynamic>) {
      if (!_deepMapEquals(leftValue, rightValue)) {
        return false;
      }
      continue;
    }
    if (leftValue != rightValue) {
      return false;
    }
  }
  return true;
}

String widgetArabicPlural(String label) {
  switch (label) {
    case '\u0627\u0644\u0642\u0633\u0645':
      return '\u0627\u0644\u0623\u0642\u0633\u0627\u0645';
    case '\u0627\u0644\u0630\u0643\u0631':
      return '\u0627\u0644\u0623\u0630\u0643\u0627\u0631';
    case '\u0627\u0644\u062f\u0639\u0627\u0621':
      return '\u0627\u0644\u0623\u062f\u0639\u064a\u0629';
    default:
      return label;
  }
}

String widgetFrenchPlural(String label) {
  switch (label.toLowerCase()) {
    case 'category':
      return 'categories';
    case 'dhikr':
      return 'adhkar';
    case 'dua':
      return 'invocations';
    default:
      return label;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
