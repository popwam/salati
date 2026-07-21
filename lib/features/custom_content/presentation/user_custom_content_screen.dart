import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/loading_state_view.dart';
import '../data/firestore_user_custom_content_repository.dart';
import '../models/custom_user_content_models.dart';

class UserCustomContentScreen extends StatefulWidget {
  const UserCustomContentScreen({
    super.key,
    required this.services,
    required this.type,
  });

  final AppServices services;
  final UserCustomContentType type;

  @override
  State<UserCustomContentScreen> createState() =>
      _UserCustomContentScreenState();
}

class _UserCustomContentScreenState extends State<UserCustomContentScreen> {
  late final FirestoreUserCustomContentRepository _repository;
  final Map<String, int> _progress = <String, int>{};
  final Set<String> _ensuredUsers = <String>{};
  Future<CustomContentPlanLimits>? _limitsFuture;

  bool get _isDhikr => widget.type == UserCustomContentType.dhikr;

  String get _title => _isDhikr ? 'أذكاري الخاصة' : 'أدعيتي الخاصة';

  String get _emptyTitle =>
      _isDhikr ? 'ابدأ بإضافة ذكر خاص' : 'ابدأ بإضافة دعاء خاص';

  String get _emptyMessage => _isDhikr
      ? 'اكتب الذكر وعدد مرات التكرار، وسيظهر هنا كورد يومي.'
      : 'اكتب الدعاء وعدد مرات التكرار، وسيظهر هنا كورد يومي.';

  @override
  void initState() {
    super.initState();
    _repository = FirestoreUserCustomContentRepository(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.services.authService.currentSession;
    if (session == null || session.uid.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const EmptyStateView(
          title: 'تحتاج حسابا أولا',
          message:
              'سجل الدخول أو انتظر تجهيز الحساب المجاني حتى تحفظ محتواك الخاص.',
        ),
      );
    }

    _limitsFuture ??= _repository.loadPlanLimitsForUser(uid: session.uid);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<CustomContentPlanLimits>(
        future: _limitsFuture,
        builder: (context, limitsSnapshot) {
          if (limitsSnapshot.hasError) {
            return EmptyStateView(
              title: 'تعذر تحميل حدود الباقة',
              message: mapAppErrorToArabic(limitsSnapshot.error!),
            );
          }
          final limits = limitsSnapshot.data;
          if (limits == null) {
            return const LoadingStateView(label: 'جارٍ قراءة حدود الباقة');
          }

          unawaited(_ensureDefaultCategory(session.uid));

          return StreamBuilder<List<UserCustomContentCategory>>(
            stream: _repository.watchCategories(
              uid: session.uid,
              type: widget.type,
            ),
            builder: (context, categoriesSnapshot) {
              if (categoriesSnapshot.hasError) {
                return EmptyStateView(
                  title: 'تعذر فتح القسم',
                  message: mapAppErrorToArabic(categoriesSnapshot.error!),
                );
              }
              final categories =
                  categoriesSnapshot.data ??
                  const <UserCustomContentCategory>[];
              final activeCategories = categories
                  .where((category) => category.isActive)
                  .toList(growable: false);
              final category = activeCategories.isEmpty
                  ? null
                  : activeCategories.first;

              if (category == null) {
                return const LoadingStateView(label: 'جارٍ تجهيز القسم الخاص');
              }

              return _isDhikr
                  ? _buildDhikrItems(session.uid, category, limits)
                  : _buildDuaItems(session.uid, category, limits);
            },
          );
        },
      ),
    );
  }

  Future<void> _ensureDefaultCategory(String uid) async {
    final key = '${widget.type.name}:$uid';
    if (_ensuredUsers.contains(key)) {
      return;
    }
    _ensuredUsers.add(key);

    final existing = await _repository
        .watchCategories(uid: uid, type: widget.type)
        .first;
    if (existing.isNotEmpty) {
      return;
    }

    try {
      await _repository.createCategory(
        uid: uid,
        type: widget.type,
        data: {
          'title': _title,
          'description': _isDhikr
              ? 'قسمك الافتراضي للأذكار الخاصة'
              : 'قسمك الافتراضي للأدعية الخاصة',
          'icon': _isDhikr ? 'menu_book' : 'volunteer_activism',
          'order': 0,
          'isActive': true,
        },
      );
    } catch (error) {
      debugPrint('[CustomContent] ensure default failed: $error');
    }
  }

  Widget _buildDhikrItems(
    String uid,
    UserCustomContentCategory category,
    CustomContentPlanLimits limits,
  ) {
    return StreamBuilder<List<UserCustomDhikrItem>>(
      stream: _repository.watchDhikrItems(uid: uid, categoryId: category.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyStateView(
            title: 'تعذر تحميل الأذكار',
            message: mapAppErrorToArabic(snapshot.error!),
          );
        }
        final items = snapshot.data ?? const <UserCustomDhikrItem>[];
        return _CustomContentScaffold(
          title: _title,
          planLabel: _planLabel(limits),
          canAdd: items.length < _itemLimit(limits),
          limitLabel: '${items.length}/${_itemLimit(limits)}',
          onAdd: () => _openDhikrEditor(uid: uid, categoryId: category.id),
          emptyTitle: _emptyTitle,
          emptyMessage: _emptyMessage,
          children: items
              .map(
                (item) => _CustomCountCard(
                  title: item.text,
                  subtitle: item.source,
                  repeatCount: item.repeatCount,
                  currentCount: _progress[item.id] ?? 0,
                  canEdit: _canEdit(limits),
                  canDelete: _canDelete(limits),
                  onIncrement: () => _increment(item.id, item.repeatCount),
                  onReset: () => setState(() => _progress[item.id] = 0),
                  onEdit: () => _openDhikrEditor(
                    uid: uid,
                    categoryId: category.id,
                    item: item,
                  ),
                  onDelete: () => _deleteItem(uid, category.id, item.id),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildDuaItems(
    String uid,
    UserCustomContentCategory category,
    CustomContentPlanLimits limits,
  ) {
    return StreamBuilder<List<UserCustomDuaItem>>(
      stream: _repository.watchDuaItems(uid: uid, categoryId: category.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyStateView(
            title: 'تعذر تحميل الأدعية',
            message: mapAppErrorToArabic(snapshot.error!),
          );
        }
        final items = snapshot.data ?? const <UserCustomDuaItem>[];
        return _CustomContentScaffold(
          title: _title,
          planLabel: _planLabel(limits),
          canAdd: items.length < _itemLimit(limits),
          limitLabel: '${items.length}/${_itemLimit(limits)}',
          onAdd: () => _openDuaEditor(uid: uid, categoryId: category.id),
          emptyTitle: _emptyTitle,
          emptyMessage: _emptyMessage,
          children: items
              .map(
                (item) => _CustomCountCard(
                  title: item.title.isEmpty ? item.text : item.title,
                  subtitle: item.text,
                  repeatCount: item.repeatCount,
                  currentCount: _progress[item.id] ?? 0,
                  canEdit: _canEdit(limits),
                  canDelete: _canDelete(limits),
                  onIncrement: () => _increment(item.id, item.repeatCount),
                  onReset: () => setState(() => _progress[item.id] = 0),
                  onEdit: () => _openDuaEditor(
                    uid: uid,
                    categoryId: category.id,
                    item: item,
                  ),
                  onDelete: () => _deleteItem(uid, category.id, item.id),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  int _itemLimit(CustomContentPlanLimits limits) {
    return _isDhikr
        ? limits.maxCustomDhikrItemsPerCategory
        : limits.maxCustomDuaItemsPerCategory;
  }

  bool _canEdit(CustomContentPlanLimits limits) {
    final plan = limits.planId.trim().toLowerCase();
    return plan == 'pro' || plan == 'plus';
  }

  bool _canDelete(CustomContentPlanLimits limits) {
    return limits.planId.trim().toLowerCase() == 'plus';
  }

  String _planLabel(CustomContentPlanLimits limits) {
    final plan = limits.planId.trim().toLowerCase();
    if (plan == 'plus') {
      return 'Plus: 30 عنصر مع تعديل وحذف';
    }
    if (plan == 'pro') {
      return 'Pro: 10 عناصر مع تعديل';
    }
    return 'مجاني: عنصران بدون تعديل أو حذف';
  }

  void _increment(String itemId, int repeatCount) {
    final current = _progress[itemId] ?? 0;
    final next = (current + 1).clamp(0, repeatCount).toInt();
    setState(() => _progress[itemId] = next);
  }

  Future<void> _deleteItem(String uid, String categoryId, String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العنصر؟'),
        content: const Text('سيتم حذف هذا العنصر من قسمك الخاص.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _repository.deleteItem(
        uid: uid,
        type: widget.type,
        categoryId: categoryId,
        itemId: itemId,
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openDhikrEditor({
    required String uid,
    required String categoryId,
    UserCustomDhikrItem? item,
  }) async {
    final result = await _showContentEditor(
      title: item == null ? 'إضافة ذكر' : 'تعديل ذكر',
      textLabel: 'نص الذكر',
      initialText: item?.text ?? '',
      initialSource: item?.source ?? '',
      initialRepeat: item?.repeatCount ?? 33,
    );
    if (result == null) {
      return;
    }
    try {
      if (item == null) {
        await _repository.createDhikrItem(
          uid: uid,
          categoryId: categoryId,
          data: {
            'text': result.text,
            'source': result.source,
            'repeatCount': result.repeatCount,
            'order': DateTime.now().millisecondsSinceEpoch,
            'isActive': true,
          },
        );
      } else {
        await _repository.updateItem(
          uid: uid,
          type: widget.type,
          categoryId: categoryId,
          itemId: item.id,
          updates: {
            'text': result.text,
            'source': result.source,
            'repeatCount': result.repeatCount,
          },
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openDuaEditor({
    required String uid,
    required String categoryId,
    UserCustomDuaItem? item,
  }) async {
    final result = await _showContentEditor(
      title: item == null ? 'إضافة دعاء' : 'تعديل دعاء',
      titleLabel: 'عنوان الدعاء',
      textLabel: 'نص الدعاء',
      initialTitle: item?.title ?? '',
      initialText: item?.text ?? '',
      initialSource: item?.source ?? '',
      initialRepeat: item?.repeatCount ?? 1,
    );
    if (result == null) {
      return;
    }
    try {
      if (item == null) {
        await _repository.createDuaItem(
          uid: uid,
          categoryId: categoryId,
          data: {
            'title': result.title,
            'text': result.text,
            'source': result.source,
            'repeatCount': result.repeatCount,
            'order': DateTime.now().millisecondsSinceEpoch,
            'isActive': true,
          },
        );
      } else {
        await _repository.updateItem(
          uid: uid,
          type: widget.type,
          categoryId: categoryId,
          itemId: item.id,
          updates: {
            'title': result.title,
            'text': result.text,
            'source': result.source,
            'repeatCount': result.repeatCount,
          },
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<_CustomContentFormResult?> _showContentEditor({
    required String title,
    required String textLabel,
    String? titleLabel,
    String initialTitle = '',
    String initialText = '',
    String initialSource = '',
    int initialRepeat = 1,
  }) {
    final titleController = TextEditingController(text: initialTitle);
    final textController = TextEditingController(text: initialText);
    final sourceController = TextEditingController(text: initialSource);
    final repeatController = TextEditingController(text: '$initialRepeat');

    return showModalBottomSheet<_CustomContentFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (titleLabel != null) ...[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: titleLabel),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: textController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(labelText: textLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repeatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'عدد التكرار'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sourceController,
                decoration: const InputDecoration(
                  labelText: 'المصدر أو ملاحظة اختيارية',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  final repeat =
                      int.tryParse(repeatController.text.trim()) ?? 1;
                  Navigator.of(context).pop(
                    _CustomContentFormResult(
                      title: titleController.text.trim(),
                      text: text,
                      source: sourceController.text.trim(),
                      repeatCount: repeat.clamp(1, 10000).toInt(),
                    ),
                  );
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      textController.dispose();
      sourceController.dispose();
      repeatController.dispose();
    });
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mapAppErrorToArabic(error))));
  }
}

class _CustomContentScaffold extends StatelessWidget {
  const _CustomContentScaffold({
    required this.title,
    required this.planLabel,
    required this.canAdd,
    required this.limitLabel,
    required this.onAdd,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String planLabel;
  final bool canAdd;
  final String limitLabel;
  final VoidCallback onAdd;
  final String emptyTitle;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المستخدم: $limitLabel',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: canAdd ? onAdd : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          EmptyStateView(title: emptyTitle, message: emptyMessage)
        else
          ...children,
      ],
    );
  }
}

class _CustomCountCard extends StatelessWidget {
  const _CustomCountCard({
    required this.title,
    required this.subtitle,
    required this.repeatCount,
    required this.currentCount,
    required this.canEdit,
    required this.canDelete,
    required this.onIncrement,
    required this.onReset,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final int repeatCount;
  final int currentCount;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onIncrement;
  final VoidCallback onReset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = currentCount >= repeatCount;
    final hasActions = canEdit || canDelete;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: completed ? null : onIncrement,
        onLongPress: hasActions ? () => _showActions(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (hasActions)
                    Icon(
                      Icons.more_horiz_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: repeatCount <= 0 ? 0 : currentCount / repeatCount,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '$currentCount / $repeatCount',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: completed
                          ? Colors.green.shade700
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onReset, child: const Text('إعادة')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: completed ? null : onIncrement,
                    child: Text(completed ? 'اكتمل' : 'عد'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                if (canDelete) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomContentFormResult {
  const _CustomContentFormResult({
    required this.title,
    required this.text,
    required this.source,
    required this.repeatCount,
  });

  final String title;
  final String text;
  final String source;
  final int repeatCount;
}
