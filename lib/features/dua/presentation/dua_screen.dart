import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/content_locale_fallback.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/points_award_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/feature_category_card.dart';
import '../../custom_content/models/custom_user_content_models.dart';
import '../../custom_content/presentation/user_custom_content_screen.dart';

class DuaScreen extends StatefulWidget {
  const DuaScreen({
    super.key,
    required this.services,
    required this.preferences,
  });

  final AppServices services;
  final AppPreferences preferences;

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  Set<String> _completedCategories = const <String>{};

  @override
  void initState() {
    super.initState();
    _refreshCompletedCategories();
  }

  Future<void> _refreshCompletedCategories() async {
    final completed = await _loadTodayDuaCompleted(widget.preferences);
    if (mounted) {
      setState(() => _completedCategories = completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_DuaCategory>>(
      future: _duaCategoriesFor(
        firebaseConfigured: widget.services.firebaseConfigured,
        localeCode: widget.preferences.localeCode,
      ),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? _duaCategories;
        return FeatureCategoryCardGrid(
          itemCount: categories.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return FeatureCategoryCard(
                title: 'My duas',
                subtitle: '',
                icon: Icons.add_circle_outline_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserCustomContentScreen(
                        services: widget.services,
                        type: UserCustomContentType.dua,
                      ),
                    ),
                  );
                },
              );
            }
            final category = categories[index - 1];
            final completed = _completedCategories.contains(category.id);
            return FeatureCategoryCard(
              title: category.title,
              subtitle: '',
              icon: category.icon,
              footerLabel: completed ? 'Completed today' : null,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => _DuaCategoryDetails(
                      category: category,
                      services: widget.services,
                      preferences: widget.preferences,
                    ),
                  ),
                );
                await _refreshCompletedCategories();
              },
            );
          },
        );
      },
    );
  }
}

class _DuaCategoryDetails extends StatefulWidget {
  const _DuaCategoryDetails({
    required this.category,
    required this.services,
    required this.preferences,
  });

  final _DuaCategory category;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<_DuaCategoryDetails> createState() => _DuaCategoryDetailsState();
}

class _DuaCategoryDetailsState extends State<_DuaCategoryDetails> {
  static const _defaultDuration = Duration(seconds: 5);

  int _currentIndex = 0;
  final Set<String> _completed = <String>{};
  Timer? _timer;
  double _progress = 0;
  bool _completionHandled = false;
  late final PointsAwardService _pointsAwardService;

  @override
  void initState() {
    super.initState();
    _pointsAwardService = PointsAwardService(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    _timer?.cancel();
    _progress = 0;
    const tick = Duration(milliseconds: 100);
    final totalTicks = _defaultDuration.inMilliseconds ~/ tick.inMilliseconds;
    var currentTick = 0;
    _timer = Timer.periodic(tick, (timer) {
      currentTick += 1;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = currentTick / totalTicks;
      });
      if (currentTick >= totalTicks) {
        timer.cancel();
        _completeCurrentItem();
      }
    });
  }

  void _completeCurrentItem() {
    final item = widget.category.items[_currentIndex];
    _completed.add(item.id);
    if (_currentIndex >= widget.category.items.length - 1) {
      _showCompletionSummary();
      return;
    }
    setState(() {
      _currentIndex += 1;
      _progress = 0;
    });
    _startProgress();
  }

  Future<void> _showCompletionSummary() async {
    if (_completionHandled) {
      return;
    }
    _completionHandled = true;
    final alreadyCompleted = await _markDuaCategoryCompleted(
      widget.preferences,
      widget.category.id,
    );
    final awardResult = alreadyCompleted
        ? const PointsAwardResult(
            applied: false,
            delta: 0,
            duplicate: true,
            reason: 'local-duplicate',
          )
        : await _awardCategoryPoints();
    if (!mounted) {
      return;
    }
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
                Text(_completionMessage(awardResult)),
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

    return _pointsAwardService.awardDuaCompletion(
      categoryId: widget.category.id,
      date: DateTime.now(),
      title: widget.category.title,
    );
  }

  String _completionMessage(PointsAwardResult result) {
    final base =
        'Completed ${_completed.length} duas in ${widget.category.title}.';
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

  @override
  Widget build(BuildContext context) {
    if (widget.category.items.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyStateView(
            title: widget.category.title,
            message: 'لا توجد أدعية مضافة لهذا القسم بعد',
            icon: widget.category.icon,
          ),
        ),
      );
    }

    final item = widget.category.items[_currentIndex];
    final completedCount = _completed.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.category.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${completedCount + 1}/${widget.category.items.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            item.text,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(height: 1.9),
                          ),
                          if (item.source?.isNotEmpty == true) ...[
                            const SizedBox(height: 18),
                            Text(
                              item.source!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'التقدم: $completedCount من ${widget.category.items.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress.clamp(0, 1),
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentIndex == 0
                          ? null
                          : () {
                              setState(() {
                                _currentIndex -= 1;
                                _progress = 0;
                              });
                              _startProgress();
                            },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      label: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        _completeCurrentItem();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('تمت القراءة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuaCategory {
  const _DuaCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<_DuaItem> items;
}

class _DuaItem {
  const _DuaItem({
    required this.id,
    required this.title,
    required this.text,
    this.source,
  });

  final String id;
  final String title;
  final String text;
  final String? source;
}

Future<List<_DuaCategory>>? _duaCategoriesFuture;
bool? _duaCategoriesFutureFirebaseConfigured;
String? _duaCategoriesFutureLocaleCode;

Future<Set<String>> _loadTodayDuaCompleted(AppPreferences preferences) async {
  final today = _todayKey();
  if (preferences.duaCompletedDate != today) {
    await preferences.setDuaCompleted({});
    await preferences.setDuaCompletedDate(today);
    return {};
  }
  return preferences.duaCompleted;
}

Future<bool> _markDuaCategoryCompleted(
  AppPreferences preferences,
  String categoryId,
) async {
  final completed = await _loadTodayDuaCompleted(preferences);
  final normalized = categoryId.trim().toLowerCase();
  if (completed.contains(normalized)) {
    return true;
  }
  await preferences.setDuaCompleted({...completed, normalized});
  await preferences.setDuaCompletedDate(_todayKey());
  return false;
}

String _todayKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

Future<List<_DuaCategory>> _duaCategoriesFor({
  required bool firebaseConfigured,
  required String localeCode,
}) {
  if (_duaCategoriesFuture == null ||
      _duaCategoriesFutureFirebaseConfigured != firebaseConfigured ||
      _duaCategoriesFutureLocaleCode != localeCode) {
    _duaCategoriesFutureFirebaseConfigured = firebaseConfigured;
    _duaCategoriesFutureLocaleCode = localeCode;
    _duaCategoriesFuture = _loadDuaCategories(
      firebaseConfigured: firebaseConfigured,
      localeCode: localeCode,
    );
  }
  return _duaCategoriesFuture!;
}

Future<List<_DuaCategory>> _loadDuaCategories({
  required bool firebaseConfigured,
  required String localeCode,
}) async {
  final localCategories = await _loadLocalDuaCategories();
  if (!firebaseConfigured) {
    return localCategories;
  }

  try {
    // TODO(server-sync): version remote dua content and persist deltas into
    // the local JSON cache for first-run offline use.
    final remoteCategories = await _loadRemoteDuaCategories(
      localeCode: localeCode,
    );
    return remoteCategories.isNotEmpty ? remoteCategories : localCategories;
  } catch (_) {
    return localCategories;
  }
}

Future<List<_DuaCategory>> _loadLocalDuaCategories() async {
  try {
    final raw = await rootBundle.loadString('assets/data/duaa.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return _duaCategories;
    }

    final itemsByCategory = <String, List<_DuaItem>>{};
    for (final entry
        in (decoded['items'] as List<dynamic>? ?? const []).indexed) {
      if (entry.$2 is! Map) {
        continue;
      }
      final itemMap = Map<String, dynamic>.from(entry.$2 as Map);
      final categoryId = _stringValue(itemMap['categoryId']);
      final text = _stringValue(itemMap['text']);
      if (categoryId == null || text == null) {
        continue;
      }
      itemsByCategory
          .putIfAbsent(categoryId, () => [])
          .add(
            _DuaItem(
              id:
                  _stringValue(itemMap['id']) ??
                  '${categoryId}_${entry.$1 + 1}',
              title: _stringValue(itemMap['title']) ?? text,
              text: text,
              source: _stringValue(itemMap['source']),
            ),
          );
    }

    final categories = <_DuaCategory>[];
    for (final entry
        in (decoded['categories'] as List<dynamic>? ?? const []).indexed) {
      if (entry.$2 is! Map) {
        continue;
      }
      final categoryMap = Map<String, dynamic>.from(entry.$2 as Map);
      final id = _stringValue(categoryMap['id']);
      if (id == null) {
        continue;
      }

      final nestedItems = (categoryMap['items'] as List<dynamic>? ?? const [])
          .indexed
          .map((itemEntry) {
            if (itemEntry.$2 is! Map) {
              return null;
            }
            final itemMap = Map<String, dynamic>.from(itemEntry.$2 as Map);
            final text = _stringValue(itemMap['text']);
            if (text == null) {
              return null;
            }
            return _DuaItem(
              id: _stringValue(itemMap['id']) ?? '${id}_${itemEntry.$1 + 1}',
              title: _stringValue(itemMap['title']) ?? text,
              text: text,
              source: _stringValue(itemMap['source']),
            );
          })
          .whereType<_DuaItem>()
          .toList(growable: false);

      categories.add(
        _DuaCategory(
          id: id,
          title: _stringValue(categoryMap['title']) ?? id,
          description: _stringValue(categoryMap['description']) ?? '',
          icon: _iconForDuaCategory(id),
          items: nestedItems.isNotEmpty
              ? nestedItems
              : itemsByCategory[id] ?? const [],
        ),
      );
    }

    return categories.isNotEmpty ? categories : _duaCategories;
  } catch (_) {
    return _duaCategories;
  }
}

Future<List<_DuaCategory>> _loadRemoteDuaCategories({
  required String localeCode,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('content')
      .doc('dua')
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .orderBy('order')
      .get()
      .timeout(const Duration(seconds: 2));

  final categories = <_DuaCategory>[];
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final categoryTranslations = _translationsValue(data['translations']);
    final itemsSnapshot = await doc.reference
        .collection('items')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get()
        .timeout(const Duration(seconds: 2));

    final items = itemsSnapshot.docs
        .map((itemDoc) {
          final itemData = itemDoc.data();
          final translations = _translationsValue(itemData['translations']);
          final text = ContentLocaleFallback.resolve(
            localeCode: localeCode,
            ar:
                _stringValue(itemData['textAr']) ??
                _stringValue(translations['ar']?['text']),
            en:
                _stringValue(itemData['textEn']) ??
                _stringValue(translations['en']?['text']),
            fr:
                _stringValue(itemData['textFr']) ??
                _stringValue(translations['fr']?['text']),
            readableFallbacks: [_stringValue(itemData['text'])],
          );
          final title = ContentLocaleFallback.resolve(
            localeCode: localeCode,
            ar:
                _stringValue(itemData['titleAr']) ??
                _stringValue(translations['ar']?['title']),
            en:
                _stringValue(itemData['titleEn']) ??
                _stringValue(translations['en']?['title']),
            fr:
                _stringValue(itemData['titleFr']) ??
                _stringValue(translations['fr']?['title']),
            readableFallbacks: [_stringValue(itemData['title']), text],
          );
          final source = ContentLocaleFallback.resolve(
            localeCode: localeCode,
            ar:
                _stringValue(itemData['sourceAr']) ??
                _stringValue(translations['ar']?['source']),
            en:
                _stringValue(itemData['sourceEn']) ??
                _stringValue(translations['en']?['source']),
            fr:
                _stringValue(itemData['sourceFr']) ??
                _stringValue(translations['fr']?['source']),
            readableFallbacks: [_stringValue(itemData['source'])],
          );
          return _DuaItem(
            id: itemDoc.id,
            title: title,
            text: text,
            source: source.isEmpty ? null : source,
          );
        })
        .where((item) => item.text.trim().isNotEmpty)
        .toList(growable: false);

    categories.add(
      _DuaCategory(
        id: doc.id,
        title: ContentLocaleFallback.resolve(
          localeCode: localeCode,
          ar:
              _stringValue(data['titleAr']) ??
              _stringValue(categoryTranslations['ar']?['title']),
          en:
              _stringValue(data['titleEn']) ??
              _stringValue(categoryTranslations['en']?['title']),
          fr:
              _stringValue(data['titleFr']) ??
              _stringValue(categoryTranslations['fr']?['title']),
          readableFallbacks: [_stringValue(data['title'])],
        ),
        description: ContentLocaleFallback.resolve(
          localeCode: localeCode,
          ar:
              _stringValue(data['descriptionAr']) ??
              _stringValue(data['subtitleAr']) ??
              _stringValue(categoryTranslations['ar']?['description']),
          en:
              _stringValue(data['descriptionEn']) ??
              _stringValue(data['subtitleEn']) ??
              _stringValue(categoryTranslations['en']?['description']),
          fr:
              _stringValue(data['descriptionFr']) ??
              _stringValue(data['subtitleFr']) ??
              _stringValue(categoryTranslations['fr']?['description']),
          readableFallbacks: [_stringValue(data['description'])],
        ),
        icon: _iconForDuaCategory(doc.id),
        items: items,
      ),
    );
  }
  return categories;
}

IconData _iconForDuaCategory(String id) {
  switch (id) {
    case 'daily':
      return Icons.wb_twilight_outlined;
    case 'calm':
      return Icons.spa_outlined;
    case 'family':
      return Icons.favorite_outline_rounded;
    case 'rizq':
      return Icons.work_outline_rounded;
    default:
      return Icons.auto_awesome_outlined;
  }
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Map<String, Map<String, dynamic>> _translationsValue(dynamic value) {
  if (value is Map) {
    final translations = <String, Map<String, dynamic>>{};
    for (final entry in value.entries) {
      if (entry.value is Map) {
        translations['${entry.key}'] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }
    return translations;
  }
  return const <String, Map<String, dynamic>>{};
}

const _duaCategories = [
  _DuaCategory(
    id: 'daily',
    title: 'أدعية يومية',
    description: 'أدعية خفيفة لبداية اليوم وختمه',
    icon: Icons.wb_twilight_outlined,
    items: [
      _DuaItem(
        id: 'daily_1',
        title: 'دعاء التيسير',
        text: 'اللهم لا سهل إلا ما جعلته سهلا، وأنت تجعل الحزن إذا شئت سهلا.',
        source: 'مأثور',
      ),
      _DuaItem(
        id: 'daily_2',
        title: 'دعاء ختام اليوم',
        text:
            'اللهم إني أستودعك يومي، فاغفر زللي، واقبل عملي، واكتب لي خير ما أرجو.',
      ),
    ],
  ),
  _DuaCategory(
    id: 'calm',
    title: 'أدعية السكينة',
    description: 'طمأنينة وهدوء عند الضغط والانشغال',
    icon: Icons.spa_outlined,
    items: [
      _DuaItem(
        id: 'calm_1',
        title: 'دعاء الطمأنينة',
        text:
            'اللهم أنزل على قلبي سكينة من عندك، واصرف عني القلق، واملأ صدري رضا ويقينًا.',
      ),
      _DuaItem(
        id: 'calm_2',
        title: 'دعاء الفرج',
        text:
            'يا حي يا قيوم برحمتك أستغيث، أصلح لي شأني كله، ولا تكلني إلى نفسي طرفة عين.',
      ),
    ],
  ),
  _DuaCategory(
    id: 'family',
    title: 'أدعية الأسرة',
    description: 'دعوات للحفظ والمودة والبركة',
    icon: Icons.favorite_outline_rounded,
    items: [
      _DuaItem(
        id: 'family_1',
        title: 'دعاء البركة',
        text:
            'اللهم بارك لي في أهلي، وأدم بيننا الرحمة والمودة، واحفظنا بحفظك الذي لا يضيع.',
      ),
    ],
  ),
  _DuaCategory(
    id: 'rizq',
    title: 'أدعية الرزق',
    description: 'دعاء للسعة والبركة في العمل والرزق',
    icon: Icons.work_outline_rounded,
    items: [
      _DuaItem(
        id: 'rizq_1',
        title: 'دعاء السعة',
        text:
            'اللهم اكفني بحلالك عن حرامك، وأغنني بفضلك عمن سواك، وافتح لي أبواب رزقك.',
      ),
    ],
  ),
];
