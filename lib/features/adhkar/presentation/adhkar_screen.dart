import 'package:flutter/material.dart';

import '../../../core/models/feature_entitlement.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/points_award_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/feature_category_card.dart';
import '../../../shared/widgets/loading_state_view.dart';
import '../../custom_content/models/custom_user_content_models.dart';
import '../../custom_content/presentation/user_custom_content_screen.dart';
import '../data/firestore_adhkar_repository.dart';
import '../data/local_adhkar_progress_repository.dart';
import '../data/local_adhkar_repository.dart';
import '../models/adhkar_category.dart';
import 'adhkar_controller.dart';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({
    super.key,
    required this.repository,
    required this.progressRepository,
    required this.services,
    required this.preferences,
  });

  final LocalAdhkarRepository repository;
  final LocalAdhkarProgressRepository progressRepository;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final AdhkarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdhkarController(
      repository: widget.repository,
      progressRepository: widget.progressRepository,
      firestoreRepository: FirestoreAdhkarRepository(
        firebaseConfigured: widget.services.firebaseConfigured,
        localeCode: widget.preferences.localeCode,
      ),
      analyticsService: widget.services.analyticsService,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.services.authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;
        if (session == null) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _buildBody(context, false),
          );
        }

        return StreamBuilder<List<FeatureEntitlement>>(
          stream: widget.services.entitlementRepository.watchUserEntitlements(
            session.uid,
          ),
          builder: (context, entitlementSnapshot) {
            final entitlements = entitlementSnapshot.data ?? const [];
            final favoritesUnlocked = widget.services.entitlementChecker
                .isEnabled(
                  featureKey: 'advanced_adhkar',
                  entitlements: entitlements,
                );

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildBody(context, favoritesUnlocked),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, bool favoritesUnlocked) {
    if (_controller.isLoading) {
      return const LoadingStateView(label: 'Loading adhkar categories');
    }

    return FeatureCategoryCardGrid(
      itemCount: _controller.categories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return FeatureCategoryCard(
            title: 'My adhkar',
            subtitle: '',
            icon: Icons.add_circle_outline_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UserCustomContentScreen(
                    services: widget.services,
                    type: UserCustomContentType.dhikr,
                  ),
                ),
              );
            },
          );
        }
        final category = _controller.categories[index - 1];
        final locked = category.isPremium && !favoritesUnlocked;
        final completed = _controller.isCategoryCompleted(category.id);
        return FeatureCategoryCard(
          title: category.title,
          subtitle: '',
          icon: _iconForCategory(category.id),
          locked: locked,
          variant: category.isFavorites
              ? FeatureCategoryCardVariant.compact
              : FeatureCategoryCardVariant.category,
          footerLabel: locked
              ? 'Subscription required'
              : completed
              ? 'Completed today'
              : null,
          onTap: () => _openCategory(category, favoritesUnlocked),
        );
      },
    );
  }

  Future<void> _openCategory(
    AdhkarCategory category,
    bool favoritesUnlocked,
  ) async {
    if (category.isPremium && !favoritesUnlocked) {
      _showFavoriteLocked(context);
      return;
    }

    if (_shouldBlockForKahf(category)) {
      final confirmed = await _showKahfGate(context);
      if (!confirmed) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AdhkarCategoryScreen(
          category: category,
          controller: _controller,
          favoritesUnlocked: favoritesUnlocked,
          services: widget.services,
        ),
      ),
    );
  }

  bool _shouldBlockForKahf(AdhkarCategory category) {
    return widget.preferences.isKahfGateActiveToday &&
        !_isKahfCategory(category);
  }

  bool _isKahfCategory(AdhkarCategory category) {
    final value = '${category.id} ${category.title}'.toLowerCase();
    return value.contains('kahf') || value.contains('الكهف');
  }

  Future<bool> _showKahfGate(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سورة الكهف أولًا',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'إعداداتك مفعلة على إتمام الكهف يوم الجمعة قبل فتح الورد العادي. سجل أنك قرأتها ثم أكمل وردك.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await widget.preferences
                          .markKahfCompletedForCurrentWeek();
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('قرأت سورة الكهف'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('العودة'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}

class _AdhkarCategoryScreen extends StatefulWidget {
  const _AdhkarCategoryScreen({
    required this.category,
    required this.controller,
    required this.favoritesUnlocked,
    required this.services,
  });

  final AdhkarCategory category;
  final AdhkarController controller;
  final bool favoritesUnlocked;
  final AppServices services;

  @override
  State<_AdhkarCategoryScreen> createState() => _AdhkarCategoryScreenState();
}

class _AdhkarCategoryScreenState extends State<_AdhkarCategoryScreen> {
  bool _completionHandled = false;
  late final PointsAwardService _pointsAwardService;

  @override
  void initState() {
    super.initState();
    _pointsAwardService = PointsAwardService(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    _completionHandled = widget.controller.isCategoryCompleted(
      widget.category.id,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadCategory(widget.category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.stateFor(widget.category.id);

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          widget.category.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => widget.controller.loadCategory(
                      widget.category,
                      force: true,
                    ),
                    child: _buildState(context, state),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildState(BuildContext context, AdhkarCategoryState state) {
    if (state.isLoading && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          LoadingStateView(label: 'جارٍ تحميل الأذكار'),
        ],
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.52)
                .clamp(260.0, 520.0)
                .toDouble(),
            child: ErrorStateView(
              title: 'تعذر تحميل القسم',
              message: 'تعذر تحميل أذكار هذا القسم الآن. حاول مرة أخرى.',
              onRetry: () =>
                  widget.controller.loadCategory(widget.category, force: true),
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      final message = widget.category.isFavorites
          ? 'لم تضف أذكارًا إلى المفضلة بعد'
          : 'لا توجد أذكار مضافة لهذا القسم بعد';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.52)
                .clamp(260.0, 520.0)
                .toDouble(),
            child: EmptyStateView(
              title: widget.category.title,
              message: message,
              icon: widget.category.isFavorites
                  ? Icons.favorite_border_rounded
                  : _iconForCategory(widget.category.id),
            ),
          ),
        ],
      );
    }

    final sortedItems = [...state.items]
      ..sort((a, b) {
        final aCompleted = widget.controller.isCompleted(a);
        final bCompleted = widget.controller.isCompleted(b);
        if (aCompleted != bCompleted) {
          return aCompleted ? 1 : -1;
        }
        return a.sortOrder.compareTo(b.sortOrder);
      });

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: sortedItems.length + (state.sourceLabel == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (state.sourceLabel != null && index == 0) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(label: Text(state.sourceLabel!)),
          );
        }

        final item = sortedItems[state.sourceLabel == null ? index : index - 1];
        final progress = widget.controller.progressFor(item.id);
        final current = progress > item.requiredCount
            ? item.requiredCount
            : progress;
        final completed = widget.controller.isCompleted(item);

        return Opacity(
          opacity: completed ? 0.72 : 1,
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: completed
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : null,
            child: InkWell(
              onTap: () async {
                await widget.controller.incrementItem(item);
                if (mounted) {
                  await _maybeHandleCompletion();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.text,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  height: 1.7,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            if (!widget.favoritesUnlocked) {
                              _showFavoriteLocked(context);
                              return;
                            }
                            await widget.controller.toggleFavorite(item.id);
                          },
                          icon: Icon(
                            widget.controller.favorites.contains(item.id)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    if (item.source?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        item.source!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _InlineStatusBadge(completed: completed),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => widget.controller.resetItem(item),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('العدد المطلوب: ${item.requiredCount}'),
                        const Spacer(),
                        Text('$current / ${item.requiredCount}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.requiredCount == 0
                          ? 0
                          : current / item.requiredCount,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybeHandleCompletion() async {
    if (_completionHandled) {
      return;
    }
    final state = widget.controller.stateFor(widget.category.id);
    if (state.items.isEmpty ||
        state.items.any((item) => !widget.controller.isCompleted(item))) {
      return;
    }
    _completionHandled = true;
    final shouldAward = await widget.controller.markCategoryCompleted(
      widget.category.id,
    );
    final awardResult = shouldAward
        ? await _awardCategoryPoints()
        : const PointsAwardResult(
            applied: false,
            delta: 0,
            duplicate: true,
            reason: 'local-duplicate',
          );
    if (!mounted) {
      return;
    }
    final completedCount = state.items.length;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اكتمل القسم',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(_completionMessage(completedCount, awardResult)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(this.context).pop();
                    },
                    child: const Text('إنهاء القسم'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<PointsAwardResult> _awardCategoryPoints() async {
    final session = widget.services.authService.currentSession;
    if (session == null) {
      return const PointsAwardResult(
        applied: false,
        delta: 0,
        reason: 'missing-session',
        message: 'Sign in is required for server points.',
      );
    }

    return _pointsAwardService.awardAdhkarCompletion(
      categoryId: widget.category.id,
      date: DateTime.now(),
      title: widget.category.title,
    );
  }

  String _completionMessage(int completedCount, PointsAwardResult result) {
    final base =
        'Completed $completedCount adhkar in ${widget.category.title}.';
    if (result.applied) {
      return '$base\n+${result.delta} points.';
    }
    if (result.duplicate) {
      return '$base\nPoints for this category were already counted today.';
    }
    if (result.reason == 'missing-session') {
      return '$base\nSign in to receive points.';
    }
    return base;
  }
}

class _InlineStatusBadge extends StatelessWidget {
  const _InlineStatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? Colors.green
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        completed ? 'مكتمل' : 'اضغط للعد',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

void _showFavoriteLocked(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'إضافة الأذكار إلى المفضلة متاحة للمشتركين فقط في الوقت الحالي.',
      ),
    ),
  );
}

IconData _iconForCategory(String categoryId) {
  switch (categoryId) {
    case 'favorites':
      return Icons.favorite_rounded;
    case 'morning':
      return Icons.wb_sunny_outlined;
    case 'evening':
      return Icons.nights_stay_outlined;
    case 'travel':
      return Icons.flight_takeoff_rounded;
    case 'sleep':
      return Icons.bedtime_outlined;
    case 'post_prayer':
      return Icons.mosque_outlined;
    case 'waking':
      return Icons.light_mode_outlined;
    default:
      return Icons.menu_book_outlined;
  }
}
