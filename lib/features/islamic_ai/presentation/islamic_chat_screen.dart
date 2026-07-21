import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/services/admob_reward_service.dart';
import '../../../core/services/app_services.dart';
import '../data/firestore_ai_usage_repository.dart';
import '../data/islamic_ai_api_client.dart';
import '../models/islamic_chat_response.dart';

class IslamicChatScreen extends StatefulWidget {
  const IslamicChatScreen({super.key, required this.services, this.apiClient});

  final AppServices services;
  final IslamicAiApiClient? apiClient;

  @override
  State<IslamicChatScreen> createState() => _IslamicChatScreenState();
}

class _IslamicChatScreenState extends State<IslamicChatScreen> {
  late final IslamicAiApiClient _apiClient;
  late final FirestoreAiUsageRepository _usageRepository;
  final AdMobRewardService _rewardService = AdMobRewardService();
  late final bool _ownsApiClient;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'islamicChatInput');
  final List<_ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isLoadingQuota = false;
  bool _isQuotaSheetOpen = false;
  int? _remainingUserMessages;
  int? _dailyLimit;
  String? _currentQuotaPlanId;
  Timer? _quotaResetTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? IslamicAiApiClient();
    _usageRepository = FirestoreAiUsageRepository(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    _ownsApiClient = widget.apiClient == null;
    unawaited(_rewardService.loadRewardedAd());
    _quotaResetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isQuotaDepleted) {
        setState(() {});
      }
    });
    _messages.add(
      const _ChatMessage(
        role: _ChatRole.assistant,
        text:
            'مرحبًا، اكتب سؤالك بهدوء. أقدر أساعدك في فهم آية أو حديث أو عبادة بإرشاد عام من المصادر المتاحة، وليس كبديل عن فتوى من أهل العلم.',
        direction: TextDirection.rtl,
      ),
    );
    _refreshQuota();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    if (_ownsApiClient) {
      _apiClient.close();
    }
    _rewardService.dispose();
    _quotaResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final quota = await _loadQuotaForSend();
    if (!mounted) return;
    if (quota == null) {
      setState(() => _isSending = false);
      return;
    }
    if (!quota.canSend) {
      _addLimitReachedMessage(quota);
      setState(() => _isSending = false);
      unawaited(_openQuotaOptionsSheet());
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          role: _ChatRole.user,
          text: message,
          direction: _textDirectionFor(message),
        ),
      );
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _apiClient.sendMessage(
        message,
        userId: _currentUserId,
        userPlanId: quota.planId,
        dailyLimit: quota.dailyLimit,
        remainingMessages: quota.remainingMessages,
      );

      if (!mounted) return;

      final isOutOfScope = response.intent == 'out_of_scope';
      final cards = isOutOfScope ? const <IslamicChatCard>[] : response.cards;
      final answer = response.hasError
          ? response.errorMessage!
          : response.answer.trim().isEmpty
          ? 'لم تصل إجابة واضحة من الخدمة. حاول صياغة السؤال مرة أخرى.'
          : response.answer;
      final isDailyLimitError =
          response.hasError && _isDailyLimitMessage(answer);
      final updatedQuota = isDailyLimitError
          ? quota.copyWith(usedToday: quota.dailyLimit)
          : response.hasError
          ? quota
          : await _recordSuccessfulMessage(fallbackQuota: quota);

      setState(() {
        _dailyLimit = updatedQuota.dailyLimit;
        _remainingUserMessages = updatedQuota.remainingMessages;
        _currentQuotaPlanId = updatedQuota.planId;
        _messages.add(
          _ChatMessage(
            role: _ChatRole.assistant,
            text: answer,
            direction: _directionFromBackend(response.direction, answer),
            cards: cards,
            remainingUserMessages: updatedQuota.remainingMessages,
            dailyLimit: updatedQuota.dailyLimit,
            showUpgradeAction: isDailyLimitError,
            isError: response.hasError,
          ),
        );
      });
    } on IslamicAiApiException catch (error) {
      if (!mounted) return;
      _addNetworkError(error.message);
    } catch (_) {
      if (!mounted) return;
      _addNetworkError(
        'تعذر الاتصال بالخدمة. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    }
  }

  void _addNetworkError(String message) {
    setState(() {
      _messages.add(
        _ChatMessage(
          role: _ChatRole.assistant,
          text: message,
          direction: TextDirection.rtl,
          isError: true,
        ),
      );
    });
  }

  Future<void> _refreshQuota() async {
    if (_isLoadingQuota) return;
    setState(() => _isLoadingQuota = true);
    try {
      final quota = await _usageRepository.loadQuota(uid: _currentUserId);
      if (!mounted) return;
      setState(() {
        _dailyLimit = quota.dailyLimit;
        _remainingUserMessages = quota.remainingMessages;
        _currentQuotaPlanId = quota.planId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dailyLimit = null;
        _remainingUserMessages = null;
        _currentQuotaPlanId = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuota = false);
      }
    }
  }

  Future<AiUsageQuota?> _loadQuotaForSend() async {
    try {
      final quota = await _usageRepository.loadQuota(uid: _currentUserId);
      if (!mounted) return null;
      setState(() {
        _dailyLimit = quota.dailyLimit;
        _remainingUserMessages = quota.remainingMessages;
        _currentQuotaPlanId = quota.planId;
      });
      return quota;
    } catch (_) {
      if (!mounted) return null;
      _addNetworkError('تعذر قراءة حدود الشات من الحساب. حاول مرة أخرى.');
      return null;
    }
  }

  Future<AiUsageQuota> _recordSuccessfulMessage({
    required AiUsageQuota fallbackQuota,
  }) async {
    try {
      return await _usageRepository.recordMessage(
        uid: _currentUserId,
        resolvedQuota: fallbackQuota,
      );
    } on AiUsageLimitReachedException catch (error) {
      return error.quota;
    } catch (_) {
      return fallbackQuota;
    }
  }

  void _addLimitReachedMessage(AiUsageQuota quota) {
    setState(() {
      _dailyLimit = quota.dailyLimit;
      _remainingUserMessages = 0;
      _currentQuotaPlanId = quota.planId;
      _messages.add(
        _ChatMessage(
          role: _ChatRole.assistant,
          text:
              'انتهى حد الشات اليومي لهذه الباقة. الترقية هنا لرفع الحدود اليومية، وليس لأن الشات مغلق بالكامل.',
          direction: TextDirection.rtl,
          remainingUserMessages: 0,
          dailyLimit: quota.dailyLimit,
          showUpgradeAction: true,
          isError: true,
        ),
      );
    });
    _scrollToBottom();
  }

  bool _isDailyLimitMessage(String message) {
    return message.contains('حد') || message.toLowerCase().contains('limit');
  }

  bool get _isQuotaDepleted =>
      _remainingUserMessages != null && _remainingUserMessages! <= 0;

  int _rewardedAiCreditAmount({String? planId}) {
    switch ((planId ?? _currentQuotaPlanId ?? '').trim().toLowerCase()) {
      case 'plus':
        return 50;
      case 'pro':
        return 30;
      default:
        return 15;
    }
  }

  String get _quotaChipLabel {
    if (_isQuotaDepleted) {
      return 'يتجدد خلال ${_quotaResetCountdownLabel()}';
    }
    if (_remainingUserMessages == null) {
      return 'الرصيد';
    }
    return _dailyLimit == null
        ? 'الرصيد: $_remainingUserMessages'
        : 'الرصيد: $_remainingUserMessages / $_dailyLimit';
  }

  String _quotaResetCountdownLabel() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes ساعة';
  }

  Future<void> _openQuotaOptionsSheet() async {
    if (_isQuotaSheetOpen || !mounted) {
      return;
    }
    _focusNode.unfocus();
    setState(() => _isQuotaSheetOpen = true);
    final rewardAmount = _rewardedAiCreditAmount();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isQuotaDepleted ? 'انتهى رصيد AI المجاني' : 'رصيد AI',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _isQuotaDepleted
                      ? 'الرصيد المجاني يتجدد تلقائيًا خلال ${_quotaResetCountdownLabel()}. يمكنك ترقية الحدود أو مشاهدة إعلان مكافأة لفتح $rewardAmount نقطة مجانية الآن.'
                      : 'يمكنك ترقية الحدود، أو مشاهدة إعلان مكافأة لإضافة $rewardAmount نقطة AI مجانية.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(
                      context,
                    ).pushNamed(AppRouter.subscriptionsRoute);
                  },
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('ترقية الحدود'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_showRewardedAdForAiCredits());
                  },
                  icon: const Icon(Icons.ondemand_video_rounded),
                  label: Text('مشاهدة إعلان وفتح $rewardAmount نقطة'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) {
      setState(() => _isQuotaSheetOpen = false);
    }
  }

  Future<void> _showRewardedAdForAiCredits() async {
    final shown = await _rewardService.showRewardedAd(
      onUserEarnedReward: () {
        unawaited(_grantRewardedAiCredits());
      },
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان غير جاهز حاليا، حاول بعد لحظات')),
      );
    }
  }

  Future<void> _grantRewardedAiCredits() async {
    try {
      final currentQuota = await _usageRepository.loadQuota(
        uid: _currentUserId,
      );
      final rewardAmount = _rewardedAiCreditAmount(planId: currentQuota.planId);
      final quota = await _usageRepository.addRewardedCredits(
        uid: _currentUserId,
        amount: rewardAmount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dailyLimit = quota.dailyLimit;
        _remainingUserMessages = quota.remainingMessages;
        _currentQuotaPlanId = quota.planId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إضافة $rewardAmount نقطة AI مجانية')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إضافة الرصيد المجاني الآن')),
      );
    }
  }

  String get _currentUserId {
    final uid = widget.services.authService.currentSession?.uid.trim();
    if (uid?.isNotEmpty == true) return uid!;
    return 'anonymous-user';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _fillPrompt(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الإسلامي'),
        actions: [
          if (_isLoadingQuota)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_remainingUserMessages != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    _isQuotaDepleted
                        ? Icons.timer_outlined
                        : Icons.auto_awesome_outlined,
                    size: 18,
                  ),
                  label: Text(_quotaChipLabel),
                  onPressed: () => unawaited(_openQuotaOptionsSheet()),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _TypingIndicator();
                  }

                  return _ChatBubble(message: _messages[index]);
                },
              ),
            ),
            if (_messages.length <= 1)
              _PromptSuggestions(onSelected: _fillPrompt),
            if (_isQuotaDepleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_openQuotaOptionsSheet()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'الرصيد خلص. يتجدد خلال ${_quotaResetCountdownLabel()} أو شاهد إعلانًا لفتح ${_rewardedAiCreditAmount()} نقطة.',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withAlpha(40)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        enabled: !_isSending,
                        readOnly: _isQuotaDepleted,
                        minLines: 1,
                        maxLines: 4,
                        textDirection: TextDirection.rtl,
                        textInputAction: TextInputAction.send,
                        onTap: () {
                          if (_isQuotaDepleted) {
                            unawaited(_openQuotaOptionsSheet());
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'اكتب سؤالك هنا',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'إرسال',
                      onPressed: _isSending
                          ? null
                          : _isQuotaDepleted
                          ? () => unawaited(_openQuotaOptionsSheet())
                          : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptSuggestions extends StatelessWidget {
  const _PromptSuggestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _prompts = [
    'كيف يساعدني صلاتي؟',
    'اشرح حديث إنما الأعمال بالنيات ببساطة',
    'اذكر آيات فيها الجنة والنار واشرح الفرق ببساطة',
    'اقترح لي وردًا خفيفًا لهذا الأسبوع',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: _prompts
            .map((prompt) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ActionChip(
                  label: Text(prompt),
                  onPressed: () => onSelected(prompt),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == _ChatRole.user;
    final alignment = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    final backgroundColor = message.isError
        ? scheme.errorContainer
        : isUser
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foregroundColor = message.isError
        ? scheme.onErrorContainer
        : isUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(isUser ? 18 : 6),
              bottomEnd: Radius.circular(isUser ? 6 : 18),
            ),
          ),
          child: Directionality(
            textDirection: message.direction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SelectableText(
                        message.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: foregroundColor,
                          height: 1.55,
                        ),
                      ),
                    ),
                    if (!isUser) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'نسخ الإجابة',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ الإجابة')),
                          );
                        },
                        icon: Icon(
                          Icons.copy_rounded,
                          color: foregroundColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                if (message.remainingUserMessages != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        message.dailyLimit == null
                            ? 'المتبقي اليوم: ${message.remainingUserMessages}'
                            : 'المتبقي اليوم: ${message.remainingUserMessages} / ${message.dailyLimit}',
                      ),
                    ),
                  ),
                ],
                if (message.showUpgradeAction) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.subscriptionsRoute);
                      },
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('ترقية الحدود'),
                    ),
                  ),
                ],
                if (message.cards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...message.cards.map((card) => _IslamicCardView(card: card)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IslamicCardView extends StatelessWidget {
  const _IslamicCardView({required this.card});

  final IslamicChatCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = card.title.isNotEmpty
        ? card.title
        : card.reference.isNotEmpty
        ? card.reference
        : card.kind;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (card.kind.isNotEmpty)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(card.kind),
                ),
              if (card.reference.isNotEmpty)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(card.reference),
                ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (card.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (card.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              card.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
          if (card.source.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(
              card.source,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    required this.direction,
    this.cards = const [],
    this.remainingUserMessages,
    this.dailyLimit,
    this.showUpgradeAction = false,
    this.isError = false,
  });

  final _ChatRole role;
  final String text;
  final TextDirection direction;
  final List<IslamicChatCard> cards;
  final int? remainingUserMessages;
  final int? dailyLimit;
  final bool showUpgradeAction;
  final bool isError;
}

enum _ChatRole { user, assistant }

TextDirection _directionFromBackend(String direction, String fallbackText) {
  if (direction.toLowerCase() == 'ltr') return TextDirection.ltr;
  if (direction.toLowerCase() == 'rtl') return TextDirection.rtl;
  return _textDirectionFor(fallbackText);
}

TextDirection _textDirectionFor(String value) {
  return RegExp(r'[\u0600-\u06ff]').hasMatch(value)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
