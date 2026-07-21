import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/salati_localizations.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/feature_entitlement.dart';
import '../../../core/services/admob_reward_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../../shared/widgets/info_card.dart';
import '../data/firestore_store_repository.dart';
import '../models/store_catalog_item.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.services,
    required this.preferences,
  });

  final AppServices services;
  final AppPreferences preferences;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final FirestoreStoreRepository _storeRepository;
  final AdMobRewardService _rewardService = AdMobRewardService();
  String? _busyFeatureKey;
  bool _isProTrialBusy = false;

  @override
  void initState() {
    super.initState();
    _storeRepository = FirestoreStoreRepository(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    unawaited(_rewardService.loadRewardedAd());
  }

  @override
  void dispose() {
    _rewardService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.services.authService.currentSession;
    final userStream = session == null
        ? Stream<AppUser?>.value(null)
        : widget.services.userProfileRepository.watchCurrentUser(session.uid);
    final entitlementStream = session == null
        ? Stream<List<FeatureEntitlement>>.value(const [])
        : widget.services.entitlementRepository.watchUserEntitlements(
            session.uid,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(SalatiLocalizations.of(context).text('store')),
      ),
      body: StreamBuilder<List<StoreCatalogItem>>(
        stream: _storeRepository.watchActiveItems(),
        builder: (context, itemSnapshot) {
          final items = itemSnapshot.data ?? StoreCatalogDefaults.items;
          if (itemSnapshot.connectionState == ConnectionState.waiting &&
              !itemSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<AppUser?>(
            stream: userStream,
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              final pointsUnavailable =
                  session != null && userSnapshot.hasError;
              return StreamBuilder<List<FeatureEntitlement>>(
                stream: entitlementStream,
                builder: (context, entitlementSnapshot) {
                  return _StoreContent(
                    items: items,
                    user: user,
                    pointsUnavailable: pointsUnavailable,
                    entitlements: entitlementSnapshot.data ?? const [],
                    adsWatched:
                        (user?.proTrialRewardedAdsWatched ??
                                widget.preferences.proTrialRewardedAdsWatched)
                            .clamp(0, 5)
                            .toInt(),
                    busyFeatureKey: _busyFeatureKey,
                    isProTrialBusy: _isProTrialBusy,
                    onPurchase: (item) => _purchaseItem(user: user, item: item),
                    onWatchProAd: user == null
                        ? null
                        : () => _watchProTrialAd(uid: user.uid),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _purchaseItem({
    required AppUser? user,
    required StoreCatalogItem item,
  }) async {
    if (user == null) {
      _showSnack('سجل الدخول أولًا للشراء من المتجر.');
      return;
    }

    if (item.pricePoints > user.points) {
      _showSnack(
        'رصيدك ${user.points} نقطة، والعنصر يحتاج ${item.pricePoints} نقطة.',
      );
      return;
    }

    setState(() => _busyFeatureKey = item.featureKey);
    try {
      final result = await _storeRepository.purchaseWithPoints(
        uid: user.uid,
        item: item,
      );
      if (!mounted) return;
      _showSnack(result.message, isError: !result.success);
    } catch (error) {
      if (!mounted) return;
      _showSnack('تعذر إتمام الشراء: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyFeatureKey = null);
      }
    }
  }

  Future<void> _watchProTrialAd({required String uid}) async {
    if (_isProTrialBusy) {
      return;
    }

    setState(() => _isProTrialBusy = true);
    try {
      if (!_rewardService.isReady) {
        await _rewardService.loadRewardedAd();
        if (!mounted) return;
        _showSnack('الإعلان قيد التحميل. حاول مرة أخرى بعد لحظات.');
        return;
      }

      var earnedReward = false;
      final shown = await _rewardService.showRewardedAd(
        onUserEarnedReward: () {
          earnedReward = true;
        },
      );
      if (!mounted) return;

      if (!shown) {
        _showSnack('الإعلان غير جاهز حاليًا. حاول مرة أخرى بعد لحظات.');
        return;
      }
      if (!earnedReward) {
        _showSnack('يجب إكمال الإعلان حتى يتم احتسابه.');
        return;
      }

      var currentWatched = await widget.preferences
          .incrementProTrialRewardedAdsWatched();
      if (widget.services.firebaseConfigured) {
        currentWatched = await _storeRepository.recordProTrialRewardedAd(
          uid: uid,
        );
        await widget.preferences.setProTrialRewardedAdsWatched(currentWatched);
      }

      if (!mounted) return;
      if (currentWatched >= 5) {
        final result = await _storeRepository.grantProTrialByAds(uid: uid);
        await widget.preferences.markProTrialUnlocked();
        if (!mounted) return;
        _showSnack(result.message, isError: !result.success);
      } else {
        _showSnack('تم احتساب الإعلان: $currentWatched من 5.');
      }
    } catch (error) {
      if (!mounted) return;
      _showSnack('تعذر تشغيل إعلان المكافأة: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProTrialBusy = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _StoreContent extends StatelessWidget {
  const _StoreContent({
    required this.items,
    required this.user,
    required this.pointsUnavailable,
    required this.entitlements,
    required this.busyFeatureKey,
    required this.isProTrialBusy,
    required this.onPurchase,
    required this.onWatchProAd,
    required this.adsWatched,
  });

  final List<StoreCatalogItem> items;
  final AppUser? user;
  final bool pointsUnavailable;
  final List<FeatureEntitlement> entitlements;
  final String? busyFeatureKey;
  final bool isProTrialBusy;
  final ValueChanged<StoreCatalogItem> onPurchase;
  final VoidCallback? onWatchProAd;
  final int adsWatched;

  @override
  Widget build(BuildContext context) {
    final points = pointsUnavailable ? 0 : user?.points ?? 0;
    final activeItems = items
        .where((item) => item.isActive && _isRewardStoreType(item.type))
        .toList();

    return DefaultTabController(
      length: _storeSections.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: InfoCard(
              title: pointsUnavailable
                  ? 'رصيد النقاط غير متاح'
                  : 'رصيدك: $points نقطة',
              body: pointsUnavailable
                  ? 'أعد الاتصال أو حدث الصفحة قبل الشراء. لن يعرض التطبيق رصيدًا وهميًا.'
                  : 'استخدم رصيدك الموثق لفتح الثيمات والخطوط والأصوات والودجت والمكافآت.',
              trailing: Icon(
                pointsUnavailable
                    ? Icons.cloud_off_outlined
                    : Icons.toll_outlined,
              ),
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _storeSections
                  .map(
                    (section) =>
                        Tab(icon: Icon(section.icon), text: section.title),
                  )
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: _storeSections
                  .map((section) {
                    final sectionItems = activeItems
                        .where(
                          (item) =>
                              section.types.contains(_storeType(item.type)),
                        )
                        .toList(growable: false);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                        if (sectionItems.isEmpty)
                          _EmptyStoreSection(section: section)
                        else
                          ...sectionItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StoreItemCard(
                                item: item,
                                isOwned: _isOwned(item),
                                points: points,
                                balanceUnavailable: pointsUnavailable,
                                isBusy: busyFeatureKey == item.featureKey,
                                isProTrialBusy: isProTrialBusy,
                                adsWatched: adsWatched,
                                onPurchase: () => onPurchase(item),
                                onWatchProAd: onWatchProAd,
                              ),
                            ),
                          ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  bool _isOwned(StoreCatalogItem item) {
    if (item.isDefaultFree) {
      return true;
    }
    return entitlements.any(
      (entitlement) =>
          entitlement.isActive && entitlement.featureKey == item.featureKey,
    );
  }

  bool _isRewardStoreType(String type) {
    return !{
      'calendar',
      'paid_feature',
      'pro_trial',
    }.contains(_storeType(type));
  }
}

class _StoreSection {
  const _StoreSection({
    required this.title,
    required this.icon,
    required this.types,
  });

  final String title;
  final IconData icon;
  final List<String> types;
}

const _storeSections = <_StoreSection>[
  _StoreSection(
    title: 'المظهر',
    icon: Icons.palette_outlined,
    types: ['theme', 'font', 'quran_font', 'mushaf_pack'],
  ),
  _StoreSection(
    title: 'الأصوات والودجت',
    icon: Icons.redeem_outlined,
    types: ['adhan_sound', 'widget_unlock'],
  ),
  _StoreSection(
    title: 'الهدايا',
    icon: Icons.card_giftcard_rounded,
    types: ['gift'],
  ),
];

class _EmptyStoreSection extends StatelessWidget {
  const _EmptyStoreSection({required this.section});

  final _StoreSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(section.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'لا توجد منتجات نشطة في هذا القسم حاليًا. أضفها من الداشبورد وستظهر هنا تلقائيًا.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({
    required this.item,
    required this.isOwned,
    required this.points,
    required this.balanceUnavailable,
    required this.isBusy,
    required this.isProTrialBusy,
    required this.adsWatched,
    required this.onPurchase,
    required this.onWatchProAd,
  });

  final StoreCatalogItem item;
  final bool isOwned;
  final int points;
  final bool balanceUnavailable;
  final bool isBusy;
  final bool isProTrialBusy;
  final int adsWatched;
  final VoidCallback onPurchase;
  final VoidCallback? onWatchProAd;

  bool get _isProTrial => _storeType(item.type) == 'pro_trial';
  bool get _isTheme => _storeType(item.type) == 'theme';

  void _showPreview(BuildContext context, StoreCatalogItem item) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final description = item.localizedDescription(localeCode);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('معاينة ${item.localizedTitle(localeCode)}'),
        content: Text(
          description.isNotEmpty
              ? '$description${_storeType(item.type) == 'widget_unlock' && !isOwned ? '\n\nاشتر الودجت أولًا ليصل إلى حسابك مفتاح الفتح.' : ''}'
              : 'المعاينة قيد التجهيز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = points >= item.pricePoints;
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final description = item.localizedDescription(localeCode);
    final summary = item.assetSummary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Icon(_iconForType(item.type))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.localizedTitle(localeCode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PriceChip(item: item),
                    ],
                  ),
                ),
              ],
            ),
            if (_isTheme && item.themeColors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ThemePalettePreview(colors: item.themeColors),
            ],
            if (_storeType(item.type) == 'widget_unlock') ...[
              const SizedBox(height: 12),
              _WidgetProductPreview(type: item.metadataString('widgetType')),
            ],
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(description),
            ],
            if (summary.isNotEmpty && !_isTheme) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isPreviewableType(item.type))
                  OutlinedButton.icon(
                    onPressed: () => _showPreview(context, item),
                    icon: const Icon(Icons.preview_outlined, size: 16),
                    label: const Text('معاينة'),
                  ),
                _buildAction(context, canAfford),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, bool canAfford) {
    if (_isProTrial) {
      return FilledButton.tonalIcon(
        onPressed: isProTrialBusy || onWatchProAd == null ? null : onWatchProAd,
        icon: isProTrialBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_circle_outline),
        label: Text('${adsWatched.clamp(0, 5)}/5 إعلان'),
      );
    }

    if (isOwned) {
      return const FilledButton.tonal(onPressed: null, child: Text('مملوك'));
    }

    if (balanceUnavailable) {
      return const FilledButton(
        onPressed: null,
        child: Text('الرصيد غير متاح'),
      );
    }

    return FilledButton(
      onPressed: isBusy || !canAfford ? null : onPurchase,
      child: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(canAfford ? 'شراء' : 'نقاط غير كافية'),
    );
  }
}

class _ThemePalettePreview extends StatelessWidget {
  const _ThemePalettePreview({required this.colors});

  final Map<String, String> colors;

  @override
  Widget build(BuildContext context) {
    final swatches = const ['primary', 'secondary', 'background', 'surface']
        .map((key) => _parseHexColor(colors[key]))
        .whereType<Color>()
        .toList(growable: false);

    if (swatches.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final color in swatches)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsetsDirectional.only(end: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WidgetProductPreview extends StatelessWidget {
  const _WidgetProductPreview({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final normalized = type?.trim().isEmpty == false
        ? type!.trim()
        : 'next_prayer';
    final data = switch (normalized) {
      'points' => ('النقاط', '128', Icons.toll_outlined),
      'quick_controls' => (
        'تحكم سريع',
        'الصوت  تنبيه  فتح',
        Icons.tune_rounded,
      ),
      'quran_ayah' => (
        'آية اليوم',
        'وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا',
        Icons.menu_book_outlined,
      ),
      'adhkar' => ('الأذكار المفضلة', 'سبحان الله وبحمده', Icons.spa_outlined),
      'hadith' => (
        'الحديث المفضل',
        'إنما الأعمال بالنيات',
        Icons.format_quote_rounded,
      ),
      'today_prayers' => (
        'مواقيت الصلاة',
        'الفجر 05:10  الظهر 12:42',
        Icons.calendar_today_outlined,
      ),
      _ => ('الصلاة القادمة', 'الفجر بعد 18 دقيقة', Icons.mosque_outlined),
    };
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD1E4E0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDCECEA),
                foregroundColor: const Color(0xFF0F766E),
                child: Icon(data.$3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1F2933),
                        fontWeight: FontWeight.w700,
                      ),
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

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.item});

  final StoreCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final isFree = item.pricePoints <= 0;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isFree ? Icons.lock_open_rounded : Icons.toll_outlined,
        size: 18,
      ),
      label: Text(isFree ? 'مجاني' : '${item.pricePoints} نقطة'),
    );
  }
}

IconData _iconForType(String type) {
  switch (_storeType(type)) {
    case 'theme':
      return Icons.palette_outlined;
    case 'font':
    case 'quran_font':
      return Icons.text_fields_rounded;
    case 'mushaf_pack':
      return Icons.menu_book_outlined;
    case 'widget_unlock':
      return Icons.widgets_outlined;
    case 'adhan_sound':
      return Icons.volume_up_outlined;
    case 'calendar':
      return Icons.calendar_month_outlined;
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'paid_feature':
    case 'pro_trial':
      return Icons.workspace_premium_outlined;
    default:
      return Icons.storefront_outlined;
  }
}

bool _isPreviewableType(String type) {
  return const {'adhan_sound', 'widget_unlock'}.contains(_storeType(type));
}

String _storeType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'adhan':
      return 'adhan_sound';
    case 'widget':
      return 'widget_unlock';
    case 'mushaf':
      return 'mushaf_pack';
    case 'gift_card':
      return 'gift';
    default:
      return type.trim().toLowerCase();
  }
}

Color? _parseHexColor(String? value) {
  final normalized = value?.trim().replaceFirst('#', '');
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  if (hex.length != 8) {
    return null;
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
