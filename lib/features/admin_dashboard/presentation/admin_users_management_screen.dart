import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class AdminUsersManagementScreen extends StatefulWidget {
  const AdminUsersManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminUsersManagementScreen> createState() =>
      _AdminUsersManagementScreenState();
}

enum _AdminUsersFilter { all, active, premium, blocked, aiOverride }

class _AdminUsersManagementScreenState
    extends State<AdminUsersManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminUsersRepository _usersRepository;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ValueNotifier<String> _searchQueryNotifier;

  String? _busyUserId;
  _AdminUsersFilter _selectedFilter = _AdminUsersFilter.all;

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
    _searchFocusNode = FocusNode(debugLabel: 'adminUsersSearch');
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

  List<AdminUserSummary> _sortUsers(List<AdminUserSummary> users) {
    final sorted = [...users]..sort(_compareUsers);
    return sorted;
  }

  List<AdminUserSummary> _filterUsers(
    List<AdminUserSummary> users,
    String query,
  ) {
    return users
        .where((user) => user.matchesQuery(query))
        .where(_matchesSelectedFilter)
        .toList(growable: false);
  }

  bool _matchesSelectedFilter(AdminUserSummary user) {
    switch (_selectedFilter) {
      case _AdminUsersFilter.all:
        return true;
      case _AdminUsersFilter.active:
        final updatedAt = user.updatedAt ?? user.createdAt;
        return updatedAt != null &&
            !updatedAt.isBefore(
              DateTime.now().subtract(const Duration(days: 7)),
            );
      case _AdminUsersFilter.premium:
        return user.plan != AdminUserPlan.free;
      case _AdminUsersFilter.blocked:
        return user.isBlocked;
      case _AdminUsersFilter.aiOverride:
        return user.aiUsageLimitOverride != null;
    }
  }

  int _compareUsers(AdminUserSummary left, AdminUserSummary right) {
    final leftCreatedAt = left.createdAt;
    final rightCreatedAt = right.createdAt;

    if (leftCreatedAt != null && rightCreatedAt != null) {
      final createdAtComparison = rightCreatedAt.compareTo(leftCreatedAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
    } else if (leftCreatedAt != null) {
      return -1;
    } else if (rightCreatedAt != null) {
      return 1;
    }

    final leftUpdatedAt = left.updatedAt;
    final rightUpdatedAt = right.updatedAt;
    if (leftUpdatedAt != null && rightUpdatedAt != null) {
      final updatedAtComparison = rightUpdatedAt.compareTo(leftUpdatedAt);
      if (updatedAtComparison != 0) {
        return updatedAtComparison;
      }
    } else if (leftUpdatedAt != null) {
      return -1;
    } else if (rightUpdatedAt != null) {
      return 1;
    }

    return left.displayName.toLowerCase().compareTo(
      right.displayName.toLowerCase(),
    );
  }

  bool _canManageTarget(
    AdminDashboardAccess access,
    AdminUserSummary targetUser,
  ) {
    if (access.role == AdminDashboardRole.superAdmin) {
      return true;
    }
    return targetUser.role != AdminDashboardRole.superAdmin;
  }

  bool _canEditSettings(
    AdminDashboardAccess access,
    AdminUserSummary targetUser,
  ) {
    final hasSettingsPermission =
        access.can(AdminDashboardPermission.dashboardView) ||
        access.can(AdminDashboardPermission.dashboardView);
    return hasSettingsPermission && _canManageTarget(access, targetUser);
  }

  bool _canEditPoints(
    AdminDashboardAccess access,
    AdminUserSummary targetUser,
  ) {
    return access.can(AdminDashboardPermission.dashboardView) &&
        _canManageTarget(access, targetUser);
  }

  String _settingsActionTooltip(
    AdminDashboardAccess access,
    AdminUserSummary targetUser,
    BuildContext context,
  ) {
    if (_canEditSettings(access, targetUser)) {
      return adminDashText(
        context,
        ar: 'تعديل الخطة والدور والحظر وحد AI',
        en: 'Edit plan, role, block status, and AI override',
        fr: 'Modifier le plan, le role, le blocage et la limite IA',
      );
    }
    if (!_canManageTarget(access, targetUser)) {
      return adminDashText(
        context,
        ar: 'لا يمكن للمشرف العادي إدارة حسابات superAdmin',
        en: 'Standard admins cannot manage superAdmin accounts.',
        fr: 'Un admin standard ne peut pas gerer un superAdmin',
      );
    }
    return adminDashText(
      context,
      ar: 'لا توجد صلاحية كافية لهذا التعديل',
      en: 'Missing permission to edit plans, roles, blocking, or AI limits.',
      fr: 'Autorisation insuffisante pour cette modification',
    );
  }

  String _pointsActionTooltip(
    AdminDashboardAccess access,
    AdminUserSummary targetUser,
    BuildContext context,
  ) {
    if (_canEditPoints(access, targetUser)) {
      return adminDashText(
        context,
        ar: 'إضافة أو خصم نقاط',
        en: 'Add or subtract points',
        fr: 'Ajouter ou retirer des points',
      );
    }
    if (!_canManageTarget(access, targetUser)) {
      return adminDashText(
        context,
        ar: 'لا يمكن للمشرف العادي إدارة حسابات superAdmin',
        en: 'Standard admins cannot manage superAdmin accounts.',
        fr: 'Un admin standard ne peut pas gerer un superAdmin',
      );
    }
    return adminDashText(
      context,
      ar: 'لا توجد صلاحية لإدارة النقاط',
      en: 'Missing permission to edit points.',
      fr: 'Autorisation insuffisante pour les points',
    );
  }

  Future<void> _openEditDialog(
    AdminDashboardAccess access,
    AdminUserSummary user,
  ) async {
    final result = await showDialog<_UserSettingsUpdateResult>(
      context: context,
      builder: (context) => _EditUserDialog(access: access, user: user),
    );

    if (result == null) {
      return;
    }
    if (!result.hasChanges) {
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'لا توجد تعديلات للحفظ.',
          en: 'No changes to save.',
          fr: 'Aucun changement à enregistrer.',
        ),
      );
      return;
    }

    setState(() {
      _busyUserId = user.uid;
    });

    try {
      await _usersRepository.updateUserSettings(
        uid: user.uid,
        plan: result.plan,
        role: result.role,
        isBlocked: result.isBlocked,
        aiUsageLimitOverride: result.aiUsageLimitOverride,
        clearAiUsageLimitOverride: result.clearAiUsageLimitOverride,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث بيانات المستخدم.',
          en: 'User updated successfully.',
          fr: 'Utilisateur mis à jour avec succès.',
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

  Future<void> _toggleUserStatus(
    AdminDashboardAccess access,
    AdminUserSummary user,
  ) async {
    if (!_canEditSettings(access, user)) {
      return;
    }
    setState(() {
      _busyUserId = user.uid;
    });
    try {
      await _usersRepository.updateUserStatus(
        uid: user.uid,
        isBlocked: !user.isBlocked,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: user.isBlocked ? 'تم تنشيط المستخدم.' : 'تم حظر المستخدم.',
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
          _busyUserId = null;
        });
      }
    }
  }

  Future<void> _openUserDetails(AdminUserSummary user) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _UserDetailsDialog(user: user, formatDate: _formatDate),
    );
  }

  Future<void> _openPointsDialog(
    AdminDashboardAccess access,
    AdminUserSummary user,
  ) async {
    final result = await showDialog<_PointsAdjustmentResult>(
      context: context,
      builder: (context) => _PointsDialog(user: user),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _busyUserId = user.uid;
    });

    try {
      await _usersRepository.adjustUserPoints(
        uid: user.uid,
        delta: result.delta,
      );
      if (!mounted) {
        return;
      }
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: result.delta >= 0 ? 'تمت إضافة النقاط.' : 'تم خصم النقاط.',
          en: result.delta >= 0
              ? 'Points added successfully.'
              : 'Points deducted successfully.',
          fr: result.delta >= 0
              ? 'Points ajoutés avec succès.'
              : 'Points retirés avec succès.',
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Future<void> _copyUsersCsv(List<AdminUserSummary> users) async {
    if (users.isEmpty) {
      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'لا توجد بيانات لتصديرها.',
          en: 'No users to export.',
          fr: 'Aucun utilisateur a exporter.',
        ),
      );
      return;
    }

    final rows = <List<String>>[
      [
        'uid',
        'name',
        'email',
        'phone',
        'plan',
        'role',
        'points',
        'blocked',
        'ai_usage_limit_override',
        'created_at',
        'updated_at',
      ],
      ...users.map(
        (user) => [
          user.uid,
          user.name,
          user.email ?? '',
          user.phone ?? '',
          user.planId,
          adminDashboardRoleValue(user.role),
          user.points.toString(),
          user.isBlocked ? 'true' : 'false',
          user.aiUsageLimitOverride?.toString() ?? '',
          _formatDate(user.createdAt),
          _formatDate(user.updatedAt),
        ],
      ),
    ];

    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');

    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) {
      return;
    }
    showAdminDashboardSnackBar(
      context,
      message: adminDashText(
        context,
        ar: 'تم نسخ ملف CSV للمستخدمين إلى الحافظة.',
        en: 'Users CSV copied to clipboard.',
        fr: 'CSV utilisateurs copie dans le presse-papiers.',
      ),
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('\r') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
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
            ar: 'إدارة المستخدمين',
            en: 'Users',
            fr: 'Utilisateurs',
          ),
          currentRoute: AppRouter.adminDashboardUsersRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminUserSummary>>(
            stream: _usersRepository.watchUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _AdminUsersStateCard(
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

              final sortedUsers = _sortUsers(snapshot.data!);

              return LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UsersToolbar(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        searchQueryListenable: _searchQueryNotifier,
                        allUsers: sortedUsers,
                        filterUsers: _filterUsers,
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (filter) {
                          setState(() => _selectedFilter = filter);
                        },
                        onExportCsv: () => _copyUsersCsv(
                          _filterUsers(sortedUsers, _searchQueryNotifier.value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _searchQueryNotifier,
                          builder: (context, query, _) {
                            final filteredUsers = _filterUsers(
                              sortedUsers,
                              query,
                            );

                            if (filteredUsers.isEmpty) {
                              return _AdminUsersStateCard(
                                title: adminDashText(
                                  context,
                                  ar: 'لا توجد نتائج',
                                  en: 'No results',
                                  fr: 'Aucun résultat',
                                ),
                                message: adminDashText(
                                  context,
                                  ar: 'جرّب تعديل البحث.',
                                  en: 'Try refining the search.',
                                  fr: 'Essayez d’affiner la recherche.',
                                ),
                              );
                            }

                            return _UsersCardsList(
                              users: filteredUsers,
                              access: access,
                              busyUserId: _busyUserId,
                              canEditSettings: _canEditSettings,
                              canEditPoints: _canEditPoints,
                              settingsActionTooltip: (a, u) =>
                                  _settingsActionTooltip(a, u, context),
                              pointsActionTooltip: (a, u) =>
                                  _pointsActionTooltip(a, u, context),
                              onEditPressed: _openEditDialog,
                              onPointsPressed: _openPointsDialog,
                              onStatusPressed: _toggleUserStatus,
                              onDetailsPressed: _openUserDetails,
                              formatDate: _formatDate,
                            );
                          },
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

class _UsersToolbar extends StatelessWidget {
  const _UsersToolbar({
    required this.controller,
    required this.focusNode,
    required this.searchQueryListenable,
    required this.allUsers,
    required this.filterUsers,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onExportCsv,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<String> searchQueryListenable;
  final List<AdminUserSummary> allUsers;
  final List<AdminUserSummary> Function(List<AdminUserSummary>, String)
  filterUsers;
  final _AdminUsersFilter selectedFilter;
  final ValueChanged<_AdminUsersFilter> onFilterChanged;
  final VoidCallback onExportCsv;

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
                    ar: 'ابحث بالاسم أو البريد أو الهاتف',
                    en: 'Search by name, email, or phone',
                    fr: 'Recherche par nom, e-mail ou téléphone',
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

        final countChip = ValueListenableBuilder<String>(
          valueListenable: searchQueryListenable,
          builder: (context, query, _) {
            final resultCount = filterUsers(allUsers, query).length;
            return Chip(
              label: Text(
                adminDashText(
                  context,
                  ar: 'النتائج: $resultCount',
                  en: 'Results: $resultCount',
                  fr: 'Résultats : $resultCount',
                ),
              ),
            );
          },
        );
        final exportButton = OutlinedButton.icon(
          onPressed: onExportCsv,
          icon: const Icon(Icons.download_outlined),
          label: Text(
            adminDashText(
              context,
              ar: 'تصدير CSV',
              en: 'Export CSV',
              fr: 'Exporter CSV',
            ),
          ),
        );
        final filterControl = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_AdminUsersFilter>(
            segments: const [
              ButtonSegment(value: _AdminUsersFilter.all, label: Text('الكل')),
              ButtonSegment(
                value: _AdminUsersFilter.active,
                label: Text('نشط'),
              ),
              ButtonSegment(
                value: _AdminUsersFilter.premium,
                label: Text('مشترك'),
              ),
              ButtonSegment(
                value: _AdminUsersFilter.blocked,
                label: Text('محظور'),
              ),
              ButtonSegment(
                value: _AdminUsersFilter.aiOverride,
                label: Text('AI'),
              ),
            ],
            selected: {selectedFilter},
            onSelectionChanged: (value) => onFilterChanged(value.first),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              filterControl,
              const SizedBox(height: 12),
              Row(
                children: [
                  countChip,
                  const Spacer(),
                  Flexible(child: exportButton),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 12),
            filterControl,
            const SizedBox(width: 12),
            countChip,
            const SizedBox(width: 12),
            exportButton,
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _UsersDataTable extends StatelessWidget {
  const _UsersDataTable({
    required this.users,
    required this.access,
    required this.busyUserId,
    required this.canEditSettings,
    required this.canEditPoints,
    required this.settingsActionTooltip,
    required this.pointsActionTooltip,
    required this.onEditPressed,
    required this.onPointsPressed,
    required this.onStatusPressed,
    required this.onDetailsPressed,
    required this.formatDate,
  });

  final List<AdminUserSummary> users;
  final AdminDashboardAccess access;
  final String? busyUserId;
  final bool Function(AdminDashboardAccess, AdminUserSummary) canEditSettings;
  final bool Function(AdminDashboardAccess, AdminUserSummary) canEditPoints;
  final String Function(AdminDashboardAccess, AdminUserSummary)
  settingsActionTooltip;
  final String Function(AdminDashboardAccess, AdminUserSummary)
  pointsActionTooltip;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onEditPressed;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onPointsPressed;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onStatusPressed;
  final Future<void> Function(AdminUserSummary) onDetailsPressed;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1180),
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                dataRowMinHeight: 76,
                dataRowMaxHeight: 116,
                columns: [
                  DataColumn(
                    label: Text(
                      adminDashText(
                        context,
                        ar: 'المستخدم',
                        en: 'User',
                        fr: 'Utilisateur',
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      adminDashText(
                        context,
                        ar: 'الخطة',
                        en: 'Plan',
                        fr: 'Plan',
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      adminDashText(
                        context,
                        ar: 'الدور',
                        en: 'Role',
                        fr: 'Role',
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      adminDashText(
                        context,
                        ar: 'النقاط',
                        en: 'Points',
                        fr: 'Points',
                      ),
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
                        ar: 'الإنشاء',
                        en: 'Created',
                        fr: 'Creation',
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
                rows: users
                    .map((user) {
                      final settingsEnabled = canEditSettings(access, user);
                      final pointsEnabled = canEditPoints(access, user);
                      final isBusy = busyUserId == user.uid;

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 280,
                              child: _UserIdentityCell(user: user),
                            ),
                          ),
                          DataCell(
                            _InfoChip(label: adminUserPlanLabel(user.plan)),
                          ),
                          DataCell(
                            _InfoChip(
                              label: adminDashboardRoleLabel(user.role),
                            ),
                          ),
                          DataCell(Text('${user.points}')),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    label: user.isBlocked
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
                                    color: user.isBlocked
                                        ? Colors.red.shade100
                                        : Colors.green.shade100,
                                  ),
                                  if (user.aiUsageLimitOverride != null)
                                    _InfoChip(
                                      label: 'AI: ${user.aiUsageLimitOverride}',
                                      color: Colors.orange.shade100,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              formatDate(user.lastLoginAt ?? user.updatedAt),
                            ),
                          ),
                          DataCell(
                            isBusy
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : SizedBox(
                                    width: 330,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed: settingsEnabled
                                              ? () => onStatusPressed(
                                                  access,
                                                  user,
                                                )
                                              : null,
                                          icon: Icon(
                                            user.isBlocked
                                                ? Icons.check_circle_outline
                                                : Icons.block_outlined,
                                          ),
                                          label: Text(
                                            user.isBlocked ? 'تنشيط' : 'حظر',
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              onDetailsPressed(user),
                                          icon: const Icon(
                                            Icons.info_outline_rounded,
                                          ),
                                          label: const Text('تفاصيل'),
                                        ),
                                        Tooltip(
                                          message: settingsActionTooltip(
                                            access,
                                            user,
                                          ),
                                          child: FilledButton.tonalIcon(
                                            onPressed: settingsEnabled
                                                ? () => onEditPressed(
                                                    access,
                                                    user,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
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
                                        Tooltip(
                                          message: pointsActionTooltip(
                                            access,
                                            user,
                                          ),
                                          child: OutlinedButton.icon(
                                            onPressed: pointsEnabled
                                                ? () => onPointsPressed(
                                                    access,
                                                    user,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.toll_outlined,
                                            ),
                                            label: Text(
                                              adminDashText(
                                                context,
                                                ar: 'نقاط',
                                                en: 'Points',
                                                fr: 'Points',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsersCardsList extends StatelessWidget {
  const _UsersCardsList({
    required this.users,
    required this.access,
    required this.busyUserId,
    required this.canEditSettings,
    required this.canEditPoints,
    required this.settingsActionTooltip,
    required this.pointsActionTooltip,
    required this.onEditPressed,
    required this.onPointsPressed,
    required this.onStatusPressed,
    required this.onDetailsPressed,
    required this.formatDate,
  });

  final List<AdminUserSummary> users;
  final AdminDashboardAccess access;
  final String? busyUserId;
  final bool Function(AdminDashboardAccess, AdminUserSummary) canEditSettings;
  final bool Function(AdminDashboardAccess, AdminUserSummary) canEditPoints;
  final String Function(AdminDashboardAccess, AdminUserSummary)
  settingsActionTooltip;
  final String Function(AdminDashboardAccess, AdminUserSummary)
  pointsActionTooltip;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onEditPressed;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onPointsPressed;
  final Future<void> Function(AdminDashboardAccess, AdminUserSummary)
  onStatusPressed;
  final Future<void> Function(AdminUserSummary) onDetailsPressed;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? 3
            : constraints.maxWidth >= 820
            ? 2
            : 1;
        return GridView.builder(
          itemCount: users.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 260,
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            final settingsEnabled = canEditSettings(access, user);
            final pointsEnabled = canEditPoints(access, user);
            final isBusy = busyUserId == user.uid;

            return AdminDashboardSurfaceCard(
              minHeight: 218,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UserIdentityCell(user: user),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: adminUserPlanLabel(user.plan)),
                        _InfoChip(label: adminDashboardRoleLabel(user.role)),
                        _InfoChip(
                          label: adminDashText(
                            context,
                            ar: 'النقاط: ${user.points}',
                            en: 'Points: ${user.points}',
                            fr: 'Points : ${user.points}',
                          ),
                        ),
                        _InfoChip(
                          label: user.isBlocked
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
                          color: user.isBlocked
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                        ),
                        if (user.aiUsageLimitOverride != null)
                          _InfoChip(
                            label: 'AI: ${user.aiUsageLimitOverride}',
                            color: Colors.orange.shade100,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      adminDashText(
                        context,
                        ar: 'الإنشاء: ${formatDate(user.createdAt)}',
                        en: 'Created: ${formatDate(user.createdAt)}',
                        fr: 'Creation : ${formatDate(user.createdAt)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isBusy)
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: settingsEnabled
                                ? () => onStatusPressed(access, user)
                                : null,
                            icon: Icon(
                              user.isBlocked
                                  ? Icons.check_circle_outline
                                  : Icons.block_outlined,
                            ),
                            label: Text(user.isBlocked ? 'تنشيط' : 'حظر'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onDetailsPressed(user),
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('تفاصيل'),
                          ),
                          Tooltip(
                            message: settingsActionTooltip(access, user),
                            child: FilledButton.tonalIcon(
                              onPressed: settingsEnabled
                                  ? () => onEditPressed(access, user)
                                  : null,
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
                          ),
                          Tooltip(
                            message: pointsActionTooltip(access, user),
                            child: OutlinedButton.icon(
                              onPressed: pointsEnabled
                                  ? () => onPointsPressed(access, user)
                                  : null,
                              icon: const Icon(Icons.toll_outlined),
                              label: Text(
                                adminDashText(
                                  context,
                                  ar: 'نقاط',
                                  en: 'Points',
                                  fr: 'Points',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserIdentityCell extends StatelessWidget {
  const _UserIdentityCell({required this.user});

  final AdminUserSummary user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          user.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email ??
              adminDashText(
                context,
                ar: 'لا يوجد بريد',
                en: 'No email',
                fr: 'Aucun e-mail',
              ),
        ),
        const SizedBox(height: 2),
        Text(
          user.phone ??
              adminDashText(
                context,
                ar: 'لا يوجد هاتف',
                en: 'No phone',
                fr: 'Aucun telephone',
              ),
        ),
        const SizedBox(height: 2),
        Text(
          user.uid,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color,
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AdminUsersStateCard extends StatelessWidget {
  const _AdminUsersStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AdminDashboardSurfaceCard(
          child: Padding(
            padding: EdgeInsets.zero,
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

class _UserDetailsDialog extends StatelessWidget {
  const _UserDetailsDialog({required this.user, required this.formatDate});

  final AdminUserSummary user;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('UID', user.uid),
      MapEntry(
        'الاسم',
        user.name.trim().isEmpty ? user.displayName : user.name,
      ),
      MapEntry('البريد', user.email ?? 'غير متاح'),
      MapEntry('الهاتف', user.phone ?? 'غير متاح'),
      MapEntry('الخطة', adminUserPlanLabel(user.plan)),
      MapEntry('الدور', adminDashboardRoleLabel(user.role)),
      MapEntry('النقاط', '${user.points}'),
      MapEntry('الحالة', user.isBlocked ? 'محظور' : 'نشط'),
      MapEntry('آخر دخول', formatDate(user.lastLoginAt)),
      MapEntry('آخر تحديث', formatDate(user.updatedAt)),
      MapEntry('تاريخ الإنشاء', formatDate(user.createdAt)),
      MapEntry(
        'الصلاحيات',
        user.permissions.isEmpty ? 'لا توجد' : user.permissions.join(', '),
      ),
      MapEntry('حد AI', user.aiUsageLimitOverride?.toString() ?? 'حسب الخطة'),
    ];

    return AlertDialog(
      title: Text(user.displayName),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          row.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: SelectableText(row.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.access, required this.user});

  final AdminDashboardAccess access;
  final AdminUserSummary user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _aiLimitController;
  late AdminUserPlan _selectedPlan;
  late AdminDashboardRole _selectedRole;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.user.plan;
    _selectedRole = widget.user.role;
    _isBlocked = widget.user.isBlocked;
    _aiLimitController = TextEditingController(
      text: widget.user.aiUsageLimitOverride?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _aiLimitController.dispose();
    super.dispose();
  }

  bool get _isSelf => widget.access.uid == widget.user.uid;

  bool get _canManagePlanRoleBlock =>
      widget.access.can(AdminDashboardPermission.dashboardView) &&
      (widget.access.role == AdminDashboardRole.superAdmin ||
          widget.user.role != AdminDashboardRole.superAdmin);

  bool get _canManageAiLimit =>
      widget.access.can(AdminDashboardPermission.dashboardView) &&
      (widget.access.role == AdminDashboardRole.superAdmin ||
          widget.user.role != AdminDashboardRole.superAdmin);

  List<AdminUserPlan> get _availablePlans {
    if (!_isSelf) {
      return AdminUserPlan.values;
    }

    final currentRank = adminUserPlanRank(widget.user.plan);
    return AdminUserPlan.values
        .where((plan) => adminUserPlanRank(plan) >= currentRank)
        .toList(growable: false);
  }

  List<AdminDashboardRole> get _availableRoles {
    if (widget.access.role == AdminDashboardRole.superAdmin) {
      return AdminDashboardRole.values;
    }
    return const [AdminDashboardRole.user, AdminDashboardRole.admin];
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (_isSelf &&
        adminUserPlanRank(_selectedPlan) <
            adminUserPlanRank(widget.user.plan)) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'لا يمكنك تخفيض باقتك من هنا.',
          en: 'You cannot downgrade your own subscription from this page.',
          fr: 'Vous ne pouvez pas rétrograder votre propre abonnement ici.',
        ),
      );
      return;
    }

    if (_isSelf && _selectedRole != widget.user.role) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'لا يمكنك تغيير دورك الإداري.',
          en: 'You cannot change your own admin role.',
          fr: 'Vous ne pouvez pas modifier votre propre rôle admin.',
        ),
      );
      return;
    }

    if (_isSelf && _isBlocked != widget.user.isBlocked) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'لا يمكنك حظر حسابك الحالي.',
          en: 'You cannot block your current account.',
          fr: 'Vous ne pouvez pas bloquer votre compte actuel.',
        ),
      );
      return;
    }

    if (widget.access.role != AdminDashboardRole.superAdmin &&
        _selectedRole == AdminDashboardRole.superAdmin) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'فقط superAdmin يمكنه تعيين هذا الدور.',
          en: 'Only a superAdmin can assign the superAdmin role.',
          fr: 'Seul un superAdmin peut attribuer ce rôle.',
        ),
      );
      return;
    }

    final aiLimitText = _aiLimitController.text.trim();
    int? aiLimitOverride;
    var clearAiUsageLimitOverride = false;

    if (aiLimitText.isEmpty) {
      clearAiUsageLimitOverride = widget.user.aiUsageLimitOverride != null;
    } else {
      aiLimitOverride = int.tryParse(aiLimitText);
      if (aiLimitOverride == null || aiLimitOverride < 0) {
        _showValidationMessage(
          adminDashText(
            context,
            ar: 'أدخل حد AI صحيحًا أو اتركه فارغًا.',
            en: 'Enter a valid non-negative AI limit or leave it empty.',
            fr: 'Saisissez une limite IA valide ou laissez vide.',
          ),
        );
        return;
      }
    }

    Navigator.of(context).pop(
      _UserSettingsUpdateResult(
        plan: _selectedPlan != widget.user.plan ? _selectedPlan : null,
        role: _selectedRole != widget.user.role ? _selectedRole : null,
        isBlocked: _isBlocked != widget.user.isBlocked ? _isBlocked : null,
        aiUsageLimitOverride:
            aiLimitText.isNotEmpty &&
                aiLimitOverride != widget.user.aiUsageLimitOverride
            ? aiLimitOverride
            : null,
        clearAiUsageLimitOverride: clearAiUsageLimitOverride,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planFieldEnabled = _canManagePlanRoleBlock;
    final roleFieldEnabled = _canManagePlanRoleBlock && !_isSelf;
    final blockFieldEnabled = _canManagePlanRoleBlock && !_isSelf;
    final aiFieldEnabled = _canManageAiLimit;

    return AlertDialog(
      title: Text(widget.user.displayName),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.email ?? widget.user.uid),
              const SizedBox(height: 16),
              DropdownButtonFormField<AdminUserPlan>(
                initialValue: _selectedPlan,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الخطة',
                    en: 'Plan',
                    fr: 'Plan',
                  ),
                ),
                items: _availablePlans
                    .map(
                      (plan) => DropdownMenuItem<AdminUserPlan>(
                        value: plan,
                        child: Text(adminUserPlanLabel(plan)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: planFieldEnabled
                    ? (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedPlan = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdminDashboardRole>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'الدور',
                    en: 'Role',
                    fr: 'Rôle',
                  ),
                ),
                items: _availableRoles
                    .map(
                      (role) => DropdownMenuItem<AdminDashboardRole>(
                        value: role,
                        child: Text(adminDashboardRoleLabel(role)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: roleFieldEnabled
                    ? (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedRole = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  adminDashText(
                    context,
                    ar: 'حظر المستخدم',
                    en: 'Block user',
                    fr: 'Bloquer l’utilisateur',
                  ),
                ),
                value: _isBlocked,
                onChanged: blockFieldEnabled
                    ? (value) {
                        setState(() {
                          _isBlocked = value;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aiLimitController,
                enabled: aiFieldEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adminDashText(
                    context,
                    ar: 'حد AI المخصص',
                    en: 'AI usage override',
                    fr: 'Limite IA personnalisée',
                  ),
                  hintText: adminDashText(
                    context,
                    ar: 'فارغ = استخدام حد الخطة',
                    en: 'Empty = use plan limit',
                    fr: 'Vide = limite du plan',
                  ),
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
            adminDashText(context, ar: 'حفظ', en: 'Save', fr: 'Enregistrer'),
          ),
        ),
      ],
    );
  }
}

class _PointsDialog extends StatefulWidget {
  const _PointsDialog({required this.user});

  final AdminUserSummary user;

  @override
  State<_PointsDialog> createState() => _PointsDialogState();
}

class _PointsDialogState extends State<_PointsDialog> {
  static const _quickAmounts = <int>[10, 25, 50, 100, 250];

  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit({required bool isAddition}) {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل عدد نقاط أكبر من صفر.',
          en: 'Enter a positive number of points.',
          fr: 'Entrez un nombre de points positif.',
        ),
      );
      return;
    }

    if (!isAddition && amount > widget.user.points) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'لا يمكن خصم أكثر من الرصيد الحالي.',
          en: 'You cannot subtract more points than the current balance.',
          fr: 'Vous ne pouvez pas retirer plus que le solde actuel.',
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(_PointsAdjustmentResult(delta: isAddition ? amount : -amount));
  }

  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final previewAdd = widget.user.points + amount;
    final previewSubtract = widget.user.points - amount;

    return AlertDialog(
      title: Text(
        adminDashText(
          context,
          ar: 'النقاط - ${widget.user.displayName}',
          en: 'Points - ${widget.user.displayName}',
          fr: 'Points - ${widget.user.displayName}',
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDashboardFormSection(
              title: adminDashText(
                context,
                ar: 'الرصيد الحالي',
                en: 'Current balance',
                fr: 'Solde actuel',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${widget.user.points}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    adminDashText(
                      context,
                      ar: 'اختر قيمة سريعة أو اكتب عدد النقاط يدويًا.',
                      en: 'Choose a quick value or enter points manually.',
                      fr: 'Choisissez une valeur rapide ou saisissez les points manuellement.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AdminDashboardFormSection(
              title: adminDashText(
                context,
                ar: 'قيمة التعديل',
                en: 'Adjustment amount',
                fr: 'Valeur de l ajustement',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickAmounts
                        .map((quickAmount) {
                          final isSelected =
                              _amountController.text.trim() == '$quickAmount';
                          return ChoiceChip(
                            label: Text('$quickAmount'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _amountController.text = '$quickAmount';
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: adminDashText(
                        context,
                        ar: 'عدد النقاط',
                        en: 'Points amount',
                        fr: 'Nombre de points',
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AdminDashboardMetricCard(
                    label: adminDashText(
                      context,
                      ar: 'بعد الإضافة',
                      en: 'After add',
                      fr: 'Apres ajout',
                    ),
                    value: '$previewAdd',
                    icon: Icons.add_circle_outline,
                    tint: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminDashboardMetricCard(
                    label: adminDashText(
                      context,
                      ar: 'بعد الخصم',
                      en: 'After subtract',
                      fr: 'Apres retrait',
                    ),
                    value: previewSubtract >= 0 ? '$previewSubtract' : '0',
                    icon: Icons.remove_circle_outline,
                    tint: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            adminDashText(context, ar: 'إلغاء', en: 'Cancel', fr: 'Annuler'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _submit(isAddition: false),
          icon: const Icon(Icons.remove_circle_outline),
          label: Text(
            adminDashText(context, ar: 'خصم', en: 'Subtract', fr: 'Retirer'),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _submit(isAddition: true),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(
            adminDashText(context, ar: 'إضافة', en: 'Add', fr: 'Ajouter'),
          ),
        ),
      ],
    );
  }
}

class _UserSettingsUpdateResult {
  const _UserSettingsUpdateResult({
    this.plan,
    this.role,
    this.isBlocked,
    this.aiUsageLimitOverride,
    this.clearAiUsageLimitOverride = false,
  });

  final AdminUserPlan? plan;
  final AdminDashboardRole? role;
  final bool? isBlocked;
  final int? aiUsageLimitOverride;
  final bool clearAiUsageLimitOverride;

  bool get hasChanges =>
      plan != null ||
      role != null ||
      isBlocked != null ||
      aiUsageLimitOverride != null ||
      clearAiUsageLimitOverride;
}

class _PointsAdjustmentResult {
  const _PointsAdjustmentResult({required this.delta});

  final int delta;
}
