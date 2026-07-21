import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/localization/content_locale_fallback.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_store_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_store_item.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminStoreManagementScreen extends StatefulWidget {
  const AdminStoreManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminStoreManagementScreen> createState() =>
      _AdminStoreManagementScreenState();
}

class _AdminStoreManagementScreenState
    extends State<AdminStoreManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminStoreRepository _storeRepository;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ValueNotifier<String> _searchQueryNotifier;

  String? _busyItemId;
  bool _isSeedingDefaults = false;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _storeRepository = FirestoreAdminStoreRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'adminStoreSearch');
    _searchQueryNotifier = ValueNotifier<String>('');
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text.trim();
    if (_searchQueryNotifier.value != nextQuery) {
      _searchQueryNotifier.value = nextQuery;
    }
  }

  List<AdminStoreItem> _filterItems(List<AdminStoreItem> items, String query) {
    final rewardItems = items
        .where((item) => _isRewardStoreType(item.type))
        .toList(growable: false);
    if (query.trim().isEmpty) {
      return rewardItems;
    }

    final normalized = query.trim().toLowerCase();
    return rewardItems
        .where((item) {
          return item.displayTitle.toLowerCase().contains(normalized) ||
              item.type.toLowerCase().contains(normalized) ||
              item.value.toLowerCase().contains(normalized) ||
              item.assetSummary.toLowerCase().contains(normalized) ||
              item.requiredPlan.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  bool _isRewardStoreType(String type) {
    return !{
      'calendar',
      'paid_feature',
      'pro_trial',
    }.contains(type.trim().toLowerCase());
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_StoreItemDialogResult>(
      context: context,
      builder: (context) => const _StoreItemDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      await _storeRepository.createItem(data: result.toCreateData());
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم إنشاء عنصر المتجر.',
          en: 'Store item created.',
          fr: 'Element de boutique cree.',
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

  Future<void> _openEditDialog(AdminStoreItem item) async {
    final result = await showDialog<_StoreItemDialogResult>(
      context: context,
      builder: (context) => _StoreItemDialog(initialItem: item),
    );
    if (result == null) {
      return;
    }

    final updates = result.toUpdateData(previous: item);
    if (updates.isEmpty) {
      return;
    }

    setState(() {
      _busyItemId = item.id;
    });

    try {
      await _storeRepository.updateItem(itemId: item.id, updates: updates);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث عنصر المتجر.',
          en: 'Store item updated.',
          fr: 'Element de boutique mis a jour.',
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
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _deleteItem(AdminStoreItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            adminDashText(
              context,
              ar: 'حذف عنصر المتجر',
              en: 'Delete store item',
              fr: 'Supprimer l element',
            ),
          ),
          content: Text(
            adminDashText(
              context,
              ar: 'هل تريد حذف "${item.displayTitle}" نهائيًا؟',
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
                  ar: 'حذف',
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
      await _storeRepository.deleteItem(itemId: item.id);
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم حذف عنصر المتجر.',
          en: 'Store item deleted.',
          fr: 'Element de boutique supprime.',
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
          _busyItemId = null;
        });
      }
    }
  }

  Future<void> _seedCommercialDefaults() async {
    if (_isSeedingDefaults) {
      return;
    }

    setState(() {
      _isSeedingDefaults = true;
    });
    try {
      final createdCount = await _storeRepository.seedCommercialDefaults();
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تجهيز $createdCount عنصر تجاري افتراضي.',
          en: '$createdCount commercial defaults prepared.',
          fr: '$createdCount elements commerciaux prepares.',
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
          _isSeedingDefaults = false;
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
            ar: 'المتجر',
            en: 'Store',
            fr: 'Boutique',
          ),
          currentRoute: AppRouter.adminDashboardStoreRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminStoreItem>>(
            stream: _storeRepository.watchItems(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _StoreStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل عناصر المتجر',
                    en: 'Unable to load store items',
                    fr: 'Impossible de charger les elements',
                  ),
                  message: mapAppErrorToArabic(snapshot.error!),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return ValueListenableBuilder<String>(
                valueListenable: _searchQueryNotifier,
                builder: (context, query, _) {
                  final items = _filterItems(snapshot.data!, query);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1100;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StoreToolbar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            searchQueryListenable: _searchQueryNotifier,
                            resultCount: items.length,
                            onCreate: _openCreateDialog,
                            onSeedDefaults: _seedCommercialDefaults,
                            isSeedingDefaults: _isSeedingDefaults,
                          ),
                          const SizedBox(height: 16),
                          const _CommercialStoreGuideCard(),
                          const SizedBox(height: 16),
                          Expanded(
                            child: items.isEmpty
                                ? _StoreStateCard(
                                    title: adminDashText(
                                      context,
                                      ar: 'لا توجد عناصر',
                                      en: 'No store items',
                                      fr: 'Aucun element',
                                    ),
                                    message: adminDashText(
                                      context,
                                      ar: 'أضف أول عنصر في المتجر.',
                                      en: 'Add your first store item.',
                                      fr: 'Ajoutez votre premier element.',
                                    ),
                                  )
                                : isWide
                                ? _StoreItemsTable(
                                    items: items,
                                    busyItemId: _busyItemId,
                                    onEdit: _openEditDialog,
                                    onDelete: _deleteItem,
                                  )
                                : _StoreItemsCards(
                                    items: items,
                                    busyItemId: _busyItemId,
                                    onEdit: _openEditDialog,
                                    onDelete: _deleteItem,
                                  ),
                          ),
                        ],
                      );
                    },
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

class _StoreToolbar extends StatelessWidget {
  const _StoreToolbar({
    required this.controller,
    required this.focusNode,
    required this.searchQueryListenable,
    required this.resultCount,
    required this.onCreate,
    required this.onSeedDefaults,
    required this.isSeedingDefaults,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<String> searchQueryListenable;
  final int resultCount;
  final VoidCallback onCreate;
  final VoidCallback onSeedDefaults;
  final bool isSeedingDefaults;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;
        final searchField = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? double.infinity : 440,
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: searchQueryListenable,
            builder: (context, query, _) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'ابحث في عناصر المتجر',
                    en: 'Search store items',
                    fr: 'Rechercher dans la boutique',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              );
            },
          ),
        );

        final countChip = Chip(
          label: Text(
            adminDashText(
              context,
              ar: 'النتائج: $resultCount',
              en: 'Results: $resultCount',
              fr: 'Resultats : $resultCount',
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: Text(
            adminDashText(
              context,
              ar: 'إضافة عنصر',
              en: 'Add item',
              fr: 'Ajouter',
            ),
          ),
        );

        final seedButton = OutlinedButton.icon(
          onPressed: isSeedingDefaults ? null : onSeedDefaults,
          icon: isSeedingDefaults
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_outlined),
          label: Text(
            adminDashText(
              context,
              ar: 'تهيئة المنتجات',
              en: 'Seed products',
              fr: 'Initialiser',
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [countChip, seedButton, addButton],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            countChip,
            const SizedBox(width: 12),
            seedButton,
            const SizedBox(width: 12),
            addButton,
          ],
        );
      },
    );
  }
}

class _CommercialStoreGuideCard extends StatelessWidget {
  const _CommercialStoreGuideCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDashboardSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adminDashText(
              context,
              ar: 'طريقة إضافة منتجات المتجر',
              en: 'How to add store products',
              fr: 'Comment ajouter des produits',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            adminDashText(
              context,
              ar: 'أضف المنتج كأصل حقيقي: للمصحف استخدم type=mushaf مع رابط مجلد الصفحات ونطاق 000.png إلى 114.png. للثيم استخدم type=theme مع اسم الثيم وألوان Hex. للودجت استخدم type=widget مع مفتاح الودجت وحدد هل هو مجاني أم مدفوع. المدفوع لن يظهر للمستخدم إلا بعد الشراء أو المنح من الداشبورد.',
              en: 'Add products as real assets: type=mushaf with a pages folder URL and a 000.png to 114.png range, type=theme with a theme name and Hex colors, and type=widget with a widget key plus free/paid visibility. Paid widgets stay hidden until purchased or granted.',
              fr: 'Ajoutez les produits comme de vrais actifs : type=mushaf avec URL et plage de pages, type=theme avec couleurs Hex, et type=widget avec cle et visibilite gratuite/payante.',
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreItemsTable extends StatelessWidget {
  const _StoreItemsTable({
    required this.items,
    required this.busyItemId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminStoreItem> items;
  final String? busyItemId;
  final Future<void> Function(AdminStoreItem item) onEdit;
  final Future<void> Function(AdminStoreItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(
              label: Text(
                adminDashText(context, ar: 'العنصر', en: 'Item', fr: 'Element'),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(context, ar: 'القسم', en: 'Type', fr: 'Type'),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(context, ar: 'القيمة', en: 'Value', fr: 'Valeur'),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(
                  context,
                  ar: 'ملفات المنتج',
                  en: 'Product files',
                  fr: 'Fichiers',
                ),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(context, ar: 'السعر', en: 'Price', fr: 'Prix'),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(context, ar: 'الخطة', en: 'Plan', fr: 'Plan'),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(
                  context,
                  ar: 'الحالة',
                  en: 'Status',
                  fr: 'Statut',
                ),
              ),
            ),
            DataColumn(
              label: Text(
                adminDashText(
                  context,
                  ar: 'الإجراءات',
                  en: 'Actions',
                  fr: 'Actions',
                ),
              ),
            ),
          ],
          rows: items
              .map((item) {
                final isBusy = busyItemId == item.id;

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Row(
                          children: [
                            _StorePreviewThumb(url: item.previewUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (item.description.trim().isNotEmpty)
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(_storeTypeLabel(context, item.type))),
                    DataCell(Text(item.value)),
                    DataCell(
                      SizedBox(
                        width: 260,
                        child: Text(
                          item.assetSummary.isEmpty ? '-' : item.assetSummary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        adminDashText(
                          context,
                          ar: '${item.pricePoints} نقطة',
                          en: '${item.pricePoints} pts',
                          fr: '${item.pricePoints} pts',
                        ),
                      ),
                    ),
                    DataCell(Text(_planLabel(context, item.requiredPlan))),
                    DataCell(
                      _StoreChip(
                        label: item.isActive
                            ? adminDashText(
                                context,
                                ar: 'مفعّل',
                                en: 'Active',
                                fr: 'Active',
                              )
                            : adminDashText(
                                context,
                                ar: 'متوقف',
                                en: 'Inactive',
                                fr: 'Inactive',
                              ),
                        color: item.isActive
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                      ),
                    ),
                    DataCell(
                      isBusy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => onEdit(item),
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
                                  onPressed: () => onDelete(item),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    adminDashText(
                                      context,
                                      ar: 'حذف',
                                      en: 'Delete',
                                      fr: 'Supprimer',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _StoreItemsCards extends StatelessWidget {
  const _StoreItemsCards({
    required this.items,
    required this.busyItemId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminStoreItem> items;
  final String? busyItemId;
  final Future<void> Function(AdminStoreItem item) onEdit;
  final Future<void> Function(AdminStoreItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 880
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return ListView(
          children: [
            AdminDashboardGridWrap(
              children: items
                  .map((item) {
                    final isBusy = busyItemId == item.id;
                    return SizedBox(
                      width: cardWidth.clamp(280.0, 420.0).toDouble(),
                      child: AdminDashboardSurfaceCard(
                        minHeight: 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.displayTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (isBusy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _StorePreviewHero(url: item.previewUrl),
                            if (item.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(item.description),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StoreChip(
                                  label: _storeTypeLabel(context, item.type),
                                ),
                                _StoreChip(
                                  label: _planLabel(context, item.requiredPlan),
                                ),
                                _StoreChip(
                                  label: adminDashText(
                                    context,
                                    ar: '${item.pricePoints} نقطة',
                                    en: '${item.pricePoints} pts',
                                    fr: '${item.pricePoints} pts',
                                  ),
                                ),
                                _StoreChip(
                                  label: item.isActive
                                      ? adminDashText(
                                          context,
                                          ar: 'مفعّل',
                                          en: 'Active',
                                          fr: 'Active',
                                        )
                                      : adminDashText(
                                          context,
                                          ar: 'متوقف',
                                          en: 'Inactive',
                                          fr: 'Inactive',
                                        ),
                                  color: item.isActive
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              adminDashText(
                                context,
                                ar: 'القيمة: ${item.value}',
                                en: 'Value: ${item.value}',
                                fr: 'Valeur : ${item.value}',
                              ),
                            ),
                            if (item.assetSummary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                adminDashText(
                                  context,
                                  ar: 'ملفات المنتج: ${item.assetSummary}',
                                  en: 'Product files: ${item.assetSummary}',
                                  fr: 'Fichiers : ${item.assetSummary}',
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: isBusy ? null : () => onEdit(item),
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
                                  onPressed: isBusy
                                      ? null
                                      : () => onDelete(item),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    adminDashText(
                                      context,
                                      ar: 'حذف',
                                      en: 'Delete',
                                      fr: 'Supprimer',
                                    ),
                                  ),
                                ),
                              ],
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
  }
}

class _StoreItemDialog extends StatefulWidget {
  const _StoreItemDialog({this.initialItem});

  final AdminStoreItem? initialItem;

  @override
  State<_StoreItemDialog> createState() => _StoreItemDialogState();
}

class _StoreItemDialogState extends State<_StoreItemDialog> {
  static const _defaultTypeOptions = <String>[
    'gift',
    'adhan_sound',
    'theme',
    'quran_font',
    'widget_unlock',
    'mushaf_pack',
    'other_reward',
  ];
  static const _planOptions = <String>['all', 'free', 'plus', 'pro'];

  late final TextEditingController _typeController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _previewUrlController;
  late final TextEditingController _valueController;
  late final TextEditingController _assetKindController;
  late final TextEditingController _assetUrlController;
  late final TextEditingController _unlockKeyController;
  late final TextEditingController _fileBaseUrlController;
  late final TextEditingController _fileNamePatternController;
  late final TextEditingController _fileStartIndexController;
  late final TextEditingController _fileEndIndexController;
  late final TextEditingController _themeNameController;
  late final TextEditingController _themePrimaryHexController;
  late final TextEditingController _themeSecondaryHexController;
  late final TextEditingController _themeBackgroundHexController;
  late final TextEditingController _themeSurfaceHexController;
  late final TextEditingController _themeTextHexController;
  late final TextEditingController _widgetNameController;
  late final TextEditingController _widgetKeyController;
  late final TextEditingController _pricePointsController;
  late final TextEditingController _requiredPlanController;
  late bool _isActive;
  late bool _isFreeWidget;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _typeController = TextEditingController(text: item?.type ?? 'theme');
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _previewUrlController = TextEditingController(text: item?.previewUrl ?? '');
    _valueController = TextEditingController(text: item?.value ?? '');
    _assetKindController = TextEditingController(
      text: item?.assetKind ?? _defaultAssetKind(item?.type ?? 'theme'),
    );
    _assetUrlController = TextEditingController(text: item?.assetUrl ?? '');
    _unlockKeyController = TextEditingController(text: item?.unlockKey ?? '');
    final colors = item?.metadataMap('colors') ?? const <String, dynamic>{};
    _fileBaseUrlController = TextEditingController(
      text: item?.metadataString('fileBaseUrl') ?? '',
    );
    _fileNamePatternController = TextEditingController(
      text: item?.metadataString('fileNamePattern') ?? '000.png',
    );
    _fileStartIndexController = TextEditingController(
      text: '${item?.metadataInt('fileStartIndex') ?? 0}',
    );
    _fileEndIndexController = TextEditingController(
      text: '${item?.metadataInt('fileEndIndex') ?? 114}',
    );
    _themeNameController = TextEditingController(
      text: item?.metadataString('themeName') ?? item?.title ?? '',
    );
    _themePrimaryHexController = TextEditingController(
      text: '${colors['primary'] ?? '#1F9D62'}',
    );
    _themeSecondaryHexController = TextEditingController(
      text: '${colors['secondary'] ?? '#F5A524'}',
    );
    _themeBackgroundHexController = TextEditingController(
      text: '${colors['background'] ?? '#F7FBF8'}',
    );
    _themeSurfaceHexController = TextEditingController(
      text: '${colors['surface'] ?? '#FFFFFF'}',
    );
    _themeTextHexController = TextEditingController(
      text: '${colors['text'] ?? '#10231A'}',
    );
    _widgetNameController = TextEditingController(
      text: item?.metadataString('widgetName') ?? item?.title ?? '',
    );
    _widgetKeyController = TextEditingController(
      text: item?.metadataString('widgetKey') ?? item?.value ?? '',
    );
    _pricePointsController = TextEditingController(
      text: '${item?.pricePoints ?? 0}',
    );
    _requiredPlanController = TextEditingController(
      text: item?.requiredPlan ?? 'free',
    );
    _isActive = item?.isActive ?? true;
    _isFreeWidget =
        item?.metadataBool('isFreeWidget') ?? (item?.pricePoints == 0);
    _previewUrlController.addListener(_handlePreviewChanged);
  }

  @override
  void dispose() {
    _previewUrlController.removeListener(_handlePreviewChanged);
    _typeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _previewUrlController.dispose();
    _valueController.dispose();
    _assetKindController.dispose();
    _assetUrlController.dispose();
    _unlockKeyController.dispose();
    _fileBaseUrlController.dispose();
    _fileNamePatternController.dispose();
    _fileStartIndexController.dispose();
    _fileEndIndexController.dispose();
    _themeNameController.dispose();
    _themePrimaryHexController.dispose();
    _themeSecondaryHexController.dispose();
    _themeBackgroundHexController.dispose();
    _themeSurfaceHexController.dispose();
    _themeTextHexController.dispose();
    _widgetNameController.dispose();
    _widgetKeyController.dispose();
    _pricePointsController.dispose();
    _requiredPlanController.dispose();
    super.dispose();
  }

  void _handlePreviewChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<String> get _typeOptions {
    final selected = _typeController.text.trim();
    final options = <String>{..._defaultTypeOptions};
    if (selected.isNotEmpty) {
      options.add(selected);
    }
    return options.toList(growable: false);
  }

  static String _defaultAssetKind(String type) {
    switch (type.trim()) {
      case 'quran_font':
        return 'metadata_only';
      case 'mushaf':
      case 'mushaf_pack':
        return 'metadata_only';
      case 'adhan':
      case 'adhan_sound':
        return 'bundled_raw';
      case 'widget':
      case 'widget_unlock':
        return 'widget_unlock';
      case 'theme':
        return 'theme_hex_palette';
      default:
        return '';
    }
  }

  void _applyTypeDefaults(String type) {
    final defaultKind = _defaultAssetKind(type);
    if (defaultKind.isNotEmpty) {
      _assetKindController.text = defaultKind;
    }
    if ((type == 'mushaf' || type == 'mushaf_pack') &&
        _fileBaseUrlController.text.trim().isEmpty) {
      _fileNamePatternController.text = 'page_%03d.png';
      _fileStartIndexController.text = '0';
      _fileEndIndexController.text = '114';
    }
    if ((type == 'widget' || type == 'widget_unlock') &&
        _widgetKeyController.text.trim().isEmpty) {
      _widgetKeyController.text = 'next_prayer';
    }
    if (type == 'theme' && _themeNameController.text.trim().isEmpty) {
      _themeNameController.text = _titleController.text.trim();
    }
  }

  void _showValidationMessage(String message) {
    showAdminDashboardSnackBar(context, message: message, isError: true);
  }

  Map<String, dynamic> _buildMetadata(String type) {
    final normalizedType = type.trim().toLowerCase();
    final metadata = <String, dynamic>{};

    final fileBaseUrl = _fileBaseUrlController.text.trim();
    final fileNamePattern = _fileNamePatternController.text.trim();
    final fileStartIndex = int.tryParse(_fileStartIndexController.text.trim());
    final fileEndIndex = int.tryParse(_fileEndIndexController.text.trim());
    if (normalizedType == 'mushaf' ||
        normalizedType == 'mushaf_pack' ||
        fileBaseUrl.isNotEmpty) {
      if (fileBaseUrl.isNotEmpty) {
        metadata['fileBaseUrl'] = fileBaseUrl;
      }
      if (fileNamePattern.isNotEmpty) {
        metadata['fileNamePattern'] = fileNamePattern;
      }
      if (fileStartIndex != null) {
        metadata['fileStartIndex'] = fileStartIndex;
      }
      if (fileEndIndex != null) {
        metadata['fileEndIndex'] = fileEndIndex;
      }
    }

    if (normalizedType == 'theme') {
      final themeId = _slugFromTitle(
        _themeNameController.text.trim().isEmpty
            ? _titleController.text.trim()
            : _themeNameController.text.trim(),
        fallback: 'theme',
      );
      metadata['themeName'] = _themeNameController.text.trim();
      metadata['colors'] = {
        'primary': _normalizedHex(_themePrimaryHexController.text),
        'secondary': _normalizedHex(_themeSecondaryHexController.text),
        'background': _normalizedHex(_themeBackgroundHexController.text),
        'surface': _normalizedHex(_themeSurfaceHexController.text),
        'text': _normalizedHex(_themeTextHexController.text),
      };
      metadata['theme'] = {
        'id': themeId,
        'primaryColor': _normalizedHex(_themePrimaryHexController.text),
        'secondaryColor': _normalizedHex(_themeSecondaryHexController.text),
        'backgroundColor': _normalizedHex(_themeBackgroundHexController.text),
        'surfaceColor': _normalizedHex(_themeSurfaceHexController.text),
        'textColor': _normalizedHex(_themeTextHexController.text),
        'isDark': false,
      };
    }

    if (normalizedType == 'widget' || normalizedType == 'widget_unlock') {
      final widgetType = _widgetKeyController.text.trim().isEmpty
          ? 'next_prayer'
          : _widgetKeyController.text.trim();
      metadata['widgetName'] = _widgetNameController.text.trim();
      metadata['widgetType'] = widgetType;
      metadata['widgetKey'] = 'widget.$widgetType';
      metadata['isFreeWidget'] = _isFreeWidget;
    }

    return _stripEmptyMetadata(metadata);
  }

  String _normalizedHex(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return '';
    }
    return clean.startsWith('#') ? clean : '#$clean';
  }

  Map<String, dynamic> _stripEmptyMetadata(Map<String, dynamic> value) {
    final result = <String, dynamic>{};
    value.forEach((key, item) {
      if (item is String) {
        if (item.trim().isNotEmpty) {
          result[key] = item.trim();
        }
      } else if (item is Map) {
        final nested = _stripEmptyMetadata(
          item.map((key, value) => MapEntry('$key', value)),
        );
        if (nested.isNotEmpty) {
          result[key] = nested;
        }
      } else if (item != null) {
        result[key] = item;
      }
    });
    return result;
  }

  void _submit() {
    final type = _typeController.text.trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final previewUrl = _previewUrlController.text.trim();
    final value = _generatedValueFor(type: type, title: title);
    final assetKind = _assetKindController.text.trim().isEmpty
        ? _defaultAssetKind(type)
        : _assetKindController.text.trim();
    final assetUrl = _assetUrlController.text.trim();
    final unlockKey = _generatedUnlockKeyFor(type: type, value: value);
    final parsedPricePoints = int.tryParse(_pricePointsController.text.trim());
    final normalizedType = type.toLowerCase();
    final isWidgetType =
        normalizedType == 'widget' || normalizedType == 'widget_unlock';
    final pricePoints = isWidgetType && _isFreeWidget
        ? 0
        : parsedPricePoints;
    final requiredPlan = _requiredPlanController.text.trim();
    final metadata = _buildMetadata(type);

    if (type.isEmpty) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'القسم مطلوب.',
          en: 'Type is required.',
          fr: 'Le type est requis.',
        ),
      );
      return;
    }
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
    if (pricePoints == null || pricePoints < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل سعر نقاط صحيحًا.',
          en: 'Enter a valid points price.',
          fr: 'Entrez un prix en points valide.',
        ),
      );
      return;
    }
    if (requiredPlan.isEmpty) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'الخطة المطلوبة مطلوبة.',
          en: 'Required plan is required.',
          fr: 'Le plan requis est obligatoire.',
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _StoreItemDialogResult(
        type: type,
        title: title,
        description: description,
        previewUrl: previewUrl,
        value: value,
        assetKind: assetKind,
        assetUrl: assetUrl,
        unlockKey: unlockKey,
        metadata: metadata,
        pricePoints: pricePoints,
        requiredPlan: requiredPlan,
        isActive: _isActive,
      ),
    );
  }

  String _slugFromTitle(String title, {required String fallback}) {
    final source = title.trim().isEmpty ? fallback : title;
    final slug = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty
        ? '${fallback}_${DateTime.now().millisecondsSinceEpoch}'
        : slug;
  }

  String _generatedValueFor({required String type, required String title}) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType == 'widget' || normalizedType == 'widget_unlock') {
      final widgetType = _widgetKeyController.text.trim();
      return widgetType.isEmpty ? 'next_prayer' : widgetType;
    }
    return _valueController.text.trim().isEmpty
        ? _slugFromTitle(title, fallback: type)
        : _valueController.text.trim();
  }

  String _generatedUnlockKeyFor({required String type, required String value}) {
    switch (type.trim().toLowerCase()) {
      case 'widget':
      case 'widget_unlock':
        return 'widget.$value';
      case 'theme':
        return 'theme.$value';
      case 'adhan':
      case 'adhan_sound':
        return 'adhan.$value';
      case 'mushaf':
      case 'mushaf_pack':
        return 'mushaf.$value';
      case 'quran_font':
        return 'quran_font.$value';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _previewUrlController.text.trim();
    final selectedType = _typeController.text.trim().toLowerCase();
    final isMushafType =
        selectedType == 'mushaf' || selectedType == 'mushaf_pack';
    final isWidgetType =
        selectedType == 'widget' || selectedType == 'widget_unlock';

    return AlertDialog(
      title: Text(
        adminDashText(
          context,
          ar: _isEditing ? 'تعديل عنصر المتجر' : 'إضافة عنصر للمتجر',
          en: _isEditing ? 'Edit store item' : 'Create store item',
          fr: _isEditing ? 'Modifier l element' : 'Creer un element',
        ),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(ContentLocaleFallback.dashboardLanguageNote),
              const SizedBox(height: 12),
              _StoreDialogSection(
                title: adminDashText(
                  context,
                  ar: 'بيانات المنتج',
                  en: 'Product details',
                  fr: 'Details du produit',
                ),
                initiallyExpanded: true,
                children: [
                  Text(
                    adminDashText(context, ar: 'القسم', en: 'Type', fr: 'Type'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _typeOptions
                        .map((type) {
                          final isSelected =
                              _typeController.text.trim() == type;
                          return ChoiceChip(
                            label: Text(_storeTypeLabel(context, type)),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _typeController.text = type;
                                _applyTypeDefaults(type);
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
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
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'الوصف',
                        en: 'Description',
                        fr: 'Description',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _previewUrlController,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'رابط الصورة',
                        en: 'Preview URL',
                        fr: 'URL d apercu',
                      ),
                    ),
                  ),
                  if (previewUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  adminDashText(
                                    context,
                                    ar: 'تعذر تحميل الصورة',
                                    en: 'Unable to load image',
                                    fr: 'Impossible de charger l image',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _StoreDialogSection(
                title: adminDashText(
                  context,
                  ar: 'الملفات ومفاتيح الفتح',
                  en: 'Optional advanced settings',
                  fr: 'Fichiers et cles',
                ),
                initiallyExpanded: false,
                children: [
                  TextField(
                    controller: _valueController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Generated value key',
                      helperText:
                          'Generated automatically from the title; no manual code is required.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: 'Internal type ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _assetKindController,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'نوع ملف المنتج',
                        en: 'Asset kind',
                        fr: 'Type de fichier',
                      ),
                      helperText: adminDashText(
                        context,
                        ar: 'مثال: font_file أو adhan_audio أو widget_unlock_key.',
                        en: 'Example: font_file, adhan_audio, or widget_unlock_key.',
                        fr: 'Exemple : font_file, adhan_audio ou widget_unlock_key.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _assetUrlController,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'رابط ملف المنتج',
                        en: 'Asset file URL',
                        fr: 'URL du fichier',
                      ),
                      helperText: adminDashText(
                        context,
                        ar: 'للخط ارفع ملف الخط، وللأذان ارفع ملف الصوت أو رابط التحميل.',
                        en: 'Use this for font files, adhan audio, or downloadable packs.',
                        fr: 'Utilisez ceci pour les fichiers de police, audio ou packs.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _unlockKeyController,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'مفتاح الفتح أو التشفير',
                        en: 'Auto-generated unlock key',
                        fr: 'Cle de deverrouillage',
                      ),
                      helperText: adminDashText(
                        context,
                        ar: 'للويدجت ضع مفتاح الفتح، وللأذان يمكن وضع كود المؤذن.',
                        en: 'Generated automatically. Do not enter encryption keys or widget secret keys.',
                        fr: 'Pour les widgets utilisez une cle; pour l adhan un code son.',
                      ),
                    ),
                  ),
                  if (isMushafType) ...[
                    const SizedBox(height: 18),
                    Text(
                      adminDashText(
                        context,
                        ar: 'ملفات المصحف',
                        en: 'Mushaf page files',
                        fr: 'Fichiers du mushaf',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fileBaseUrlController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'رابط مجلد الصفحات',
                          en: 'Pages folder URL',
                          fr: 'URL du dossier',
                        ),
                        helperText: 'https://domain.com/quran/othmani/',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fileNamePatternController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'نمط اسم الملف',
                          en: 'File name pattern',
                          fr: 'Modele de fichier',
                        ),
                        helperText: '000.png أو {index}.png',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fileStartIndexController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: adminDashText(
                                context,
                                ar: 'من صفحة',
                                en: 'From page',
                                fr: 'De',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _fileEndIndexController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: adminDashText(
                                context,
                                ar: 'إلى صفحة',
                                en: 'To page',
                                fr: 'A',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (selectedType == 'theme') ...[
                    const SizedBox(height: 18),
                    Text(
                      adminDashText(
                        context,
                        ar: 'ألوان الثيم',
                        en: 'Theme colors',
                        fr: 'Couleurs du theme',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _themeNameController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'اسم الثيم',
                          en: 'Theme name',
                          fr: 'Nom du theme',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StoreHexField(
                          controller: _themePrimaryHexController,
                          label: 'Primary',
                        ),
                        _StoreHexField(
                          controller: _themeSecondaryHexController,
                          label: 'Secondary',
                        ),
                        _StoreHexField(
                          controller: _themeBackgroundHexController,
                          label: 'Background',
                        ),
                        _StoreHexField(
                          controller: _themeSurfaceHexController,
                          label: 'Surface',
                        ),
                        _StoreHexField(
                          controller: _themeTextHexController,
                          label: 'Text',
                        ),
                      ],
                    ),
                  ],
                  if (isWidgetType) ...[
                    const SizedBox(height: 18),
                    Text(
                      adminDashText(
                        context,
                        ar: 'فتح الودجت',
                        en: 'Widget unlock',
                        fr: 'Deverrouillage widget',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _widgetNameController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'اسم الودجت الظاهر',
                          en: 'Widget display name',
                          fr: 'Nom du widget',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _widgetKeyController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'مفتاح الودجت',
                          en: 'Widget type',
                          fr: 'Cle widget',
                        ),
                        helperText:
                            'next_prayer, today_prayers, points, quick_controls, quran_ayah, hadith, or adhkar',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isFreeWidget,
                      title: Text(
                        adminDashText(
                          context,
                          ar: 'ودجت مجاني يظهر لكل المستخدمين',
                          en: 'Free widget visible to everyone',
                          fr: 'Widget gratuit visible par tous',
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isFreeWidget = value;
                          if (value) {
                            _pricePointsController.text = '0';
                          }
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _StoreDialogSection(
                title: adminDashText(
                  context,
                  ar: 'السعر والنشر',
                  en: 'Pricing and publishing',
                  fr: 'Prix et publication',
                ),
                initiallyExpanded: true,
                children: [
                  TextField(
                    controller: _pricePointsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'سعر النقاط',
                        en: 'Price points',
                        fr: 'Prix en points',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    adminDashText(
                      context,
                      ar: 'الخطة المطلوبة',
                      en: 'Required plan',
                      fr: 'Plan requis',
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _planOptions
                        .map((plan) {
                          final isSelected =
                              _requiredPlanController.text.trim() == plan;
                          return ChoiceChip(
                            label: Text(_planLabel(context, plan)),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _requiredPlanController.text = plan;
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _requiredPlanController,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'معرف الخطة المطلوبة',
                        en: 'Required plan ID',
                        fr: 'Identifiant du plan',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      adminDashText(
                        context,
                        ar: 'العنصر نشط',
                        en: 'Item is active',
                        fr: 'Element actif',
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

class _StoreItemDialogResult {
  const _StoreItemDialogResult({
    required this.type,
    required this.title,
    required this.description,
    required this.previewUrl,
    required this.value,
    required this.assetKind,
    required this.assetUrl,
    required this.unlockKey,
    required this.metadata,
    required this.pricePoints,
    required this.requiredPlan,
    required this.isActive,
  });

  final String type;
  final String title;
  final String description;
  final String previewUrl;
  final String value;
  final String assetKind;
  final String assetUrl;
  final String unlockKey;
  final Map<String, dynamic> metadata;
  final int pricePoints;
  final String requiredPlan;
  final bool isActive;

  Map<String, dynamic> toCreateData() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'previewUrl': previewUrl,
      'value': value,
      'assetKind': assetKind,
      'assetUrl': assetUrl,
      'unlockKey': unlockKey,
      'metadata': metadata,
      'pricePoints': pricePoints,
      'requiredPlan': requiredPlan,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> toUpdateData({required AdminStoreItem previous}) {
    final updates = <String, dynamic>{};
    if (type != previous.type) {
      updates['type'] = type;
    }
    if (title != previous.title) {
      updates['title'] = title;
    }
    if (description != previous.description) {
      updates['description'] = description;
    }
    if (previewUrl != previous.previewUrl) {
      updates['previewUrl'] = previewUrl;
    }
    if (value != previous.value) {
      updates['value'] = value;
    }
    if (assetKind != previous.assetKind) {
      updates['assetKind'] = assetKind;
    }
    if (assetUrl != previous.assetUrl) {
      updates['assetUrl'] = assetUrl;
    }
    if (unlockKey != previous.unlockKey) {
      updates['unlockKey'] = unlockKey;
    }
    if (metadata.toString() != previous.metadata.toString()) {
      updates['metadata'] = metadata;
    }
    if (pricePoints != previous.pricePoints) {
      updates['pricePoints'] = pricePoints;
    }
    if (requiredPlan != previous.requiredPlan) {
      updates['requiredPlan'] = requiredPlan;
    }
    if (isActive != previous.isActive) {
      updates['isActive'] = isActive;
    }
    return updates;
  }
}

class _StorePreviewThumb extends StatelessWidget {
  const _StorePreviewThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.trim().isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                },
              ),
      ),
    );
  }
}

class _StorePreviewHero extends StatelessWidget {
  const _StorePreviewHero({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.trim().isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 32),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 32),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({required this.label, this.color});

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

class _StoreDialogSection extends StatelessWidget {
  const _StoreDialogSection({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _StoreHexField extends StatelessWidget {
  const _StoreHexField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(controller.text);
    return SizedBox(
      width: 184,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const SizedBox(width: 18, height: 18),
            ),
          ),
          hintText: '#1F9D62',
        ),
      ),
    );
  }
}

class _StoreStateCard extends StatelessWidget {
  const _StoreStateCard({required this.title, required this.message});

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

String _storeTypeLabel(BuildContext context, String value) {
  switch (value.trim().toLowerCase()) {
    case 'theme':
      return adminDashText(context, ar: 'ثيم', en: 'Theme', fr: 'Theme');
    case 'quran_font':
      return adminDashText(
        context,
        ar: 'خط قرآن',
        en: 'Quran font',
        fr: 'Police Coran',
      );
    case 'mushaf':
      return adminDashText(
        context,
        ar: 'مصحف صور',
        en: 'Mushaf pack',
        fr: 'Pack mushaf',
      );
    case 'widget':
      return adminDashText(context, ar: 'ويدجت', en: 'Widget', fr: 'Widget');
    case 'adhan':
      return adminDashText(context, ar: 'أذان', en: 'Adhan', fr: 'Adhan');
    case 'calendar':
      return adminDashText(
        context,
        ar: 'تقويم',
        en: 'Calendar',
        fr: 'Calendrier',
      );
    case 'gift_card':
      return adminDashText(
        context,
        ar: 'بطاقة هدية',
        en: 'Gift card',
        fr: 'Carte cadeau',
      );
    case 'paid_feature':
      return adminDashText(
        context,
        ar: 'ميزة مدفوعة',
        en: 'Paid feature',
        fr: 'Fonction payante',
      );
    case 'pro_trial':
      return adminDashText(
        context,
        ar: 'تجربة Pro',
        en: 'Pro trial',
        fr: 'Essai Pro',
      );
    case 'background':
      return adminDashText(
        context,
        ar: 'خلفية',
        en: 'Background',
        fr: 'Arriere-plan',
      );
    case 'font':
      return adminDashText(context, ar: 'خط', en: 'Font', fr: 'Police');
    case 'sticker':
      return adminDashText(context, ar: 'ملصق', en: 'Sticker', fr: 'Sticker');
    case 'badge':
      return adminDashText(context, ar: 'شارة', en: 'Badge', fr: 'Badge');
    default:
      return adminDashText(context, ar: 'ثيم', en: 'Theme', fr: 'Theme');
  }
}

String _planLabel(BuildContext context, String value) {
  switch (value.trim().toLowerCase()) {
    case 'all':
      return adminDashText(context, ar: 'الكل', en: 'All', fr: 'Tous');
    case 'plus':
      return 'Plus';
    case 'pro':
      return 'Pro';
    default:
      return adminDashText(context, ar: 'مجاني', en: 'Free', fr: 'Gratuit');
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
