// ignore_for_file: unused_element, unused_field

import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../data/firestore_admin_audit_log_repository.dart';
import '../data/firestore_admin_dashboard_summary_repository.dart';
import '../data/firestore_admin_schema_maintenance_repository.dart';
import '../data/firestore_admin_users_repository.dart';
import '../models/admin_dashboard_access.dart';
import '../models/admin_audit_log_entry.dart';
import '../models/admin_dashboard_summary.dart';
import '../models/admin_user_summary.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminDashboardHomeScreen extends StatefulWidget {
  const AdminDashboardHomeScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminDashboardHomeScreen> createState() =>
      _AdminDashboardHomeScreenState();
}

class _AdminDashboardHomeScreenState extends State<AdminDashboardHomeScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminDashboardSummaryRepository _summaryRepository;
  late final FirestoreAdminAuditLogRepository _auditLogRepository;
  late final FirestoreAdminUsersRepository _usersRepository;
  late final FirestoreAdminSchemaMaintenanceRepository
  _schemaMaintenanceRepository;

  _MaintenanceAction? _runningAction;
  _MaintenanceStatus? _maintenanceStatus;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _summaryRepository = FirestoreAdminDashboardSummaryRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _auditLogRepository = FirestoreAdminAuditLogRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _usersRepository = FirestoreAdminUsersRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _schemaMaintenanceRepository = FirestoreAdminSchemaMaintenanceRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
  }

  Future<void> _runMaintenanceAction(_MaintenanceAction action) async {
    final strings = _HomeStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(action.confirmationTitle(strings)),
          content: Text(action.confirmationMessage(strings)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(action.icon),
              label: Text(action.confirmationButton(strings)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _runningAction = action;
      _maintenanceStatus = _MaintenanceStatus(
        title: action.runningTitle(strings),
        message: action.runningMessage(strings),
        icon: action.icon,
        tone: _MaintenanceTone.inProgress,
      );
    });

    try {
      late final AdminMaintenanceActionResult result;
      switch (action) {
        case _MaintenanceAction.systemSync:
          result = await _schemaMaintenanceRepository.runSystemSync(
            appConfigRepository: widget.services.appConfigRepository,
            planRepository: widget.services.planRepository,
          );
          break;
        case _MaintenanceAction.resetAiUsage:
          result = await _schemaMaintenanceRepository.resetAllAiUsage();
          break;
        case _MaintenanceAction.rebuildPermissionsCache:
          result = await _schemaMaintenanceRepository.rebuildPermissionsCache();
          break;
      }

      if (!mounted) {
        return;
      }

      final successMessage = _buildSuccessMessage(strings, action, result);
      setState(() {
        _runningAction = null;
        _maintenanceStatus = _MaintenanceStatus(
          title: action.successTitle(strings),
          message: successMessage,
          icon: Icons.check_circle_outline_rounded,
          tone: _MaintenanceTone.success,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(successMessage),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final errorMessage = mapAppErrorToArabic(error);
      setState(() {
        _runningAction = null;
        _maintenanceStatus = _MaintenanceStatus(
          title: action.failureTitle(strings),
          message: errorMessage,
          icon: Icons.error_outline_rounded,
          tone: _MaintenanceTone.error,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(errorMessage),
        ),
      );
    }
  }

  String _buildSuccessMessage(
    _HomeStrings strings,
    _MaintenanceAction action,
    AdminMaintenanceActionResult result,
  ) {
    switch (action) {
      case _MaintenanceAction.systemSync:
        final usersUpdated = result.summary['usersUpdated'] as int? ?? 0;
        return strings.systemSyncSuccess(usersUpdated: usersUpdated);
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageSuccess(affectedUsers: result.affectedCount);
      case _MaintenanceAction.rebuildPermissionsCache:
        final backfilledUsers = result.summary['backfilledUsers'] as int? ?? 0;
        final permissionsUpdated =
            result.summary['permissionsUpdated'] as int? ??
            result.affectedCount;
        return strings.rebuildPermissionsSuccess(
          backfilledUsers: backfilledUsers,
          permissionsUpdated: permissionsUpdated,
        );
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
        final strings = _HomeStrings.of(context);

        return AdminDashboardScaffold(
          title: strings.dashboardTitle,
          currentRoute: AppRouter.adminDashboardHomeRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<AdminDashboardSummary>(
            stream: _summaryRepository.watchSummary(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _HomeStateCard(
                  title: strings.summaryLoadFailureTitle,
                  message: mapAppErrorToArabic(snapshot.error!),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return _FigmaHomeBody(
                access: access,
                summary: snapshot.data!,
                usersRepository: _usersRepository,
                auditLogRepository: _auditLogRepository,
                runningAction: _runningAction,
                maintenanceStatus: _maintenanceStatus,
                onMaintenanceAction: _runMaintenanceAction,
                strings: strings,
              );
            },
          ),
        );
      },
    );
  }
}

class _FigmaHomeBody extends StatelessWidget {
  const _FigmaHomeBody({
    required this.access,
    required this.summary,
    required this.usersRepository,
    required this.auditLogRepository,
    required this.runningAction,
    required this.maintenanceStatus,
    required this.onMaintenanceAction,
    required this.strings,
  });

  final AdminDashboardAccess access;
  final AdminDashboardSummary summary;
  final FirestoreAdminUsersRepository usersRepository;
  final FirestoreAdminAuditLogRepository auditLogRepository;
  final _MaintenanceAction? runningAction;
  final _MaintenanceStatus? maintenanceStatus;
  final Future<void> Function(_MaintenanceAction action) onMaintenanceAction;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    Object.hash(
      auditLogRepository,
      runningAction,
      maintenanceStatus,
      onMaintenanceAction,
    );

    final contentCount =
        summary.totalDhikrCategories +
        summary.totalDuas +
        summary.totalStoreItems;
    final remainingTokens = summary.availableAiTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _DashboardHomeTitle(access: access, strings: strings),
            const SizedBox(height: 22),
            _ResponsiveHomeRow(
              isWide: isWide,
              children: [
                _DashboardOverviewCard(
                  title: strings.totalMoneyTitle,
                  value: '0 EGP',
                  subtitle: strings.subscriptionRevenueSubtitle,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _DashboardOverviewCard(
                  title: strings.subscribedUsersTitle,
                  value: '${summary.premiumUsers}',
                  subtitle: strings.subscribedUsersSubtitle,
                  icon: Icons.verified_user_outlined,
                ),
                _UsersBreakdownCard(summary: summary, strings: strings),
              ],
            ),
            const SizedBox(height: 18),
            isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 270,
                          child: Column(
                            children: [
                              Expanded(
                                child: _DashboardOverviewCard(
                                  title: strings.contentTitle,
                                  value: '$contentCount',
                                  subtitle: strings.contentSubtitle,
                                  icon: Icons.inventory_2_outlined,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: _DashboardOverviewCard(
                                  title: strings.availableTokensTitle,
                                  value: _formatTokens(remainingTokens),
                                  subtitle: strings.availableTokensSubtitle,
                                  icon: Icons.generating_tokens_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _InteractionChartCard(
                            summary: summary,
                            strings: strings,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _DashboardOverviewCard(
                        title: strings.contentTitle,
                        value: '$contentCount',
                        subtitle: strings.contentSubtitle,
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(height: 14),
                      _DashboardOverviewCard(
                        title: strings.availableTokensTitle,
                        value: _formatTokens(remainingTokens),
                        subtitle: strings.availableTokensSubtitle,
                        icon: Icons.generating_tokens_outlined,
                      ),
                      const SizedBox(height: 14),
                      _InteractionChartCard(summary: summary, strings: strings),
                    ],
                  ),
            const SizedBox(height: 18),
            _UsersStatusTableCard(
              usersRepository: usersRepository,
              strings: strings,
            ),
          ],
        );
      },
    );
  }

  String _formatTokens(int value) {
    final safeValue = value < 0 ? 0 : value;
    if (safeValue >= 1000) {
      return '${(safeValue / 1000).toStringAsFixed(2)}K';
    }
    return '$safeValue';
  }
}

class _ResponsiveHomeRow extends StatelessWidget {
  const _ResponsiveHomeRow({required this.isWide, required this.children});

  final bool isWide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: children[index]),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 18),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

class _DashboardHomeTitle extends StatelessWidget {
  const _DashboardHomeTitle({required this.access, required this.strings});

  final AdminDashboardAccess access;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.isArabic ? 'لوحة الإدارة' : strings.dashboardTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B1F2A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.isArabic
                    ? 'مرحبًا ${access.name}'
                    : strings.welcomeMessage(access.name),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7B8494),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF2)),
          ),
          child: Text(
            adminDashboardRoleLabel(access.role),
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardOverviewCard extends StatelessWidget {
  const _DashboardOverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _DashboardBlueIcon(icon: icon),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: Color(0xFFB5BECF)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8A94A6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF151A24),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFA2ABBA),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersBreakdownCard extends StatelessWidget {
  const _UsersBreakdownCard({required this.summary, required this.strings});

  final AdminDashboardSummary summary;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _DashboardBlueIcon(icon: Icons.groups_2_outlined),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: Color(0xFFB5BECF)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              strings.usersBreakdownTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8A94A6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniUserStat(
                    label: strings.allUsers,
                    value: '${summary.totalUsers}',
                    color: const Color(0xFF2563EB),
                  ),
                ),
                Expanded(
                  child: _MiniUserStat(
                    label: strings.bannedUsers,
                    value: '${summary.blockedUsers}',
                    color: const Color(0xFFEF4444),
                  ),
                ),
                Expanded(
                  child: _MiniUserStat(
                    label: strings.activeNow,
                    value: '${summary.activeUsersToday}',
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniUserStat extends StatelessWidget {
  const _MiniUserStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9AA3B4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InteractionChartCard extends StatelessWidget {
  const _InteractionChartCard({required this.summary, required this.strings});

  final AdminDashboardSummary summary;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final values = _buildValues();
    final theme = Theme.of(context);

    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _DashboardBlueIcon(icon: Icons.query_stats_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.interactionChartTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1B1F2A),
                    ),
                  ),
                ),
                Text(
                  strings.thisMonth,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CustomPaint(painter: _InteractionChartPainter(values)),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _buildValues() {
    final raw = [
      summary.activeUsersToday,
      summary.activeUsersLast7Days,
      summary.premiumUsers,
      summary.totalUsers,
      summary.totalStoreItems,
      summary.totalPrayerPoints,
    ];
    final maxValue = raw.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (maxValue == 0) {
      return raw.map((_) => 0.0).toList(growable: false);
    }
    return raw
        .map((value) => (value / maxValue).clamp(0.0, 0.94).toDouble())
        .toList(growable: false);
  }
}

class _InteractionChartPainter extends CustomPainter {
  const _InteractionChartPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEF6)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1 ? 0 : size.width * i / (values.length - 1),
          size.height - (size.height * values[i]),
        ),
    ];

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x662563EB), Color(0x002563EB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middleX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        middleX,
        previous.dy,
        middleX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas.drawCircle(point, 6, dotPaint);
      canvas.drawCircle(point, 6, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InteractionChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _UsersStatusTableCard extends StatelessWidget {
  const _UsersStatusTableCard({
    required this.usersRepository,
    required this.strings,
  });

  final FirestoreAdminUsersRepository usersRepository;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _DashboardBlueIcon(icon: Icons.manage_accounts_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.usersStatusTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1B1F2A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            StreamBuilder<List<AdminUserSummary>>(
              stream: usersRepository.watchUsers(limit: 8),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final users = [...snapshot.data!]
                  ..sort((left, right) {
                    final leftDate = left.lastLoginAt ?? left.updatedAt;
                    final rightDate = right.lastLoginAt ?? right.updatedAt;
                    if (leftDate != null && rightDate != null) {
                      return rightDate.compareTo(leftDate);
                    }
                    return left.displayName.compareTo(right.displayName);
                  });
                if (users.isEmpty) {
                  return Text(
                    strings.isArabic
                        ? 'لا يوجد مستخدمون بعد.'
                        : 'No users yet.',
                  );
                }
                return Column(
                  children: [
                    for (final user in users)
                      _UsersStatusRow(
                        user: user,
                        strings: strings,
                        formatDate: _formatDate,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return strings.isArabic ? 'غير متاح' : 'Not available';
    }
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _UsersStatusRow extends StatelessWidget {
  const _UsersStatusRow({
    required this.user,
    required this.strings,
    required this.formatDate,
  });

  final AdminUserSummary user;
  final _HomeStrings strings;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = !user.isBlocked
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              user.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SelectableText(
              user.uid,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              formatDate(user.lastLoginAt ?? user.updatedAt),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.isBlocked ? strings.bannedStatus : strings.activeStatus,
              style: theme.textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBlueIcon extends StatelessWidget {
  const _DashboardBlueIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
    );
  }
}

class _AdminDashboardHomeBody extends StatelessWidget {
  const _AdminDashboardHomeBody({
    required this.access,
    required this.summary,
    required this.auditLogRepository,
    required this.runningAction,
    required this.maintenanceStatus,
    required this.onMaintenanceAction,
    required this.strings,
  });

  final AdminDashboardAccess access;
  final AdminDashboardSummary summary;
  final FirestoreAdminAuditLogRepository auditLogRepository;
  final _MaintenanceAction? runningAction;
  final _MaintenanceStatus? maintenanceStatus;
  final Future<void> Function(_MaintenanceAction action) onMaintenanceAction;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final destinations = buildAdminDashboardDestinations(context, access)
        .where(
          (destination) =>
              destination.route != AppRouter.adminDashboardHomeRoute,
        )
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroCard(access: access, strings: strings),
        const SizedBox(height: 24),
        Text(
          strings.quickSummaryTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AdminDashboardGridWrap(
          children: [
            _MetricCard(
              title: strings.totalUsersLabel,
              value: '${summary.totalUsers}',
              icon: Icons.people_alt_outlined,
            ),
            _MetricCard(
              title: 'نشط اليوم',
              value: '${summary.activeUsersToday}',
              icon: Icons.today_outlined,
            ),
            _MetricCard(
              title: 'نشط آخر 7 أيام',
              value: '${summary.activeUsersLast7Days}',
              icon: Icons.trending_up_rounded,
            ),
            _MetricCard(
              title: 'مشتركون',
              value: '${summary.premiumUsers}',
              icon: Icons.workspace_premium_outlined,
            ),
            _MetricCard(
              title: 'محظورون',
              value: '${summary.blockedUsers}',
              icon: Icons.block_outlined,
            ),
            _MetricCard(
              title: 'أدمن',
              value: '${summary.adminUsers}',
              icon: Icons.admin_panel_settings_outlined,
            ),
            _MetricCard(
              title: 'حد AI مخصص',
              value: '${summary.usersWithAiLimitOverride}',
              icon: Icons.smart_toy_outlined,
            ),
            _MetricCard(
              title: 'نقاط الصلاة',
              value: '${summary.totalPrayerPoints}',
              icon: Icons.insights_outlined,
            ),
            _MetricCard(
              title: strings.totalDhikrCategoriesLabel,
              value: '${summary.totalDhikrCategories}',
              icon: Icons.auto_stories_outlined,
            ),
            _MetricCard(
              title: strings.totalDuasLabel,
              value: '${summary.totalDuas}',
              icon: Icons.menu_book_outlined,
            ),
            _MetricCard(
              title: strings.totalStoreItemsLabel,
              value: '${summary.totalStoreItems}',
              icon: Icons.storefront_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SystemHealthSection(strings: strings),
        const SizedBox(height: 24),
        _RecentAuditLogSection(repository: auditLogRepository),
        if (access.isPrimaryAdministrator && !access.isLocalMode) ...[
          const SizedBox(height: 28),
          _MaintenanceActionsSection(
            runningAction: runningAction,
            maintenanceStatus: maintenanceStatus,
            onMaintenanceAction: onMaintenanceAction,
            strings: strings,
          ),
        ],
        const SizedBox(height: 28),
        Text(
          strings.adminPagesTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AdminDashboardGridWrap(
          children: destinations
              .map(
                (destination) =>
                    _SectionCard(destination: destination, strings: strings),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.access, required this.strings});

  final AdminDashboardAccess access;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.welcomeMessage(access.name),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(strings.heroDescription, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(adminDashboardRoleLabel(access.role))),
              Chip(label: Text(access.email ?? 'Admin')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 240,
      child: AdminDashboardSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemHealthSection extends StatelessWidget {
  const _SystemHealthSection({required this.strings});

  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checks = [
      const _SystemHealthCheck(
        label: 'Firestore',
        description: 'قراءة البيانات الحية',
        status: _SystemHealthStatus.ready,
        icon: Icons.cloud_done_outlined,
      ),
      const _SystemHealthCheck(
        label: 'قواعد الأمان',
        description: 'تحتاج مراجعة قبل النشر',
        status: _SystemHealthStatus.warning,
        icon: Icons.security_outlined,
      ),
      const _SystemHealthCheck(
        label: 'الشراء',
        description: 'ينتظر تحقق الخادم',
        status: _SystemHealthStatus.warning,
        icon: Icons.verified_user_outlined,
      ),
      const _SystemHealthCheck(
        label: 'App Check',
        description: 'تفعيل من Firebase Console',
        status: _SystemHealthStatus.pending,
        icon: Icons.app_blocking_outlined,
      ),
    ];

    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'صحة النظام',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(strings.systemHealthReviewChip)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: checks
                  .map((check) => _SystemHealthTile(check: check))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SystemHealthStatus { ready, warning, pending }

class _SystemHealthCheck {
  const _SystemHealthCheck({
    required this.label,
    required this.description,
    required this.status,
    required this.icon,
  });

  final String label;
  final String description;
  final _SystemHealthStatus status;
  final IconData icon;
}

class _SystemHealthTile extends StatelessWidget {
  const _SystemHealthTile({required this.check});

  final _SystemHealthCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (check.status) {
      _SystemHealthStatus.ready => const Color(0xFF1F9D62),
      _SystemHealthStatus.warning => const Color(0xFFF5A524),
      _SystemHealthStatus.pending => theme.colorScheme.outline,
    };

    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(check.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    check.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAuditLogSection extends StatelessWidget {
  const _RecentAuditLogSection({required this.repository});

  final FirestoreAdminAuditLogRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDashboardSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'آخر عمليات الإدارة',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Chip(label: Text('20')),
              ],
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<AdminAuditLogEntry>>(
              stream: repository.watchRecentLogs(limit: 20),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(mapAppErrorToArabic(snapshot.error!));
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final logs = snapshot.data!;
                if (logs.isEmpty) {
                  return const Text('لا توجد عمليات إدارية مسجلة بعد.');
                }
                return Column(
                  children: logs
                      .map((entry) => _AuditLogTile(entry: entry))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AdminAuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = entry.createdAt;
    final timeLabel = createdAt == null
        ? 'وقت غير معروف'
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.targetId.isEmpty ? entry.adminId : entry.targetId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeLabel,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceActionsSection extends StatelessWidget {
  const _MaintenanceActionsSection({
    required this.runningAction,
    required this.maintenanceStatus,
    required this.onMaintenanceAction,
    required this.strings,
  });

  final _MaintenanceAction? runningAction;
  final _MaintenanceStatus? maintenanceStatus;
  final Future<void> Function(_MaintenanceAction action) onMaintenanceAction;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final actions = _MaintenanceAction.values;
    final isBusy = runningAction != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.maintenanceTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          strings.maintenanceDescription,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (maintenanceStatus != null) ...[
          const SizedBox(height: 16),
          _MaintenanceStatusCard(status: maintenanceStatus!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: actions
              .map((action) {
                return _MaintenanceActionCard(
                  action: action,
                  strings: strings,
                  isRunning: runningAction == action,
                  isDisabled: isBusy,
                  onPressed: () => onMaintenanceAction(action),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _MaintenanceActionCard extends StatelessWidget {
  const _MaintenanceActionCard({
    required this.action,
    required this.strings,
    required this.isRunning,
    required this.isDisabled,
    required this.onPressed,
  });

  final _MaintenanceAction action;
  final _HomeStrings strings;
  final bool isRunning;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = action.accentColor(theme);

    return SizedBox(
      width: 320,
      child: AdminDashboardSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(action.icon, color: accentColor),
              ),
              const SizedBox(height: 16),
              Text(
                action.title(strings),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.subtitle(strings),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (isRunning) ...[
                LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  color: accentColor,
                ),
                const SizedBox(height: 10),
                Text(
                  action.runningMessage(strings),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isDisabled ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: Icon(
                    isRunning ? Icons.hourglass_top_rounded : action.icon,
                  ),
                  label: Text(action.buttonLabel(strings)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceStatusCard extends StatelessWidget {
  const _MaintenanceStatusCard({required this.status});

  final _MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = status.tone.resolve(theme);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(status.icon, color: colors.icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(status.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.destination, required this.strings});

  final AdminDashboardDestination destination;
  final _HomeStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 280,
      child: AdminDashboardSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(destination.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 14),
              Text(
                destination.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(destination.subtitle),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  navigateToAdminDashboardRoute(
                    context,
                    currentRoute: AppRouter.adminDashboardHomeRoute,
                    targetRoute: destination.route,
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(strings.openPage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withAlpha(32)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HomeStateCard extends StatelessWidget {
  const _HomeStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _SurfaceCard(
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

enum _MaintenanceAction { systemSync, resetAiUsage, rebuildPermissionsCache }

extension _MaintenanceActionX on _MaintenanceAction {
  IconData get icon {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return Icons.sync_rounded;
      case _MaintenanceAction.resetAiUsage:
        return Icons.restart_alt_rounded;
      case _MaintenanceAction.rebuildPermissionsCache:
        return Icons.admin_panel_settings_outlined;
    }
  }

  Color accentColor(ThemeData theme) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return theme.colorScheme.primary;
      case _MaintenanceAction.resetAiUsage:
        return const Color(0xFF0A7C66);
      case _MaintenanceAction.rebuildPermissionsCache:
        return const Color(0xFF8B5CF6);
    }
  }

  String title(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncTitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageTitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsTitle;
    }
  }

  String subtitle(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncSubtitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageSubtitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsSubtitle;
    }
  }

  String buttonLabel(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncButton;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageButton;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsButton;
    }
  }

  String confirmationTitle(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncConfirmTitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageConfirmTitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsConfirmTitle;
    }
  }

  String confirmationMessage(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncConfirmMessage;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageConfirmMessage;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsConfirmMessage;
    }
  }

  String confirmationButton(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncButton;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageButton;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsButton;
    }
  }

  String runningTitle(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncRunningTitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageRunningTitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsRunningTitle;
    }
  }

  String runningMessage(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncRunningMessage;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageRunningMessage;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsRunningMessage;
    }
  }

  String successTitle(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncSuccessTitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageSuccessTitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsSuccessTitle;
    }
  }

  String failureTitle(_HomeStrings strings) {
    switch (this) {
      case _MaintenanceAction.systemSync:
        return strings.systemSyncFailureTitle;
      case _MaintenanceAction.resetAiUsage:
        return strings.resetAiUsageFailureTitle;
      case _MaintenanceAction.rebuildPermissionsCache:
        return strings.rebuildPermissionsFailureTitle;
    }
  }
}

class _MaintenanceStatus {
  const _MaintenanceStatus({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final _MaintenanceTone tone;
}

enum _MaintenanceTone { inProgress, success, error }

class _MaintenanceColors {
  const _MaintenanceColors({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color icon;
}

extension _MaintenanceToneX on _MaintenanceTone {
  _MaintenanceColors resolve(ThemeData theme) {
    switch (this) {
      case _MaintenanceTone.inProgress:
        return _MaintenanceColors(
          background: theme.colorScheme.primaryContainer.withAlpha(120),
          border: theme.colorScheme.primary.withAlpha(40),
          iconBackground: theme.colorScheme.primary.withAlpha(20),
          icon: theme.colorScheme.primary,
        );
      case _MaintenanceTone.success:
        return const _MaintenanceColors(
          background: Color(0xFFE7F7EF),
          border: Color(0xFFB6E2C8),
          iconBackground: Color(0xFFD5F2E0),
          icon: Color(0xFF0A7C66),
        );
      case _MaintenanceTone.error:
        return const _MaintenanceColors(
          background: Color(0xFFFFF0F0),
          border: Color(0xFFFFD0D0),
          iconBackground: Color(0xFFFFE2E2),
          icon: Color(0xFFC62828),
        );
    }
  }
}

class _HomeStrings {
  const _HomeStrings._({required this.isArabic});

  factory _HomeStrings.of(BuildContext context) {
    final isArabic = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ar');
    return _HomeStrings._(isArabic: isArabic);
  }

  final bool isArabic;

  String get dashboardTitle => isArabic ? 'لوحة الإدارة' : 'Admin Dashboard';
  String get summaryLoadFailureTitle =>
      isArabic ? 'تعذر تحميل الإحصاءات' : 'Unable to load summary';
  String get quickSummaryTitle => isArabic ? 'ملخص سريع' : 'Quick Summary';
  String get totalUsersLabel => isArabic ? 'إجمالي المستخدمين' : 'Total users';
  String get totalDhikrCategoriesLabel =>
      isArabic ? 'أقسام الأذكار' : 'Dhikr categories';
  String get totalDuasLabel => isArabic ? 'إجمالي الأدعية' : 'Total duas';
  String get totalStoreItemsLabel => isArabic ? 'عناصر المتجر' : 'Store items';
  String get adminPagesTitle => isArabic ? 'صفحات الإدارة' : 'Admin Pages';
  String get totalMoneyTitle => isArabic ? 'إجمالي الأموال' : 'Total revenue';
  String get subscriptionRevenueSubtitle =>
      isArabic ? 'إيرادات الاشتراكات داخل النظام' : 'Subscription revenue';
  String get subscribedUsersTitle =>
      isArabic ? 'المستخدمون المشتركون' : 'Subscribed users';
  String get subscribedUsersSubtitle =>
      isArabic ? 'إجمالي الحسابات المشتركة' : 'Total subscribed accounts';
  String get usersBreakdownTitle => isArabic ? 'المستخدمون' : 'Users breakdown';
  String get allUsers => isArabic ? 'الإجمالي' : 'Total';
  String get bannedUsers => isArabic ? 'المحظورون' : 'Banned';
  String get activeNow => isArabic ? 'النشطون الآن' : 'Active now';
  String get contentTitle => isArabic ? 'إجمالي المحتوى' : 'Total content';
  String get contentSubtitle => isArabic
      ? 'أذكار وأدعية ومنتجات محفوظة'
      : 'Saved azkar, duas, and products';
  String get availableTokensTitle =>
      isArabic ? 'التوكن المتاح' : 'Available tokens';
  String get availableTokensSubtitle => isArabic
      ? 'حد شهري لا يجب تجاوزه مع إجمالي المستخدمين'
      : 'Monthly cap before user growth exceeds the plan';
  String get interactionChartTitle =>
      isArabic ? 'تفاعل المستخدمين' : 'User interaction';
  String get thisMonth => isArabic ? 'لقطة حالية' : 'Current snapshot';
  String get usersStatusTitle =>
      isArabic ? 'المستخدمون وحالة الحساب' : 'Users and account status';
  String get activeStatus => isArabic ? 'نشط' : 'Active';
  String get subscribedStatus => isArabic ? 'مشترك' : 'Subscribed';
  String get bannedStatus => isArabic ? 'محظور' : 'Banned';
  String get onlineStatus => isArabic ? 'متصل' : 'Online';

  String get maintenanceTitle =>
      isArabic ? 'أدوات الصيانة الحرجة' : 'Critical Maintenance Tools';
  String get maintenanceDescription => isArabic
      ? 'أوامر صيانة متقدمة للحساب الإداري الأعلى فقط.'
      : 'Advanced maintenance tools for the highest-access admin account only.';
  String get openPage => isArabic ? 'فتح الصفحة' : 'Open Page';
  String get systemHealthReviewChip =>
      isArabic ? 'مراجعة النظام' : 'System review';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String welcomeMessage(String name) =>
      isArabic ? 'مرحبًا $name' : 'Welcome, $name';
  String get heroDescription => isArabic
      ? 'من هنا يمكنك مراجعة المؤشرات بسرعة، ثم الانتقال إلى إدارة المستخدمين، الاشتراكات، اللغات، المحتوى، المتجر، واستهلاك الذكاء الاصطناعي.'
      : 'This is the modern entry point for the admin dashboard. From here you can review key signals quickly, then move into users, subscriptions, languages, content, store, and AI usage management.';

  String get systemSyncTitle => isArabic ? 'System Sync' : 'System Sync';
  String get systemSyncSubtitle => isArabic
      ? 'مزامنة الإعدادات الافتراضية، الخطط، الأدوار، وإكمال الحقول الناقصة للمستخدمين.'
      : 'Sync default settings, plans, roles, and fill missing user schema fields.';
  String get systemSyncButton =>
      isArabic ? 'تشغيل المزامنة' : 'Run System Sync';
  String get systemSyncConfirmTitle =>
      isArabic ? 'تأكيد System Sync' : 'Confirm System Sync';
  String get systemSyncConfirmMessage => isArabic
      ? 'سيتم فحص الإعدادات العامة والخطط والأدوار وملفات المستخدمين. هل تريد المتابعة؟'
      : 'Settings, plans, roles, and user profiles will be checked and synchronized. Continue?';
  String get systemSyncRunningTitle =>
      isArabic ? 'System Sync قيد التشغيل' : 'System Sync is running';
  String get systemSyncRunningMessage => isArabic
      ? 'يتم الآن مزامنة الإعدادات والخطط والأدوار، ثم تحديث بيانات المستخدمين الناقصة.'
      : 'Settings, plans, and roles are being synchronized, then missing user fields are being repaired.';
  String get systemSyncSuccessTitle =>
      isArabic ? 'اكتملت المزامنة' : 'System Sync completed';
  String get systemSyncFailureTitle =>
      isArabic ? 'فشلت المزامنة' : 'System Sync failed';
  String systemSyncSuccess({required int usersUpdated}) => isArabic
      ? 'اكتملت مزامنة النظام بنجاح. تم تحديث $usersUpdated ملف مستخدم.'
      : 'System sync completed successfully. Updated $usersUpdated user profiles.';

  String get resetAiUsageTitle =>
      isArabic ? 'Reset AI Usage' : 'Reset AI Usage';
  String get resetAiUsageSubtitle => isArabic
      ? 'إعادة ضبط الاستهلاك اليومي للذكاء الاصطناعي لكل المستخدمين مع حفظ تاريخ إعادة الضبط.'
      : 'Reset daily AI usage for all users and store a fresh reset date.';
  String get resetAiUsageButton =>
      isArabic ? 'إعادة ضبط الاستخدام' : 'Reset Usage';
  String get resetAiUsageConfirmTitle =>
      isArabic ? 'تأكيد Reset AI Usage' : 'Confirm Reset AI Usage';
  String get resetAiUsageConfirmMessage => isArabic
      ? 'سيتم تعيين usedToday = 0 لكل المستخدمين داخل usage/ai. هل تريد المتابعة؟'
      : 'Every user usage/ai document will be reset with usedToday = 0. Continue?';
  String get resetAiUsageRunningTitle =>
      isArabic ? 'Reset AI Usage قيد التشغيل' : 'Reset AI Usage is running';
  String get resetAiUsageRunningMessage => isArabic
      ? 'يتم الآن تصفير العدادات اليومية لكل المستخدمين وتحديث تاريخ إعادة الضبط.'
      : 'Daily AI counters are being reset for all users and the reset date is being refreshed.';
  String get resetAiUsageSuccessTitle =>
      isArabic ? 'اكتملت إعادة الضبط' : 'AI Usage reset completed';
  String get resetAiUsageFailureTitle =>
      isArabic ? 'فشلت إعادة الضبط' : 'AI Usage reset failed';
  String resetAiUsageSuccess({required int affectedUsers}) => isArabic
      ? 'تمت إعادة ضبط استخدام الذكاء الاصطناعي بنجاح لعدد $affectedUsers مستخدم.'
      : 'AI usage was reset successfully for $affectedUsers users.';

  String get rebuildPermissionsTitle =>
      isArabic ? 'Rebuild Permissions Cache' : 'Rebuild Permissions Cache';
  String get rebuildPermissionsSubtitle => isArabic
      ? 'إعادة توحيد permissions المخزنة، إصلاح القيم الناقصة، وتطبيق صلاحيات admin الافتراضية عند الحاجة.'
      : 'Normalize stored permissions, fix missing values, and apply default admin permissions where needed.';
  String get rebuildPermissionsButton =>
      isArabic ? 'إعادة بناء الصلاحيات' : 'Rebuild Permissions';
  String get rebuildPermissionsConfirmTitle => isArabic
      ? 'تأكيد Rebuild Permissions Cache'
      : 'Confirm Rebuild Permissions Cache';
  String get rebuildPermissionsConfirmMessage => isArabic
      ? 'سيتم فحص جميع المستخدمين وإعادة بناء permissions المخزنة لهم بشكل آمن بدون المساس بوصول superAdmin. هل تريد المتابعة؟'
      : 'All users will be scanned and their stored permissions will be rebuilt safely without affecting superAdmin access. Continue?';
  String get rebuildPermissionsRunningTitle => isArabic
      ? 'Rebuild Permissions Cache قيد التشغيل'
      : 'Permissions cache rebuild is running';
  String get rebuildPermissionsRunningMessage => isArabic
      ? 'يتم الآن إصلاح الحقول الناقصة ثم إعادة توحيد الصلاحيات المخزنة حسب الدور.'
      : 'Missing user fields are being repaired, then stored permissions are being normalized by role.';
  String get rebuildPermissionsSuccessTitle =>
      isArabic ? 'اكتملت إعادة البناء' : 'Permissions cache rebuilt';
  String get rebuildPermissionsFailureTitle =>
      isArabic ? 'فشلت إعادة البناء' : 'Permissions cache rebuild failed';
  String rebuildPermissionsSuccess({
    required int backfilledUsers,
    required int permissionsUpdated,
  }) {
    if (isArabic) {
      return 'اكتملت إعادة بناء الصلاحيات. تم استكمال $backfilledUsers مستخدم وتحديث صلاحيات $permissionsUpdated مستخدم.';
    }
    return 'Permissions cache rebuilt. Backfilled $backfilledUsers users and updated permissions for $permissionsUpdated users.';
  }
}
