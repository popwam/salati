import 'package:flutter/material.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../islamic_ai/data/islamic_ai_api_client.dart';
import '../../islamic_ai/models/islamic_chat_response.dart';
import '../data/firestore_admin_ai_usage_repository.dart';
import '../data/firestore_admin_dashboard_access_repository.dart';
import '../models/admin_ai_usage_entry.dart';
import '../models/admin_dashboard_access.dart';
import 'admin_dashboard_guard.dart';
import 'admin_dashboard_localization.dart';
import 'admin_dashboard_scaffold.dart';
import 'admin_dashboard_ui.dart';

class AdminAiUsageManagementScreen extends StatefulWidget {
  const AdminAiUsageManagementScreen({
    super.key,
    required this.services,
    required this.firebaseConfigured,
  });

  final AppServices services;
  final bool firebaseConfigured;

  @override
  State<AdminAiUsageManagementScreen> createState() =>
      _AdminAiUsageManagementScreenState();
}

class _AdminAiUsageManagementScreenState
    extends State<AdminAiUsageManagementScreen> {
  late final FirestoreAdminDashboardAccessRepository _accessRepository;
  late final FirestoreAdminAiUsageRepository _aiUsageRepository;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ValueNotifier<String> _searchQueryNotifier;

  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _accessRepository = FirestoreAdminDashboardAccessRepository(
      authService: widget.services.authService,
      firebaseConfigured: widget.firebaseConfigured,
    );
    _aiUsageRepository = FirestoreAdminAiUsageRepository(
      firebaseConfigured: widget.firebaseConfigured,
    );
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'adminAiUsageSearch');
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

  List<AdminAiUsageEntry> _filterEntries(
    List<AdminAiUsageEntry> entries,
    String query,
  ) {
    return entries
        .where((entry) => entry.matchesQuery(query))
        .toList(growable: false);
  }

  bool _canManageTarget(AdminDashboardAccess access, AdminAiUsageEntry entry) {
    if (access.role == AdminDashboardRole.superAdmin) return true;
    return entry.role != AdminDashboardRole.superAdmin;
  }

  Future<void> _openEditor(AdminAiUsageEntry entry) async {
    final result = await showDialog<_AiUsageDialogResult>(
      context: context,
      builder: (context) => _AiUsageDialog(entry: entry),
    );

    if (result == null) return;

    setState(() => _busyUserId = entry.uid);

    try {
      await _aiUsageRepository.updateEntry(
        uid: entry.uid,
        aiUsageLimitOverride: result.aiUsageLimitOverride,
        clearAiUsageLimitOverride: result.clearAiUsageLimitOverride,
        usedToday: result.usedToday,
        dailyLimit: result.dailyLimit,
        resetDate: result.resetDate,
      );

      if (!mounted) return;

      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تم تحديث استخدام الذكاء الاصطناعي.',
          en: 'AI usage updated.',
          fr: 'Utilisation IA mise a jour.',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _resetUsage(AdminAiUsageEntry entry) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            adminDashText(
              context,
              ar: 'إعادة ضبط الاستخدام',
              en: 'Reset usage',
              fr: 'Reinitialiser l usage',
            ),
          ),
          content: Text(
            adminDashText(
              context,
              ar: 'سيتم ضبط استخدام ${entry.displayName} إلى 0 مع تحديث تاريخ إعادة الضبط. هل تريد المتابعة؟',
              en: 'Used today for ${entry.displayName} will be reset to 0 and the reset date will be refreshed. Continue?',
              fr: 'L usage de ${entry.displayName} sera remis a 0 et la date sera actualisee. Continuer ?',
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
                  ar: 'متابعة',
                  en: 'Continue',
                  fr: 'Continuer',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) return;

    setState(() => _busyUserId = entry.uid);

    try {
      await _aiUsageRepository.resetUsage(uid: entry.uid);

      if (!mounted) return;

      showAdminDashboardSnackBar(
        context,
        message: adminDashText(
          context,
          ar: 'تمت إعادة الضبط للمستخدم ${entry.displayName}.',
          en: 'Usage reset for ${entry.displayName}.',
          fr: 'Reinitialisation effectuee pour ${entry.displayName}.',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      showAdminDashboardSnackBar(
        context,
        message: mapAppErrorToArabic(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
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
            ar: 'استخدام الذكاء الاصطناعي',
            en: 'AI Usage',
            fr: 'Utilisation IA',
          ),
          currentRoute: AppRouter.adminDashboardAiUsageRoute,
          access: access,
          services: widget.services,
          child: StreamBuilder<List<AdminAiUsageEntry>>(
            stream: _aiUsageRepository.watchEntries(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _AiUsageStateCard(
                  title: adminDashText(
                    context,
                    ar: 'تعذر تحميل بيانات الاستخدام',
                    en: 'Unable to load AI usage',
                    fr: 'Impossible de charger l utilisation IA',
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
                  final entries = _filterEntries(snapshot.data!, query);
                  final summary = _AiUsageSummary.fromEntries(entries);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1180;
                      final metricWidth = constraints.maxWidth >= 1180
                          ? (constraints.maxWidth - 48) / 4
                          : constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _AiUsageToolbar(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              searchQueryListenable: _searchQueryNotifier,
                              resultCount: entries.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverToBoxAdapter(
                            child: AdminDashboardGridWrap(
                              children: [
                                _MetricBox(
                                  width: metricWidth,
                                  label: adminDashText(
                                    context,
                                    ar: 'الحسابات المعروضة',
                                    en: 'Visible accounts',
                                    fr: 'Comptes visibles',
                                  ),
                                  value: '${summary.totalUsers}',
                                  icon: Icons.groups_outlined,
                                ),
                                _MetricBox(
                                  width: metricWidth,
                                  label: adminDashText(
                                    context,
                                    ar: 'إجمالي الاستخدام اليوم',
                                    en: 'Total used today',
                                    fr: 'Usage total du jour',
                                  ),
                                  value: '${summary.totalUsedToday}',
                                  icon: Icons.auto_awesome_outlined,
                                  tint: Colors.indigo,
                                ),
                                _MetricBox(
                                  width: metricWidth,
                                  label: adminDashText(
                                    context,
                                    ar: 'حدود مخصصة',
                                    en: 'Custom overrides',
                                    fr: 'Limites personnalisees',
                                  ),
                                  value: '${summary.overrideCount}',
                                  icon: Icons.tune_outlined,
                                  tint: Colors.deepOrange,
                                ),
                                _MetricBox(
                                  width: metricWidth,
                                  label: adminDashText(
                                    context,
                                    ar: 'حسابات محظورة',
                                    en: 'Blocked accounts',
                                    fr: 'Comptes bloques',
                                  ),
                                  value: '${summary.blockedCount}',
                                  icon: Icons.block_outlined,
                                  tint: Colors.red,
                                ),
                              ],
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverToBoxAdapter(
                            child: _AiSandboxCard(services: widget.services),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverToBoxAdapter(
                            child: entries.isEmpty
                                ? _AiUsageStateCard(
                                    title: adminDashText(
                                      context,
                                      ar: 'لا توجد نتائج',
                                      en: 'No results',
                                      fr: 'Aucun resultat',
                                    ),
                                    message: adminDashText(
                                      context,
                                      ar: 'جرّب تعديل البحث.',
                                      en: 'Try refining the search.',
                                      fr: 'Essayez d affiner la recherche.',
                                    ),
                                  )
                                : isWide
                                ? _AiUsageTable(
                                    entries: entries,
                                    access: access,
                                    busyUserId: _busyUserId,
                                    canManageTarget: _canManageTarget,
                                    onEdit: _openEditor,
                                    onReset: _resetUsage,
                                  )
                                : _AiUsageCards(
                                    entries: entries,
                                    access: access,
                                    busyUserId: _busyUserId,
                                    canManageTarget: _canManageTarget,
                                    onEdit: _openEditor,
                                    onReset: _resetUsage,
                                  ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.clamp(260.0, 320.0).toDouble(),
      child: AdminDashboardMetricCard(
        label: label,
        value: value,
        icon: icon,
        tint: tint,
      ),
    );
  }
}

class _AiUsageToolbar extends StatelessWidget {
  const _AiUsageToolbar({
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
                    ar: 'ابحث بالاسم أو البريد أو المعرّف',
                    en: 'Search by name, email, or uid',
                    fr: 'Recherche par nom, e-mail ou identifiant',
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

class _AiSandboxCard extends StatefulWidget {
  const _AiSandboxCard({required this.services});

  final AppServices services;

  @override
  State<_AiSandboxCard> createState() => _AiSandboxCardState();
}

class _AiSandboxCardState extends State<_AiSandboxCard> {
  static const _planIds = <String>['free', 'pro', 'plus'];

  late final IslamicAiApiClient _apiClient;
  late final TextEditingController _promptController;
  late final TextEditingController _overrideController;
  late final TextEditingController _usedTodayController;
  late final TextEditingController _requestCostController;

  String _planId = 'free';
  bool _isTesting = false;
  String? _apiAnswer;
  String? _apiError;
  bool? _apiCached;
  int? _apiCardCount;
  List<_AiApiCardPreview> _apiCards = const [];
  bool _isTestingHealth = false;
  BackendHealth? _health;
  String? _healthError;
  int get _planLimit {
    switch (_planId) {
      case 'plus':
        return 100;
      case 'pro':
        return 50;
      default:
        return 5;
    }
  }

  @override
  void initState() {
    super.initState();
    _apiClient = IslamicAiApiClient();
    _promptController = TextEditingController(
      text: 'اشرح حديث إنما الأعمال بالنيات ببساطة',
    );
    _overrideController = TextEditingController();
    _usedTodayController = TextEditingController(text: '0');
    _requestCostController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _apiClient.close();
    _promptController.dispose();
    _overrideController.dispose();
    _usedTodayController.dispose();
    _requestCostController.dispose();
    super.dispose();
  }

  void _refreshQuotaPreview() {
    setState(() {});
  }

  Future<void> _testBackendHealth() async {
    setState(() {
      _isTestingHealth = true;
      _health = null;
      _healthError = null;
    });

    try {
      final health = await _apiClient.health();
      if (!mounted) return;
      setState(() => _health = health);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _healthError = error is IslamicAiApiException
            ? error.message
            : mapAppErrorToArabic(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isTestingHealth = false);
      }
    }
  }

  Future<void> _sendRealAiTest() async {
    final prompt = _promptController.text.trim();
    final requestCost = int.tryParse(_requestCostController.text.trim()) ?? 0;
    final usedToday = int.tryParse(_usedTodayController.text.trim()) ?? 0;
    final override = int.tryParse(_overrideController.text.trim());
    final effectiveLimit = override ?? _planLimit;
    final remainingBefore = effectiveLimit - usedToday;

    if (prompt.isEmpty) {
      setState(() {
        _apiError = adminDashText(
          context,
          ar: 'اكتب رسالة اختبار أولاً.',
          en: 'Write a test prompt first.',
          fr: 'Ecrivez d abord un prompt de test.',
        );
        _apiAnswer = null;
        _apiCards = const [];
      });
      return;
    }

    if (requestCost <= 0) {
      setState(() {
        _apiError = adminDashText(
          context,
          ar: 'تكلفة الطلب يجب أن تكون أكبر من 0.',
          en: 'Request cost must be greater than 0.',
          fr: 'Le cout doit etre superieur a 0.',
        );
        _apiAnswer = null;
        _apiCards = const [];
      });
      return;
    }

    if (remainingBefore < requestCost) {
      setState(() {
        _apiError = adminDashText(
          context,
          ar: 'لا يمكن إرسال الطلب لأن الحد اليومي لا يسمح بذلك.',
          en: 'Cannot send because the daily quota does not allow it.',
          fr: 'Impossible d envoyer car le quota journalier ne le permet pas.',
        );
        _apiAnswer = null;
        _apiCards = const [];
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _apiError = null;
      _apiAnswer = null;
      _apiCached = null;
      _apiCardCount = null;
      _apiCards = const [];
    });

    try {
      final response = await _apiClient.sendMessage(
        prompt,
        userId:
            widget.services.authService.currentSession?.uid ?? 'anonymous-user',
      );

      if (!mounted) return;

      if (response.hasError) {
        setState(() {
          _apiError = response.errorMessage;
          _apiCards = const [];
        });
        return;
      }

      final nextUsedToday = usedToday + requestCost;
      setState(() {
        _usedTodayController.text = '$nextUsedToday';
        _apiAnswer = response.answer;
        _apiCached = false;
        _apiCardCount = response.cards.length;
        _apiCards = response.cards
            .map(
              (card) => _AiApiCardPreview(
                title: card.title,
                subtitle: card.subtitle,
                body: card.body,
                reference: card.reference,
                source: card.source,
              ),
            )
            .toList(growable: false);
      });
    } catch (error) {
      setState(() {
        _apiError = error is IslamicAiApiException
            ? error.message
            : mapAppErrorToArabic(error);
        _apiCards = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final promptLength = _promptController.text.trim().length;
    final override = int.tryParse(_overrideController.text.trim());
    final usedToday = int.tryParse(_usedTodayController.text.trim()) ?? 0;
    final requestCost = int.tryParse(_requestCostController.text.trim()) ?? 0;
    final effectiveLimit = override ?? _planLimit;
    final remainingBefore = effectiveLimit - usedToday;
    final willBeAllowed = remainingBefore >= requestCost;

    final resultMessage = willBeAllowed
        ? adminDashText(
            context,
            ar: 'حسب الأرقام الحالية: الطلب مسموح ✓',
            en: 'By current numbers: request allowed ✓',
            fr: 'Selon les valeurs actuelles : demande autorisee ✓',
          )
        : adminDashText(
            context,
            ar: 'حسب الأرقام الحالية: الطلب مرفوض ✗',
            en: 'By current numbers: request blocked ✗',
            fr: 'Selon les valeurs actuelles : demande bloquee ✗',
          );

    return AdminDashboardSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: adminDashText(
              context,
              ar: 'أدوات المساعد الإسلامي',
              en: 'Islamic AI tools',
              fr: 'Outils IA islamique',
            ),
            subtitle: adminDashText(
              context,
              ar: 'اختبر صحة Cloudflare Worker وافتح صفحة المحادثة بدون أي مفاتيح داخل Flutter.',
              en: 'Check the Cloudflare Worker health and open the chat page without storing keys in Flutter.',
              fr: 'Verifiez le Worker Cloudflare et ouvrez le chat sans cle dans Flutter.',
            ),
          ),
          const SizedBox(height: 16),
          _BackendHealthPanel(
            health: _health,
            error: _healthError,
            isLoading: _isTestingHealth,
            onTest: _isTestingHealth ? null : _testBackendHealth,
            onOpenChat: () =>
                Navigator.of(context).pushNamed(AppRouter.islamicAiRoute),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoColumns = constraints.maxWidth >= 900;

              final quotaPanel = _QuotaPreviewPanel(
                planId: _planId,
                planIds: _planIds,
                onPlanChanged: (value) {
                  if (value == null) return;
                  setState(() => _planId = value);
                },
                overrideController: _overrideController,
                usedTodayController: _usedTodayController,
                requestCostController: _requestCostController,
                onChanged: (_) => _refreshQuotaPreview(),
                effectiveLimit: effectiveLimit,
                remainingBefore: remainingBefore,
                requestCost: requestCost,
                willBeAllowed: willBeAllowed,
                resultMessage: resultMessage,
              );

              final apiPanel = _RealAiTestPanel(
                promptController: _promptController,
                promptLength: promptLength,
                isTesting: _isTesting,
                apiAnswer: _apiAnswer,
                apiError: _apiError,
                apiCached: _apiCached,
                apiCardCount: _apiCardCount,
                onChanged: (_) => _refreshQuotaPreview(),
                onSend: willBeAllowed && !_isTesting ? _sendRealAiTest : null,
                apiCards: _apiCards,
              );

              if (!isTwoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [quotaPanel, const SizedBox(height: 16), apiPanel],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quotaPanel),
                  const SizedBox(width: 16),
                  Expanded(child: apiPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BackendHealthPanel extends StatelessWidget {
  const _BackendHealthPanel({
    required this.health,
    required this.error,
    required this.isLoading,
    required this.onTest,
    required this.onOpenChat,
  });

  final BackendHealth? health;
  final String? error;
  final bool isLoading;
  final VoidCallback? onTest;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return _PanelBox(
      title: adminDashText(
        context,
        ar: 'Islamic Backend',
        en: 'Islamic Backend',
        fr: 'Backend islamique',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onTest,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: Text(isLoading ? 'Testing...' : 'Test Islamic Backend'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Open Islamic Chat'),
              ),
            ],
          ),
          if (error?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _StatusBanner(success: false, message: error!),
          ],
          if (health != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AiUsageChip(label: 'service: ${health!.service}'),
                _AiUsageChip(label: 'version: ${health!.version}'),
                _AiUsageChip(label: 'ai: ${health!.ai ?? false}'),
                _AiUsageChip(label: 'cache: ${health!.cache ?? false}'),
                _AiUsageChip(label: 'mcp: ${health!.mcp}'),
                _AiUsageChip(label: 'time: ${health!.time}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuotaPreviewPanel extends StatelessWidget {
  const _QuotaPreviewPanel({
    required this.planId,
    required this.planIds,
    required this.onPlanChanged,
    required this.overrideController,
    required this.usedTodayController,
    required this.requestCostController,
    required this.onChanged,
    required this.effectiveLimit,
    required this.remainingBefore,
    required this.requestCost,
    required this.willBeAllowed,
    required this.resultMessage,
  });

  final String planId;
  final List<String> planIds;
  final ValueChanged<String?> onPlanChanged;
  final TextEditingController overrideController;
  final TextEditingController usedTodayController;
  final TextEditingController requestCostController;
  final ValueChanged<String> onChanged;
  final int effectiveLimit;
  final int remainingBefore;
  final int requestCost;
  final bool willBeAllowed;
  final String resultMessage;

  @override
  Widget build(BuildContext context) {
    return _PanelBox(
      title: adminDashText(
        context,
        ar: 'محاكاة الحد اليومي',
        en: 'Quota simulation',
        fr: 'Simulation de quota',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: planId,
            items: planIds
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(_sandboxPlanLabel(context, id)),
                  ),
                )
                .toList(),
            onChanged: onPlanChanged,
            decoration: InputDecoration(
              labelText: adminDashText(
                context,
                ar: 'الخطة',
                en: 'Plan',
                fr: 'Plan',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: overrideController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: adminDashText(
                context,
                ar: 'حد مخصص اختياري',
                en: 'Optional custom limit',
                fr: 'Limite personnalisee optionnelle',
              ),
              hintText: 'null',
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: usedTodayController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: adminDashText(
                context,
                ar: 'الاستخدام الحالي',
                en: 'Current usage',
                fr: 'Usage actuel',
              ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: requestCostController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: adminDashText(
                context,
                ar: 'تكلفة الطلب',
                en: 'Request cost',
                fr: 'Cout de la demande',
              ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SandboxStatChip(
                label: adminDashText(
                  context,
                  ar: 'الحد الفعلي',
                  en: 'Effective limit',
                  fr: 'Limite effective',
                ),
                value: '$effectiveLimit',
              ),
              _SandboxStatChip(
                label: adminDashText(
                  context,
                  ar: 'المتبقي',
                  en: 'Remaining',
                  fr: 'Restant',
                ),
                value: '$remainingBefore',
              ),
              _SandboxStatChip(
                label: adminDashText(
                  context,
                  ar: 'تكلفة الطلب',
                  en: 'Request cost',
                  fr: 'Cout',
                ),
                value: '$requestCost',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusBanner(success: willBeAllowed, message: resultMessage),
        ],
      ),
    );
  }
}

class _RealAiTestPanel extends StatelessWidget {
  const _RealAiTestPanel({
    required this.promptController,
    required this.promptLength,
    required this.isTesting,
    required this.apiAnswer,
    required this.apiError,
    required this.apiCached,
    required this.apiCardCount,
    required this.onChanged,
    required this.onSend,
    required this.apiCards,
  });

  final TextEditingController promptController;
  final int promptLength;
  final bool isTesting;
  final String? apiAnswer;
  final String? apiError;
  final bool? apiCached;
  final int? apiCardCount;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;
  final List<_AiApiCardPreview> apiCards;

  @override
  Widget build(BuildContext context) {
    return _PanelBox(
      title: adminDashText(
        context,
        ar: 'اختبار حقيقي للـ API',
        en: 'Real API test',
        fr: 'Test API reel',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: promptController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: adminDashText(
                context,
                ar: 'سؤال الاختبار',
                en: 'Test question',
                fr: 'Question de test',
              ),
              helperText: adminDashText(
                context,
                ar: 'عدد الحروف: $promptLength',
                en: 'Characters: $promptLength',
                fr: 'Caracteres : $promptLength',
              ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSend,
            icon: isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              isTesting
                  ? adminDashText(
                      context,
                      ar: 'جار الاختبار...',
                      en: 'Testing...',
                      fr: 'Test...',
                    )
                  : adminDashText(
                      context,
                      ar: 'إرسال اختبار حقيقي',
                      en: 'Send real test',
                      fr: 'Envoyer un test reel',
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (apiError != null)
            _StatusBanner(success: false, message: apiError!),
          if (apiAnswer != null)
            _ApiResultPreview(
              answer: apiAnswer!,
              cached: apiCached,
              cardCount: apiCardCount,
              cards: apiCards,
            ),
        ],
      ),
    );
  }
}

class _AiApiCardPreview {
  const _AiApiCardPreview({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.reference,
    required this.source,
  });

  final String title;
  final String subtitle;
  final String body;
  final String reference;
  final String source;
}

class _ApiResultPreview extends StatelessWidget {
  const _ApiResultPreview({
    required this.answer,
    required this.cached,
    required this.cardCount,
    required this.cards,
  });

  final String answer;
  final bool? cached;
  final int? cardCount;
  final List<_AiApiCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AiUsageChip(
                label: cached == true ? 'cached: true' : 'cached: false',
                color: cached == true ? Colors.green.shade100 : null,
              ),
              _AiUsageChip(label: 'cards: ${cardCount ?? 0}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            adminDashText(context, ar: 'الإجابة', en: 'Answer', fr: 'Reponse'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          SelectableText(
            answer.isEmpty ? '—' : answer,
            textDirection: TextDirection.rtl,
          ),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              adminDashText(context, ar: 'الكروت', en: 'Cards', fr: 'Cartes'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...cards.map((card) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      card.title.isEmpty ? card.reference : card.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (card.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SelectableText(card.body, textDirection: TextDirection.rtl),
                    if (card.source.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        card.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _PanelBox extends StatelessWidget {
  const _PanelBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.success, required this.message});

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    final background = success ? Colors.green.shade100 : Colors.red.shade100;
    final foreground = success ? Colors.green.shade900 : Colors.red.shade900;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SandboxStatChip extends StatelessWidget {
  const _SandboxStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _AiUsageTable extends StatelessWidget {
  const _AiUsageTable({
    required this.entries,
    required this.access,
    required this.busyUserId,
    required this.canManageTarget,
    required this.onEdit,
    required this.onReset,
  });

  final List<AdminAiUsageEntry> entries;
  final AdminDashboardAccess access;
  final String? busyUserId;
  final bool Function(AdminDashboardAccess, AdminAiUsageEntry) canManageTarget;
  final Future<void> Function(AdminAiUsageEntry entry) onEdit;
  final Future<void> Function(AdminAiUsageEntry entry) onReset;

  @override
  Widget build(BuildContext context) {
    return AdminDashboardSurfaceCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 1040
              ? 1040.0
              : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: DataTable(
                dataRowMinHeight: 92,
                dataRowMaxHeight: 132,
                headingRowHeight: 56,
                columnSpacing: 24,
                horizontalMargin: 20,
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
                        ar: 'الاستخدام',
                        en: 'Usage',
                        fr: 'Usage',
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
                rows: entries
                    .map((entry) {
                      final percent = _usagePercent(entry);
                      final isBusy = busyUserId == entry.uid;
                      final canManage = canManageTarget(access, entry);

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 360,
                              child: _TableUserCell(entry: entry),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 340,
                              child: _TableUsageCell(
                                entry: entry,
                                percent: percent,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 280,
                              child: _TableActionsCell(
                                isBusy: isBusy,
                                canManage: canManage,
                                onEdit: () => onEdit(entry),
                                onReset: () => onReset(entry),
                              ),
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TableUserCell extends StatelessWidget {
  const _TableUserCell({required this.entry});

  final AdminAiUsageEntry entry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.displayName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            entry.email ?? entry.uid,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AiUsageChip(label: _planLabel(context, entry.planId)),
              _AiUsageChip(label: adminDashboardRoleLabel(entry.role)),
              if (entry.isBlocked)
                _AiUsageChip(
                  label: adminDashText(
                    context,
                    ar: 'محظور',
                    en: 'Blocked',
                    fr: 'Bloque',
                  ),
                  color: Colors.red.shade100,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableUsageCell extends StatelessWidget {
  const _TableUsageCell({required this.entry, required this.percent});

  final AdminAiUsageEntry entry;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adminDashText(
              context,
              ar: 'الاستخدام ${entry.usedToday} من ${entry.effectiveDailyLimit}',
              en: 'Usage ${entry.usedToday} of ${entry.effectiveDailyLimit}',
              fr: 'Usage ${entry.usedToday} sur ${entry.effectiveDailyLimit}',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: percent),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AiUsageChip(
                label: adminDashText(
                  context,
                  ar: 'حد مخصص ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                  en: 'Override ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                  fr: 'Perso ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                ),
              ),
              _AiUsageChip(
                label:
                    entry.resetDate ??
                    adminDashText(
                      context,
                      ar: 'بلا تاريخ',
                      en: 'No date',
                      fr: 'Sans date',
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableActionsCell extends StatelessWidget {
  const _TableActionsCell({
    required this.isBusy,
    required this.canManage,
    required this.onEdit,
    required this.onReset,
  });

  final bool isBusy;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: canManage ? onEdit : null,
          icon: const Icon(Icons.tune_outlined),
          label: Text(
            adminDashText(context, ar: 'تعديل', en: 'Edit', fr: 'Modifier'),
          ),
        ),
        OutlinedButton.icon(
          onPressed: canManage ? onReset : null,
          icon: const Icon(Icons.refresh_outlined),
          label: Text(
            adminDashText(context, ar: 'إعادة', en: 'Reset', fr: 'Reset'),
          ),
        ),
      ],
    );
  }
}

class _AiUsageCards extends StatelessWidget {
  const _AiUsageCards({
    required this.entries,
    required this.access,
    required this.busyUserId,
    required this.canManageTarget,
    required this.onEdit,
    required this.onReset,
  });

  final List<AdminAiUsageEntry> entries;
  final AdminDashboardAccess access;
  final String? busyUserId;
  final bool Function(AdminDashboardAccess, AdminAiUsageEntry) canManageTarget;
  final Future<void> Function(AdminAiUsageEntry entry) onEdit;
  final Future<void> Function(AdminAiUsageEntry entry) onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 880
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return AdminDashboardGridWrap(
          children: entries
              .map((entry) {
                final isBusy = busyUserId == entry.uid;
                final canManage = canManageTarget(access, entry);
                final percent = _usagePercent(entry);

                return SizedBox(
                  width: cardWidth.clamp(280.0, 460.0).toDouble(),
                  child: AdminDashboardSurfaceCard(
                    minHeight: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.displayName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 6),
                        Text(
                          entry.email ?? entry.uid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _AiUsageChip(
                              label: _planLabel(context, entry.planId),
                            ),
                            _AiUsageChip(
                              label: adminDashboardRoleLabel(entry.role),
                              color: entry.role == AdminDashboardRole.superAdmin
                                  ? Colors.orange.shade100
                                  : null,
                            ),
                            if (entry.isBlocked)
                              _AiUsageChip(
                                label: adminDashText(
                                  context,
                                  ar: 'محظور',
                                  en: 'Blocked',
                                  fr: 'Bloque',
                                ),
                                color: Colors.red.shade100,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          adminDashText(
                            context,
                            ar: 'الاستخدام ${entry.usedToday} من ${entry.effectiveDailyLimit}',
                            en: 'Usage ${entry.usedToday} of ${entry.effectiveDailyLimit}',
                            fr: 'Usage ${entry.usedToday} sur ${entry.effectiveDailyLimit}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: percent),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _AiUsageChip(
                              label: adminDashText(
                                context,
                                ar: 'حد مخصص ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                                en: 'Override ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                                fr: 'Perso ${entry.aiUsageLimitOverride?.toString() ?? '—'}',
                              ),
                            ),
                            _AiUsageChip(
                              label:
                                  entry.resetDate ??
                                  adminDashText(
                                    context,
                                    ar: 'بلا تاريخ',
                                    en: 'No date',
                                    fr: 'Sans date',
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
                              onPressed: isBusy || !canManage
                                  ? null
                                  : () => onEdit(entry),
                              icon: const Icon(Icons.tune_outlined),
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
                              onPressed: isBusy || !canManage
                                  ? null
                                  : () => onReset(entry),
                              icon: const Icon(Icons.refresh_outlined),
                              label: Text(
                                adminDashText(
                                  context,
                                  ar: 'إعادة ضبط',
                                  en: 'Reset',
                                  fr: 'Reinitialiser',
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
        );
      },
    );
  }
}

class _AiUsageDialog extends StatefulWidget {
  const _AiUsageDialog({required this.entry});

  final AdminAiUsageEntry entry;

  @override
  State<_AiUsageDialog> createState() => _AiUsageDialogState();
}

class _AiUsageDialogState extends State<_AiUsageDialog> {
  static const _quickOverrides = <int>[5, 30, 100];

  late final TextEditingController _overrideController;
  late final TextEditingController _usedTodayController;
  late final TextEditingController _dailyLimitController;
  late final TextEditingController _resetDateController;

  @override
  void initState() {
    super.initState();
    _overrideController = TextEditingController(
      text: widget.entry.aiUsageLimitOverride?.toString() ?? '',
    );
    _usedTodayController = TextEditingController(
      text: '${widget.entry.usedToday}',
    );
    _dailyLimitController = TextEditingController(
      text: widget.entry.usageDailyLimit?.toString() ?? '',
    );
    _resetDateController = TextEditingController(
      text: widget.entry.resetDate ?? '',
    );
  }

  @override
  void dispose() {
    _overrideController.dispose();
    _usedTodayController.dispose();
    _dailyLimitController.dispose();
    _resetDateController.dispose();
    super.dispose();
  }

  void _showValidationMessage(String message) {
    showAdminDashboardSnackBar(context, message: message, isError: true);
  }

  void _submit() {
    final overrideText = _overrideController.text.trim();
    final usedTodayText = _usedTodayController.text.trim();
    final dailyLimitText = _dailyLimitController.text.trim();
    final resetDateText = _resetDateController.text.trim();

    final usedToday = int.tryParse(usedTodayText);
    if (usedToday == null || usedToday < 0) {
      _showValidationMessage(
        adminDashText(
          context,
          ar: 'أدخل قيمة صحيحة للاستخدام اليومي.',
          en: 'Enter a valid usedToday value.',
          fr: 'Entrez une valeur valide pour l usage du jour.',
        ),
      );
      return;
    }

    int? aiUsageLimitOverride;
    var clearOverride = false;

    if (overrideText.isEmpty) {
      clearOverride = widget.entry.aiUsageLimitOverride != null;
    } else {
      aiUsageLimitOverride = int.tryParse(overrideText);
      if (aiUsageLimitOverride == null || aiUsageLimitOverride < 0) {
        _showValidationMessage(
          adminDashText(
            context,
            ar: 'أدخل حدًا صحيحًا أو اتركه فارغًا.',
            en: 'Enter a valid override limit or leave it blank.',
            fr: 'Saisissez une limite valide ou laissez vide.',
          ),
        );
        return;
      }
    }

    int? dailyLimit;
    if (dailyLimitText.isNotEmpty) {
      dailyLimit = int.tryParse(dailyLimitText);
      if (dailyLimit == null || dailyLimit < 0) {
        _showValidationMessage(
          adminDashText(
            context,
            ar: 'أدخل حدًا يوميًا صحيحًا.',
            en: 'Enter a valid stored daily limit.',
            fr: 'Entrez une limite quotidienne valide.',
          ),
        );
        return;
      }
    }

    Navigator.of(context).pop(
      _AiUsageDialogResult(
        aiUsageLimitOverride:
            overrideText.isNotEmpty &&
                aiUsageLimitOverride != widget.entry.aiUsageLimitOverride
            ? aiUsageLimitOverride
            : null,
        clearAiUsageLimitOverride: clearOverride,
        usedToday: usedToday != widget.entry.usedToday ? usedToday : null,
        dailyLimit:
            dailyLimitText.isNotEmpty &&
                dailyLimit != widget.entry.usageDailyLimit
            ? dailyLimit
            : null,
        resetDate: resetDateText != widget.entry.resetDate
            ? resetDateText
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        adminDashText(
          context,
          ar: 'تعديل الاستخدام - ${widget.entry.displayName}',
          en: 'Edit AI usage - ${widget.entry.displayName}',
          fr: 'Modifier l utilisation IA - ${widget.entry.displayName}',
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardFormSection(
                title: adminDashText(
                  context,
                  ar: 'ملخص الحساب',
                  en: 'Account summary',
                  fr: 'Resume du compte',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.entry.displayName),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AiUsageChip(
                          label: _planLabel(context, widget.entry.planId),
                        ),
                        _AiUsageChip(
                          label: adminDashboardRoleLabel(widget.entry.role),
                        ),
                        _AiUsageChip(
                          label: adminDashText(
                            context,
                            ar: 'الحد الفعلي ${widget.entry.effectiveDailyLimit}',
                            en: 'Effective ${widget.entry.effectiveDailyLimit}',
                            fr: 'Effective ${widget.entry.effectiveDailyLimit}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdminDashboardFormSection(
                title: adminDashText(
                  context,
                  ar: 'ضبط الحدود',
                  en: 'Quota controls',
                  fr: 'Controle du quota',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickOverrides
                          .map((limit) {
                            return ChoiceChip(
                              label: Text('$limit'),
                              selected:
                                  _overrideController.text.trim() == '$limit',
                              onSelected: (_) {
                                setState(() {
                                  _overrideController.text = '$limit';
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _overrideController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'حد AI المخصص',
                          en: 'AI override limit',
                          fr: 'Limite IA personnalisee',
                        ),
                        helperText: adminDashText(
                          context,
                          ar: 'فارغ = استخدام حد الخطة',
                          en: 'Empty = use plan limit',
                          fr: 'Vide = utiliser la limite du plan',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dailyLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'الحد اليومي المخزن',
                          en: 'Stored daily limit',
                          fr: 'Limite quotidienne enregistree',
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
                  ar: 'الاستخدام الحالي',
                  en: 'Current usage',
                  fr: 'Usage actuel',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _usedTodayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'استخدام اليوم',
                          en: 'Used today',
                          fr: 'Utilise aujourd hui',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resetDateController,
                      decoration: InputDecoration(
                        labelText: adminDashText(
                          context,
                          ar: 'تاريخ إعادة الضبط',
                          en: 'Reset date',
                          fr: 'Date de reinitialisation',
                        ),
                      ),
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
            adminDashText(context, ar: 'حفظ', en: 'Save', fr: 'Enregistrer'),
          ),
        ),
      ],
    );
  }
}

class _AiUsageDialogResult {
  const _AiUsageDialogResult({
    this.aiUsageLimitOverride,
    this.clearAiUsageLimitOverride = false,
    this.usedToday,
    this.dailyLimit,
    this.resetDate,
  });

  final int? aiUsageLimitOverride;
  final bool clearAiUsageLimitOverride;
  final int? usedToday;
  final int? dailyLimit;
  final String? resetDate;
}

class _AiUsageChip extends StatelessWidget {
  const _AiUsageChip({required this.label, this.color});

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

class _AiUsageStateCard extends StatelessWidget {
  const _AiUsageStateCard({required this.title, required this.message});

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
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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

class _AiUsageSummary {
  const _AiUsageSummary({
    required this.totalUsers,
    required this.totalUsedToday,
    required this.overrideCount,
    required this.blockedCount,
  });

  final int totalUsers;
  final int totalUsedToday;
  final int overrideCount;
  final int blockedCount;

  factory _AiUsageSummary.fromEntries(List<AdminAiUsageEntry> entries) {
    return _AiUsageSummary(
      totalUsers: entries.length,
      totalUsedToday: entries.fold<int>(
        0,
        (sum, entry) => sum + entry.usedToday,
      ),
      overrideCount: entries
          .where((entry) => entry.aiUsageLimitOverride != null)
          .length,
      blockedCount: entries.where((entry) => entry.isBlocked).length,
    );
  }
}

double _usagePercent(AdminAiUsageEntry entry) {
  final limit = entry.effectiveDailyLimit;
  if (limit <= 0) return 0;
  return (entry.usedToday / limit).clamp(0, 1).toDouble();
}

String _planLabel(BuildContext context, String value) {
  switch (value.trim().toLowerCase()) {
    case 'plus':
      return 'Plus';
    case 'pro':
      return 'Pro';
    default:
      return adminDashText(context, ar: 'مجاني', en: 'Free', fr: 'Gratuit');
  }
}

String _sandboxPlanLabel(BuildContext context, String value) {
  switch (value.trim().toLowerCase()) {
    case 'plus':
      return adminDashText(
        context,
        ar: 'بلس 100',
        en: 'Plus 100',
        fr: 'Plus 100',
      );
    case 'pro':
      return adminDashText(context, ar: 'برو 30', en: 'Pro 30', fr: 'Pro 30');
    default:
      return adminDashText(
        context,
        ar: 'مجاني 5',
        en: 'Free 5',
        fr: 'Gratuit 5',
      );
  }
}
