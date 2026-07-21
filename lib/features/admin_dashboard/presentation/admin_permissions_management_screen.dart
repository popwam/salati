import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_users_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_user_summary.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminPermissionsManagementScreen extends StatefulWidget {
  const AdminPermissionsManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminPermissionsManagementScreen> createState() =>
      _AdminPermissionsManagementScreenState();
}

class _AdminPermissionsManagementScreenState
    extends State<AdminPermissionsManagementScreen> {
  static const int _permissionsUsersLimit = 40;

  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminUsersRepository _usersRepository;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ValueNotifier<String> _searchQueryNotifier;

  String? _selectedUserId;
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _usersRepository = FirestoreAdminUsersRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'adminPermissionsSearch');
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

  List<AdminUserSummary> _sortAndFilterUsers(
    List<AdminUserSummary> users,
    String query,
  ) {
    final filtered = users
        .where((user) => user.matchesQuery(query))
        .toList(growable: false);

    final sorted = [...filtered]
      ..sort((left, right) {
        if (left.role != right.role) {
          return right.role.index.compareTo(left.role.index);
        }
        return left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        );
      });

    return sorted;
  }

  Future<void> _savePermissions({
    required AdminUserSummary user,
    required Set<String> permissions,
  }) async {
    setState(() {
      _busyUserId = user.uid;
    });

    try {
      await _usersRepository.updateUserPermissions(
        uid: user.uid,
        permissions: permissions,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث الصلاحيات.',
          en: 'Permissions updated.',
          fr: 'Autorisations mises a jour.',
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
          _busyUserId = null;
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
            ar: 'الصلاحيات',
            en: 'Permissions',
            fr: 'Autorisations',
          ),
          currentRoute: AppRouter.adminDashboardPermissionsRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminUserSummary>>(
            stream: _usersRepository.watchUsers(limit: _permissionsUsersLimit),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _PermissionStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل المستخدمين',
                    en: 'Unable to load users',
                    fr: 'Impossible de charger les utilisateurs',
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
                  final users = _sortAndFilterUsers(snapshot.data!, query);

                  final selectedUser =
                      users.where((user) {
                        return user.uid == _selectedUserId;
                      }).firstOrNull ??
                      users.firstOrNull;
                  final selectedUserId = selectedUser?.uid;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1120;
                      final selectionPaneHeight = constraints.maxWidth < 760
                          ? 220.0
                          : 280.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PermissionsToolbar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            searchQueryListenable: _searchQueryNotifier,
                            resultCount: users.length,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: users.isEmpty
                                ? _PermissionStateCard(
                                    title: adminDashText(
                                      context,
                                      ar: 'لا يوجد مستخدمون',
                                      en: 'No users found',
                                      fr: 'Aucun utilisateur trouve',
                                    ),
                                    message: adminDashText(
                                      context,
                                      ar: 'جرّب تعديل البحث.',
                                      en: 'Try refining the search.',
                                      fr: 'Essayez d affiner la recherche.',
                                    ),
                                  )
                                : isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 328,
                                        child: _UserSelectionPane(
                                          users: users,
                                          selectedUserId: selectedUserId,
                                          onSelected: (user) {
                                            setState(() {
                                              _selectedUserId = user.uid;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _PermissionEditorPane(
                                          access: access,
                                          user: selectedUser,
                                          busyUserId: _busyUserId,
                                          onSave: _savePermissions,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: selectionPaneHeight,
                                        child: _UserSelectionPane(
                                          users: users,
                                          selectedUserId: selectedUserId,
                                          onSelected: (user) {
                                            setState(() {
                                              _selectedUserId = user.uid;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: _PermissionEditorPane(
                                          access: access,
                                          user: selectedUser,
                                          busyUserId: _busyUserId,
                                          onSave: _savePermissions,
                                        ),
                                      ),
                                    ],
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

class _PermissionsToolbar extends StatelessWidget {
  const _PermissionsToolbar({
    required this.controller,
    required this.focusNode,
    required this.searchQueryListenable,
    required this.resultCount,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<String> searchQueryListenable;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        final searchField = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? double.infinity : 420,
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
                    ar: 'ابحث عن مستخدم',
                    en: 'Search users',
                    fr: 'Rechercher un utilisateur',
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

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: countChip,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            countChip,
          ],
        );
      },
    );
  }
}

class _UserSelectionPane extends StatelessWidget {
  const _UserSelectionPane({
    required this.users,
    required this.selectedUserId,
    required this.onSelected,
  });

  final List<AdminUserSummary> users;
  final String? selectedUserId;
  final ValueChanged<AdminUserSummary> onSelected;

  int _effectivePermissionCount(AdminUserSummary user) {
    final hasEntry =
        user.role == AdminDashboardRole.superAdmin ||
        user.role == AdminDashboardRole.admin ||
        user.permissions.contains(AdminDashboardPermission.dashboardView);
    return hasEntry ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = users[index];
          final isSelected = user.uid == selectedUserId;
          final avatarText = user.displayName.trim().isEmpty
              ? '?'
              : user.displayName.characters.first.toUpperCase();

          return ListTile(
            selected: isSelected,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: CircleAvatar(child: Text(avatarText)),
            title: Text(user.displayName),
            subtitle: Text(
              '${adminDashboardRoleLabel(user.role)} - ${user.email ?? user.phone ?? user.uid}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Chip(
              label: Text(
                adminDashText(
                  context,
                  ar: '${_effectivePermissionCount(user)} صلاحية',
                  en: '${_effectivePermissionCount(user)} perms',
                  fr: '${_effectivePermissionCount(user)} droits',
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
            onTap: () => onSelected(user),
          );
        },
      ),
    );
  }
}

class _PermissionEditorPane extends StatefulWidget {
  const _PermissionEditorPane({
    required this.access,
    required this.user,
    required this.busyUserId,
    required this.onSave,
  });

  final AdminDashboardAccess access;
  final AdminUserSummary? user;
  final String? busyUserId;
  final Future<void> Function({
    required AdminUserSummary user,
    required Set<String> permissions,
  })
  onSave;

  @override
  State<_PermissionEditorPane> createState() => _PermissionEditorPaneState();
}

class _PermissionEditorPaneState extends State<_PermissionEditorPane> {
  late Set<String> _draftPermissions;

  // ignore: unused_field
  static const _definitions = <_PermissionDefinition>[
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.dashboard_outlined,
      titleAr: 'دخول اللوحة',
      titleEn: 'Dashboard access',
      titleFr: 'Acces au tableau',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.people_alt_outlined,
      titleAr: 'إدارة المستخدمين',
      titleEn: 'Users management',
      titleFr: 'Gestion des utilisateurs',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.toll_outlined,
      titleAr: 'إدارة النقاط',
      titleEn: 'Points management',
      titleFr: 'Gestion des points',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.workspace_premium_outlined,
      titleAr: 'إدارة الخطط والأدوار',
      titleEn: 'Plan and role management',
      titleFr: 'Gestion des plans et roles',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.payments_outlined,
      titleAr: 'إدارة الاشتراكات',
      titleEn: 'Subscriptions management',
      titleFr: 'Gestion des abonnements',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.translate_outlined,
      titleAr: 'إدارة اللغات',
      titleEn: 'Languages management',
      titleFr: 'Gestion des langues',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.library_books_outlined,
      titleAr: 'إدارة المحتوى',
      titleEn: 'Content management',
      titleFr: 'Gestion du contenu',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.azkarManage,
      icon: Icons.auto_stories_outlined,
      titleAr: 'إدارة الأذكار',
      titleEn: 'Azkar management',
      titleFr: 'Gestion des adhkar',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.duasManage,
      icon: Icons.menu_book_outlined,
      titleAr: 'إدارة الأدعية',
      titleEn: 'Duas management',
      titleFr: 'Gestion des invocations',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.storefront_outlined,
      titleAr: 'إدارة المتجر',
      titleEn: 'Store management',
      titleFr: 'Gestion de la boutique',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.smart_toy_outlined,
      titleAr: 'إدارة حدود AI',
      titleEn: 'AI limits management',
      titleFr: 'Gestion des limites IA',
    ),
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.graphic_eq_outlined,
      titleAr: 'إدارة الحلقات',
      titleEn: 'Halaqat management',
      titleFr: 'Gestion des halaqat',
    ),
  ];

  static const _dashboardEntryDefinitions = <_PermissionDefinition>[
    _PermissionDefinition(
      key: AdminDashboardPermission.dashboardView,
      icon: Icons.dashboard_outlined,
      titleAr: 'دخول لوحة الإدارة',
      titleEn: 'Dashboard access',
      titleFr: 'Acces au tableau',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _draftPermissions = _resolvedPermissionsForUser(widget.user);
  }

  @override
  void didUpdateWidget(covariant _PermissionEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousPermissions = _resolvedPermissionsForUser(oldWidget.user);
    final nextPermissions = _resolvedPermissionsForUser(widget.user);
    if (oldWidget.user?.uid != widget.user?.uid ||
        _setsDiffer(previousPermissions, nextPermissions)) {
      _draftPermissions = nextPermissions;
    }
  }

  Set<String> _resolvedPermissionsForUser(AdminUserSummary? user) {
    if (user == null) {
      return <String>{};
    }
    if (user.role == AdminDashboardRole.superAdmin) {
      return {...AdminDashboardPermission.all};
    }
    if (user.permissions.isNotEmpty) {
      return {...user.permissions};
    }
    return <String>{};
  }

  bool get _isBusy =>
      widget.user != null && widget.busyUserId == widget.user!.uid;

  bool _canEditTarget(AdminUserSummary user) {
    if (widget.access.role == AdminDashboardRole.superAdmin) {
      return true;
    }
    if (user.role == AdminDashboardRole.superAdmin) {
      return false;
    }
    return widget.access.can(AdminDashboardPermission.dashboardView);
  }

  bool _canTogglePermission(String permission) {
    return widget.access.can(permission);
  }

  bool _setsDiffer(Set<String> left, Set<String> right) {
    return left.length != right.length || left.difference(right).isNotEmpty;
  }

  Set<String> _adminDefaultsGrantable() {
    return {...AdminDashboardPermission.adminDefaults.where(widget.access.can)};
  }

  Set<String> _allPermissionsGrantable() {
    return {...AdminDashboardPermission.all.where(widget.access.can)};
  }

  void _applyPreset(Set<String> permissions) {
    setState(() {
      _draftPermissions = {...permissions};
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) {
      return _PermissionStateCard(
        title: adminDashText(
          context,
          ar: 'اختر مستخدمًا',
          en: 'Select a user',
          fr: 'Selectionnez un utilisateur',
        ),
        message: adminDashText(
          context,
          ar: 'اختر مستخدمًا من القائمة.',
          en: 'Choose a user from the list.',
          fr: 'Choisissez un utilisateur dans la liste.',
        ),
      );
    }

    final effectivePermissions = _resolvedPermissionsForUser(user);
    final canEdit = _canEditTarget(user);
    final hasChanges =
        _draftPermissions.length != effectivePermissions.length ||
        _draftPermissions.difference(effectivePermissions).isNotEmpty ||
        effectivePermissions.difference(_draftPermissions).isNotEmpty;

    return AdminDashboardSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.displayName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(user.email ?? user.phone ?? user.uid),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(adminDashboardRoleLabel(user.role))),
              Chip(label: Text(adminUserPlanLabel(user.plan))),
              Chip(
                label: Text(
                  user.isBlocked
                      ? adminDashText(
                          context,
                          ar: 'محظور',
                          en: 'Blocked',
                          fr: 'Bloque',
                        )
                      : adminDashText(
                          context,
                          ar: 'نشط',
                          en: 'Active',
                          fr: 'Actif',
                        ),
                ),
              ),
              Chip(
                label: Text(
                  adminDashText(
                    context,
                    ar: 'محفوظ: ${user.permissions.length}',
                    en: 'Saved: ${user.permissions.length}',
                    fr: 'Sauve: ${user.permissions.length}',
                  ),
                ),
              ),
              Chip(
                label: Text(
                  adminDashText(
                    context,
                    ar: 'فعّال: ${effectivePermissions.length}',
                    en: 'Effective: ${effectivePermissions.length}',
                    fr: 'Effectif: ${effectivePermissions.length}',
                  ),
                ),
              ),
              Chip(
                label: Text(
                  adminDashText(
                    context,
                    ar: 'المسودة: ${_draftPermissions.length}',
                    en: 'Draft: ${_draftPermissions.length}',
                    fr: 'Brouillon: ${_draftPermissions.length}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !canEdit || _isBusy
                    ? null
                    : () => _applyPreset(_adminDefaultsGrantable()),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: Text(
                  adminDashText(
                    context,
                    ar: 'افتراضي المشرف',
                    en: 'Grant Admin Defaults',
                    fr: 'Donner les droits admin',
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    !canEdit ||
                        _isBusy ||
                        widget.access.role != AdminDashboardRole.superAdmin
                    ? null
                    : () => _applyPreset(_allPermissionsGrantable()),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(
                  adminDashText(
                    context,
                    ar: 'كل الصلاحيات',
                    en: 'Grant All Permissions',
                    fr: 'Tous les droits',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: !canEdit || _isBusy
                    ? null
                    : () => _applyPreset(const <String>{}),
                icon: const Icon(Icons.clear_all_outlined),
                label: Text(
                  adminDashText(
                    context,
                    ar: 'مسح الصلاحيات',
                    en: 'Clear Permissions',
                    fr: 'Vider les droits',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 920
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                const spacing = 12.0;
                final cardWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;

                return SingleChildScrollView(
                  child: AdminDashboardGridWrap(
                    alignment: WrapAlignment.start,
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _dashboardEntryDefinitions
                        .map((definition) {
                          final enabled =
                              canEdit && _canTogglePermission(definition.key);
                          final checked = _draftPermissions.contains(
                            definition.key,
                          );

                          return SizedBox(
                            width: cardWidth,
                            child: _PermissionToggleCard(
                              definition: definition,
                              checked: checked,
                              enabled: enabled,
                              onTap: !enabled
                                  ? null
                                  : () {
                                      setState(() {
                                        if (checked) {
                                          _draftPermissions.remove(
                                            definition.key,
                                          );
                                        } else {
                                          _draftPermissions.add(definition.key);
                                        }
                                      });
                                    },
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: !canEdit || !hasChanges || _isBusy
                  ? null
                  : () {
                      widget.onSave(user: user, permissions: _draftPermissions);
                    },
              icon: _isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                adminDashText(
                  context,
                  ar: 'حفظ الصلاحيات',
                  en: 'Save permissions',
                  fr: 'Enregistrer les droits',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStateCard extends StatelessWidget {
  const _PermissionStateCard({required this.title, required this.message});

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

class _PermissionToggleCard extends StatelessWidget {
  const _PermissionToggleCard({
    required this.definition,
    required this.checked,
    required this.enabled,
    this.onTap,
  });

  final _PermissionDefinition definition;
  final bool checked;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = checked ? scheme.primary : scheme.outline;

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: GestureDetector(
        onTap: onTap,
        child: AdminDashboardSurfaceCard(
          minHeight: 168,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(definition.icon, color: accent),
                  ),
                  const Spacer(),
                  Icon(
                    checked
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: checked ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                definition.label(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                definition.key,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                enabled
                    ? adminDashText(
                        context,
                        ar: checked ? 'مفعّلة حاليًا' : 'اضغط للتفعيل',
                        en: checked ? 'Enabled now' : 'Tap to enable',
                        fr: checked
                            ? 'Active maintenant'
                            : 'Appuyez pour activer',
                      )
                    : adminDashText(
                        context,
                        ar: 'غير متاحة لهذا الحساب',
                        en: 'Not grantable by this account',
                        fr: 'Non accordable par ce compte',
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDefinition {
  const _PermissionDefinition({
    required this.key,
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.titleFr,
  });

  final String key;
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final String titleFr;

  String label(BuildContext context) {
    return adminDashText(context, ar: titleAr, en: titleEn, fr: titleFr);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
