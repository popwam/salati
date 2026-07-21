import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/admob_reward_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../islamic_ai/data/islamic_ai_api_client.dart';
import '../../store/data/firestore_store_repository.dart';
import '../data/local_quran_progress_repository.dart';
import '../../../core/services/salati_widgets_service.dart';
import '../data/quran_service.dart';
import 'quran_access.dart';
import 'quran_reader_support.dart';
import 'quran_session_limits.dart';
import 'quran_share_image.dart';
import 'quran_typography.dart';

class QuranAyahReaderScreen extends StatefulWidget {
  const QuranAyahReaderScreen({
    super.key,
    required this.repository,
    required this.services,
    required this.preferences,
  });

  final LocalQuranProgressRepository repository;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<QuranAyahReaderScreen> createState() => _QuranAyahReaderScreenState();
}

class _AyahTrialLockedView extends StatelessWidget {
  const _AyahTrialLockedView({required this.onShowRewardedAd});

  final VoidCallback onShowRewardedAd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_off_outlined, size: 44, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  'انتهت الفترة المجانية اليومية',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكنك مشاهدة إعلان لفتح مدة إضافية غير متجددة اليوم، أو الترقية لقراءة غير محدودة.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onShowRewardedAd,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('مشاهدة إعلان'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuranAyahReaderScreenState extends State<QuranAyahReaderScreen>
    with WidgetsBindingObserver {
  static const _fallbackFreeAllowance = QuranSessionLimits.ayahFreeAllowance;
  static const _autoRotationPause = Duration(seconds: 30);

  final QuranService _service = QuranService();
  final IslamicAiApiClient _aiClient = IslamicAiApiClient();
  final AdMobRewardService _rewardService = AdMobRewardService();
  late final FirestoreStoreRepository _storeRepository;

  QuranPagePayload? _pagePayload;
  QuranVersePayload? _ayahPayload;
  int _pageNumber = 1;
  String _ayahKey = '1:1';
  bool _isLoading = true;
  bool _isAutoMode = false;
  bool _autoPausedForRotation = false;
  bool _controlsVisible = true;
  bool _settingsOpen = false;
  bool _adSessionActive = false;
  bool _freeStateLoaded = false;
  bool _freeReadingSessionActive = false;
  String _languageCode = 'ar';
  String? _errorMessage;
  double _autoSeconds = 10;
  double _fontSize = 30;
  double _fontWeightValue = 500;
  Timer? _autoTimer;
  Timer? _freeTimer;
  Timer? _rotationResumeTimer;
  Duration _freeAllowance = _fallbackFreeAllowance;
  Duration _rewardedAllowance = _fallbackFreeAllowance;
  Duration _freeRemaining = _fallbackFreeAllowance;
  bool? _lastIsLandscape;
  static const _favoriteAyahsPrefsKey = 'favorite_quran_ayahs_for_widgets';

  final Set<String> _favoriteAyahKeys = <String>{};
  bool _favoritesLoaded = false;
  @override
  void initState() {
    super.initState();
    _storeRepository = FirestoreStoreRepository(
      firebaseConfigured: widget.services.firebaseConfigured,
    );
    _autoSeconds = widget.preferences.quranAyahAutoSeconds
        .clamp(3, 60)
        .toDouble();
    _languageCode = _supportedTranslationCode(
      widget.preferences.quranTranslationLocaleCode,
    );
    _fontSize = widget.preferences.quranAyahFontSize.clamp(20, 60).toDouble();
    _fontWeightValue = widget.preferences.quranAyahFontWeight.toDouble();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_rewardService.loadRewardedAd());
    unawaited(_loadFavoriteAyahs());
    unawaited(_bootstrapReader());
  }

  Future<void> _bootstrapReader() async {
    await _loadQuranLimits();
    await _loadInitialAyah();
  }

  Future<void> _loadQuranLimits() async {
    try {
      final config = await widget.services.appConfigRepository
          .loadOperationalConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _freeAllowance = QuranSessionLimits.configuredFreeAllowance(
          mode: QuranReaderMode.ayah,
          config: config.quranLimits,
        );
        _rewardedAllowance = Duration(
          minutes: config.quranLimits.rewardedAyahMinutes,
        );
        _freeRemaining = _freeAllowance;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _freeAllowance = _fallbackFreeAllowance;
        _rewardedAllowance = _fallbackFreeAllowance;
        _freeRemaining = _fallbackFreeAllowance;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    _freeTimer?.cancel();
    _rotationResumeTimer?.cancel();
    _aiClient.close();
    _rewardService.dispose();
    unawaited(_restoreSystemUi());
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_isAutoMode || !mounted) {
      return;
    }

    final isLandscape = _isLandscapeView();

    if (_lastIsLandscape == isLandscape) {
      return;
    }

    _lastIsLandscape = isLandscape;

    if (!isLandscape && !_autoPausedForRotation) {
      _pauseForRotation();
    }
  }

  Future<void> _loadInitialAyah() async {
    await _loadFreeReaderState();
    if (widget.preferences.isKahfGateActiveToday) {
      await _loadAyah('18:1');
      return;
    }

    final seed = await loadSavedReadingPosition(widget.repository);
    await _loadAyah(seed.key);
  }

  Future<void> _loadFreeReaderState() async {
    final usedSeconds = await _service.restoreAyahFreeUsedSecondsFromHive();
    final remaining = QuranSessionLimits.remaining(
      allowance: _freeAllowance,
      usedSeconds: usedSeconds,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _freeRemaining = remaining;
      _freeReadingSessionActive = QuranSessionLimits.canOpenFreeSession(
        remaining,
      );
      _freeStateLoaded = true;
    });
  }

  String _safeAyahId(String key) {
    return key.replaceAll(':', '_');
  }

  String _surahNameFromNumber(int number) {
    const names = <int, String>{
      1: 'الفاتحة',
      2: 'البقرة',
      3: 'آل عمران',
      4: 'النساء',
      5: 'المائدة',
      6: 'الأنعام',
      7: 'الأعراف',
      8: 'الأنفال',
      9: 'التوبة',
      10: 'يونس',
      11: 'هود',
      12: 'يوسف',
      13: 'الرعد',
      14: 'إبراهيم',
      15: 'الحجر',
      16: 'النحل',
      17: 'الإسراء',
      18: 'الكهف',
      19: 'مريم',
      20: 'طه',
      21: 'الأنبياء',
      22: 'الحج',
      23: 'المؤمنون',
      24: 'النور',
      25: 'الفرقان',
      26: 'الشعراء',
      27: 'النمل',
      28: 'القصص',
      29: 'العنكبوت',
      30: 'الروم',
      31: 'لقمان',
      32: 'السجدة',
      33: 'الأحزاب',
      34: 'سبأ',
      35: 'فاطر',
      36: 'يس',
      37: 'الصافات',
      38: 'ص',
      39: 'الزمر',
      40: 'غافر',
      41: 'فصلت',
      42: 'الشورى',
      43: 'الزخرف',
      44: 'الدخان',
      45: 'الجاثية',
      46: 'الأحقاف',
      47: 'محمد',
      48: 'الفتح',
      49: 'الحجرات',
      50: 'ق',
      51: 'الذاريات',
      52: 'الطور',
      53: 'النجم',
      54: 'القمر',
      55: 'الرحمن',
      56: 'الواقعة',
      57: 'الحديد',
      58: 'المجادلة',
      59: 'الحشر',
      60: 'الممتحنة',
      61: 'الصف',
      62: 'الجمعة',
      63: 'المنافقون',
      64: 'التغابن',
      65: 'الطلاق',
      66: 'التحريم',
      67: 'الملك',
      68: 'القلم',
      69: 'الحاقة',
      70: 'المعارج',
      71: 'نوح',
      72: 'الجن',
      73: 'المزمل',
      74: 'المدثر',
      75: 'القيامة',
      76: 'الإنسان',
      77: 'المرسلات',
      78: 'النبأ',
      79: 'النازعات',
      80: 'عبس',
      81: 'التكوير',
      82: 'الانفطار',
      83: 'المطففين',
      84: 'الانشقاق',
      85: 'البروج',
      86: 'الطارق',
      87: 'الأعلى',
      88: 'الغاشية',
      89: 'الفجر',
      90: 'البلد',
      91: 'الشمس',
      92: 'الليل',
      93: 'الضحى',
      94: 'الشرح',
      95: 'التين',
      96: 'العلق',
      97: 'القدر',
      98: 'البينة',
      99: 'الزلزلة',
      100: 'العاديات',
      101: 'القارعة',
      102: 'التكاثر',
      103: 'العصر',
      104: 'الهمزة',
      105: 'الفيل',
      106: 'قريش',
      107: 'الماعون',
      108: 'الكوثر',
      109: 'الكافرون',
      110: 'النصر',
      111: 'المسد',
      112: 'الإخلاص',
      113: 'الفلق',
      114: 'الناس',
    };

    return names[number] ?? quranSurahName(number);
  }

  String _ayahDisplayName(String key) {
    final parts = key.split(':');

    if (parts.length != 2) {
      return 'آية $key';
    }

    final surahNumber = int.tryParse(parts[0]);
    final ayahNumber = int.tryParse(parts[1]);

    if (surahNumber == null || ayahNumber == null) {
      return 'آية $key';
    }

    return '${_surahNameFromNumber(surahNumber)} $ayahNumber';
  }

  bool _isCurrentAyahFavorite() {
    final payload = _ayahPayload;
    if (payload == null) {
      return false;
    }

    return _favoriteAyahKeys.contains(payload.key);
  }

  Future<void> _loadFavoriteAyahs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoriteAyahsPrefsKey);

    if (raw == null || raw.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _favoritesLoaded = true);
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        _favoriteAyahKeys
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map((item) => item['key'])
                .whereType<String>(),
          );
      }
    } catch (_) {
      _favoriteAyahKeys.clear();
    }

    if (!mounted) return;

    setState(() => _favoritesLoaded = true);
  }

  Future<void> _toggleFavoriteAyah() async {
    final payload = _ayahPayload;

    if (payload == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoriteAyahsPrefsKey);
    final favoriteItems = <Map<String, String>>[];

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final key = item['key'] as String?;
            final title = item['title'] as String?;
            final body = item['body'] as String?;
            final reference = item['reference'] as String?;

            if (key != null &&
                title != null &&
                body != null &&
                reference != null) {
              favoriteItems.add({
                'key': key,
                'title': title,
                'body': body,
                'reference': reference,
              });
            }
          }
        }
      } catch (_) {
        favoriteItems.clear();
      }
    }

    final isAlreadyFavorite = favoriteItems.any(
      (item) => item['key'] == payload.key,
    );

    if (isAlreadyFavorite) {
      favoriteItems.removeWhere((item) => item['key'] == payload.key);
      _favoriteAyahKeys.remove(payload.key);
    } else {
      final ayahName = _ayahDisplayName(payload.key);

      favoriteItems.add({
        'key': payload.key,
        'title': ayahName,
        'body': payload.text,
        'reference': ayahName,
      });

      _favoriteAyahKeys.add(payload.key);
    }

    await prefs.setString(_favoriteAyahsPrefsKey, jsonEncode(favoriteItems));

    final widgetItems = favoriteItems
        .map(
          (item) => FavoriteWidgetItem(
            title: item['title'] ?? 'آية مفضلة',
            body: item['body'] ?? '',
            reference: item['reference'] ?? 'المفضلة',
          ),
        )
        .where((item) => item.body.trim().isNotEmpty)
        .toList(growable: false);

    await SalatiWidgetsService.saveFavoriteAyahsForWidget(ayahs: widgetItems);

    await SalatiWidgetsService.refreshRandomAyahWidget();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyFavorite
              ? 'تم حذف ${_ayahDisplayName(payload.key)} من الآيات المعجبة.'
              : 'تمت إضافة ${_ayahDisplayName(payload.key)} إلى الآيات المعجبة.',
        ),
      ),
    );
  }

  Future<void> _loadAyah(String key) async {
    _autoTimer?.cancel();

    final translationIds = _translationIdsForLanguage(_languageCode);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _ayahKey = key;
    });

    final payload = await _service.getAyah(key, translations: translationIds);

    QuranPagePayload? pagePayload = _pagePayload;

    if (payload != null && pagePayload?.page != payload.page) {
      pagePayload =
          await _service.getPage(payload.page, translations: translationIds) ??
          pagePayload;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _ayahPayload = payload;
      _pagePayload = pagePayload;
      _pageNumber = payload?.page ?? _pageNumber;
      _isLoading = false;
      _errorMessage = payload == null ? 'تعذر تحميل الآية حاليا.' : null;
    });

    if (payload != null) {
      await saveReadingPosition(widget.repository, payload.key);
      await _markKahfCompletedIfNeeded(payload.key);
    }

    if (_isAutoMode && !_autoPausedForRotation) {
      _scheduleAutoAdvance();
    }
  }

  Future<void> _markKahfCompletedIfNeeded(String ayahKey) async {
    if (!widget.preferences.isKahfGateActiveToday ||
        !isKahfCompletionKey(ayahKey)) {
      return;
    }

    await widget.preferences.markKahfCompletedForCurrentWeek();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تسجيل إتمام سورة الكهف. يمكنك متابعة وردك الآن.'),
      ),
    );
  }

  Future<void> _advanceAyah() async {
    final nextKey = await resolveNextAyahKey(
      service: _service,
      currentKey: _ayahPayload?.key ?? _ayahKey,
      currentPagePayload: _pagePayload,
      currentPageNumber: _pageNumber,
    );

    await _loadAyah(nextKey);
  }

  void _changeLanguage(String value) {
    if (_languageCode == value) {
      return;
    }

    setState(() => _languageCode = value);
    unawaited(widget.preferences.setQuranTranslationLocaleCode(value));
    unawaited(_loadAyah(_ayahPayload?.key ?? _ayahKey));
  }

  Future<void> _setAutoMode(bool enabled) async {
    _rotationResumeTimer?.cancel();
    _autoTimer?.cancel();

    if (enabled) {
      setState(() {
        _isAutoMode = true;
        _autoPausedForRotation = false;
        _controlsVisible = false;
      });

      _lastIsLandscape = true;

      await _enterAutoSystemUi();
      _scheduleAutoAdvance();

      return;
    }

    setState(() {
      _isAutoMode = false;
      _autoPausedForRotation = false;
      _controlsVisible = true;
    });

    await _restoreSystemUi();
  }

  Future<void> _enterAutoSystemUi() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreSystemUi() async {
    _lastIsLandscape = null;

    await Future.wait([
      SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    ]);
  }

  bool _isLandscapeView() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize;

    return size.width >= size.height;
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();

    _autoTimer = Timer(
      Duration(milliseconds: (_autoSeconds * 1000).round()),
      _advanceAyah,
    );
  }

  void _pauseForRotation() {
    _autoTimer?.cancel();
    _rotationResumeTimer?.cancel();

    setState(() {
      _autoPausedForRotation = true;
      _controlsVisible = false;
    });

    _rotationResumeTimer = Timer(_autoRotationPause, _resumeAutoAfterPause);
  }

  void _resumeAutoAfterPause() {
    if (!_isAutoMode || !mounted) {
      return;
    }

    _rotationResumeTimer?.cancel();

    setState(() {
      _autoPausedForRotation = false;
      _controlsVisible = false;
    });

    _lastIsLandscape = _isLandscapeView();

    unawaited(_enterAutoSystemUi());
    _scheduleAutoAdvance();
  }

  void _handleReaderTap() {
    if (_isAutoMode) {
      if (_autoPausedForRotation) {
        _resumeAutoAfterPause();
      } else {
        unawaited(_setAutoMode(false));
      }

      return;
    }

    _advanceAyah();
  }

  Future<void> _showTafsirSheet(QuranAccessState access) {
    final payload = _ayahPayload;

    if (payload == null) {
      return Future.value();
    }

    final languageName = _languageName(_languageCode);
    final session = access.session;

    final ayahName = _ayahDisplayName(payload.key);
    final question =
        'اشرح آية $ayahName بلغة $languageName شرحا ميسرا ومختصرا، وبيّن المعنى الروحي أو الديني فقط: ${payload.text}';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: FutureBuilder(
            future: _aiClient.askQuran(
              question,
              userId: session?.uid ?? 'anonymous-user',
              userPlanId: access.currentUser?.effectivePlanId,
            ),
            builder: (context, snapshot) {
              final response = snapshot.data;

              final isLoading =
                  snapshot.connectionState != ConnectionState.done;

              final body = isLoading
                  ? 'جاري تجهيز التفسير...'
                  : response?.hasError == true
                  ? response!.errorMessage!
                  : response?.answer.trim().isNotEmpty == true
                  ? response!.answer
                  : 'لم أجد شرحا كافيا من المصادر الحالية.';

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفسير $ayahName',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoading) const LinearProgressIndicator(),
                    if (isLoading) const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          body,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _shareAyah() async {
    final payload = _ayahPayload;

    if (payload == null) {
      return;
    }

    final text =
        '${payload.text}\n\n(${payload.key})\n\nتطبيق صلاتي\n$salatiShareLink';
    final translationText = payload.translations.isNotEmpty
        ? _cleanTranslation(payload.translations.first.text)
        : '';

    try {
      final approved = await _confirmShareImageCost();
      if (!approved) {
        return;
      }

      final canCreateImage = await _reserveShareImageAccess();
      if (!canCreateImage) {
        return;
      }

      final image = await buildQuranShareImage(
        title: 'آية من القرآن الكريم',
        body: payload.text,
        translation: translationText.isEmpty ? null : translationText,
        reference: _ayahDisplayName(payload.key),
        quranFontKey: widget.preferences.quranFontKey,
      );

      if (!kIsWeb) {
        final imageFile = File(image.path);

        if (!await imageFile.exists()) {
          throw StateError('Share image file does not exist: ${image.path}');
        }

        final imageSize = await imageFile.length();

        if (imageSize <= 0) {
          throw StateError('Share image file is empty: ${image.path}');
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [image],
          text: 'تطبيق صلاتي\n$salatiShareLink',
          subject: 'مشاركة ${_ayahDisplayName(payload.key)}',
          fileNameOverrides: ['salati_ayah_${_safeAyahId(payload.key)}.png'],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[QuranShare] ayah image share failed: $error');
      debugPrint('[QuranShare] stackTrace:\n$stackTrace');

      try {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: 'مشاركة ${_ayahDisplayName(payload.key)}',
          ),
        );
      } catch (fallbackError) {
        debugPrint('[QuranShare] ayah text share failed: $fallbackError');

        await Clipboard.setData(ClipboardData(text: text));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذرت المشاركة، فتم نسخ نص الآية.')),
        );

        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذرت مشاركة الصورة، فتم فتح المشاركة كنص.'),
        ),
      );

      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم فتح المشاركة كصورة.')));
  }

  Future<bool> _confirmShareImageCost() async {
    if (!mounted) {
      return false;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إنشاء صورة للآية'),
          content: const Text(
            'إنشاء الصورة ومشاركتها يحتاج خصم 2 نقطة. لو الرصيد غير كاف يمكنك مشاهدة إعلان لفتح مشاركة واحدة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('إنشاء ومشاركة'),
            ),
          ],
        );
      },
    );
    return approved == true;
  }

  Future<bool> _reserveShareImageAccess() async {
    const imageCost = 2;
    final session = widget.services.authService.currentSession;
    if (widget.services.firebaseConfigured &&
        session != null &&
        session.uid.trim().isNotEmpty) {
      final result = await _storeRepository.spendPoints(
        uid: session.uid,
        amount: imageCost,
        reason: 'quran_share_image',
      );
      if (result.success) {
        return true;
      }
      if (!mounted) {
        return false;
      }
      final wantsAd = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('الرصيد غير كاف'),
            content: Text(
              '${result.message}\nيمكنك مشاهدة إعلان لفتح إنشاء صورة واحدة الآن.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ليس الآن'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('مشاهدة إعلان'),
              ),
            ],
          );
        },
      );
      if (wantsAd != true) {
        return false;
      }
    }

    final shown = await _rewardService.showRewardedAd(
      onUserEarnedReward: () {},
    );
    if (shown) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا توجد نقاط كافية، والإعلان غير جاهز حاليًا.'),
      ),
    );
    return false;
  }

  Future<void> _sendAyahToHomeWidget() async {
    final payload = _ayahPayload;

    if (payload == null) {
      return;
    }

    final ayahName = _ayahDisplayName(payload.key);

    final updated = await SalatiWidgetsService.updateCustomAyahWidget(
      ayahName: ayahName,
      ayahText: payload.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? 'تم تحديث ويدجت $ayahName.'
              : 'Add the Quran widget to your Android home screen, then try again.',
        ),
      ),
    );
  }

  String _languageName(String code) {
    switch (code) {
      case 'de':
        return 'Deutsch';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'id':
        return 'Indonesia';
      case 'tr':
        return 'Türkçe';
      case 'ur':
        return 'اردو';
      case 'ar':
      default:
        return 'العربية';
    }
  }

  String _supportedTranslationCode(String code) {
    return _translationIdsForLanguage(code).isEmpty && code != 'ar'
        ? 'en'
        : code;
  }

  List<int> _translationIdsForLanguage(String code) {
    return switch (code) {
      'en' => const [85],
      'fr' => const [31],
      'es' => const [83],
      'de' => const [27],
      'id' => const [33],
      'tr' => const [52],
      'ur' => const [54],
      _ => const <int>[],
    };
  }

  String _cleanTranslation(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _syncFreeTimer({required bool canRead, required bool isPaid}) {
    final shouldRun = canRead && !isPaid && _freeStateLoaded;
    if (!shouldRun) {
      _freeTimer?.cancel();
      _freeTimer = null;
      return;
    }
    if (_freeTimer != null) {
      return;
    }
    _freeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _freeRemaining <= Duration.zero) {
        _freeTimer?.cancel();
        _freeTimer = null;
        return;
      }
      setState(() {
        _freeRemaining -= const Duration(seconds: 1);
        if (_freeRemaining.isNegative) {
          _freeRemaining = Duration.zero;
        }
        if (_freeRemaining == Duration.zero) {
          _adSessionActive = false;
        }
      });
      unawaited(_service.addAyahFreeUsedSecondsToHive(1));
    });
  }

  Future<void> _showRewardedAdForAdSession() async {
    final shown = await _rewardService.showRewardedAd(
      onUserEarnedReward: _unlockAdSessionPlaceholder,
    );
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان غير جاهز حاليا، حاول بعد لحظات')),
      );
    }
  }

  void _unlockAdSessionPlaceholder() {
    if (!mounted) {
      return;
    }
    setState(() {
      _adSessionActive = true;
      _freeReadingSessionActive = true;
      _freeRemaining = _rewardedAllowance;
    });
  }

  String _formatRemaining(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return QuranAccessBuilder(
      services: widget.services,
      builder: (context, access) {
        final canRead =
            access.hasAyahAccess ||
            _adSessionActive ||
            _freeReadingSessionActive ||
            (_freeStateLoaded && _freeRemaining > Duration.zero);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncFreeTimer(canRead: canRead, isPaid: access.hasAyahAccess);
          }
        });

        return Scaffold(
          appBar: _controlsVisible
              ? AppBar(
                  title: const Text('المصحف آيات'),
                  actions: [
                    IconButton(
                      tooltip: 'مشاركة الآية',
                      onPressed: _shareAyah,
                      icon: const Icon(Icons.share_outlined),
                    ),
                    IconButton(
                      tooltip: _isCurrentAyahFavorite()
                          ? 'إزالة من الآيات المعجبة'
                          : 'إضافة إلى الآيات المعجبة',
                      onPressed: _favoritesLoaded && _ayahPayload != null
                          ? _toggleFavoriteAyah
                          : null,
                      icon: Icon(
                        _isCurrentAyahFavorite()
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: 'استخدام كويدجت',
                      onPressed: _sendAyahToHomeWidget,
                      icon: const Icon(Icons.widgets_outlined),
                    ),
                    IconButton(
                      tooltip: _settingsOpen
                          ? 'إغلاق الإعدادات'
                          : 'إعدادات القراءة',
                      onPressed: () {
                        setState(() => _settingsOpen = !_settingsOpen);
                      },
                      icon: Icon(
                        _settingsOpen
                            ? Icons.close_rounded
                            : Icons.tune_rounded,
                      ),
                    ),
                  ],
                )
              : null,
          floatingActionButton:
              canRead && _ayahPayload != null && _controlsVisible
              ? FloatingActionButton.extended(
                  onPressed: () => _showTafsirSheet(access),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('تفسير'),
                )
              : null,
          body: !_freeStateLoaded
              ? const Center(child: CircularProgressIndicator())
              : !canRead
              ? _AyahTrialLockedView(
                  onShowRewardedAd: _showRewardedAdForAdSession,
                )
              : _buildReaderBody(context, access),
        );
      },
    );
  }

  Widget _buildReaderBody(BuildContext context, QuranAccessState access) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final payload = _ayahPayload;

    final ayahTextStyle = quranTextStyle(
      widget.preferences.quranFontKey,
      (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: _fontSize,
        height: 1.9,
        fontWeight: quranFontWeightFromValue(_fontWeightValue),
      ),
    );

    final translationText = payload?.translations.isNotEmpty == true
        ? _cleanTranslation(payload!.translations.first.text)
        : '';

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          if (_controlsVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          payload == null
                              ? _ayahKey
                              : '${payload.key} • الصفحة ${payload.page}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!access.hasAyahAccess && !_adSessionActive) ...[
                        Text(
                          'المجاني ${_formatRemaining(_freeRemaining)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      DropdownButton<String>(
                        value: _languageCode,
                        items: const [
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text('Français'),
                          ),
                          DropdownMenuItem(value: 'es', child: Text('Español')),
                          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                          DropdownMenuItem(
                            value: 'id',
                            child: Text('Indonesia'),
                          ),
                          DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                          DropdownMenuItem(value: 'ur', child: Text('اردو')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_settingsOpen) ...[
                    SwitchListTile.adaptive(
                      value: _isAutoMode,
                      onChanged: (value) => unawaited(_setAutoMode(value)),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الوضع التلقائي'),
                      subtitle: Text(
                        _autoPausedForRotation
                            ? 'متوقف مؤقتا بعد دوران الجهاز. المس الشاشة للاستئناف.'
                            : 'يعرض آية ثم ينتقل تلقائيا بعد ${_autoSeconds.round()} ثوان.',
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'سرعة الانتقال: ${_autoSeconds.round()} ثوان',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Slider(
                      value: _autoSeconds,
                      min: 3,
                      max: 60,
                      divisions: 19,
                      label: '${_autoSeconds.round()}',
                      onChanged: (value) {
                        setState(() => _autoSeconds = value);

                        unawaited(
                          widget.preferences.setQuranAyahAutoSeconds(value),
                        );

                        if (_isAutoMode && !_autoPausedForRotation) {
                          _scheduleAutoAdvance();
                        }
                      },
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'حجم الخط: ${_fontSize.round()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Slider(
                      value: _fontSize,
                      min: 20,
                      max: 60,
                      divisions: 20,
                      label: '${_fontSize.round()}',
                      onChanged: (value) {
                        setState(() => _fontSize = value);

                        unawaited(
                          widget.preferences.setQuranAyahFontSize(value),
                        );
                      },
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'سمك الخط: ${_fontWeightValue.round()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Slider(
                      value: _fontWeightValue,
                      min: 100,
                      max: 900,
                      divisions: 8,
                      label: '${_fontWeightValue.round()}',
                      onChanged: (value) {
                        setState(() => _fontWeightValue = value);

                        unawaited(
                          widget.preferences.setQuranAyahFontWeight(
                            value.round(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          if (_autoPausedForRotation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'توقف مؤقتا بعد دوران الجهاز. المس الشاشة للاستئناف أو انتظر 30 ثانية.',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleReaderTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                color: _isAutoMode
                    ? scheme.primaryContainer.withValues(alpha: 0.18)
                    : scheme.surface,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (payload != null &&
                          shouldShowBasmalahForKey(payload.key)) ...[
                        Text(
                          quranBasmalahText,
                          style: ayahTextStyle.copyWith(
                            fontSize: (_fontSize * 0.72)
                                .clamp(22.0, 42.0)
                                .toDouble(),
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        payload?.text ?? 'لا توجد آية متاحة الآن.',
                        style: ayahTextStyle,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      if (translationText.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Divider(color: scheme.outlineVariant),
                        const SizedBox(height: 14),
                        Text(
                          translationText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            height: 1.6,
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: _languageCode == 'ur'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                      ] else if (_languageCode != 'ar') ...[
                        const SizedBox(height: 18),
                        Text(
                          'الترجمة غير متاحة لهذه الآية حاليًا، جرّب الإنجليزية أو أعد تحميل الآية.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
