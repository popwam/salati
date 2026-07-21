import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../auth/models/auth_session.dart';
import '../../islamic_ai/data/islamic_ai_api_client.dart';
import '../../../shared/widgets/info_card.dart';
import '../data/local_quran_progress_repository.dart';
import '../data/quran_service.dart';
import 'quran_reader_support.dart';
import 'quran_share_image.dart';
import 'quran_typography.dart';

class QuranPageReaderScreen extends StatefulWidget {
  const QuranPageReaderScreen({
    super.key,
    required this.repository,
    required this.services,
    required this.preferences,
  });

  final LocalQuranProgressRepository repository;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<QuranPageReaderScreen> createState() => _QuranPageReaderScreenState();
}

class _QuranPageReaderScreenState extends State<QuranPageReaderScreen> {
  static const _mushafFontKeys = {'amiri_quran', 'amiri', 'naskh'};

  final QuranService _service = QuranService();
  final IslamicAiApiClient _aiClient = IslamicAiApiClient();
  late final PageController _pageController;

  QuranPagePayload? _pagePayload;
  int _pageNumber = 1;
  bool _isLoading = true;
  String? _errorMessage;
  double _fontSize = 28;
  double _fontWeightValue = 400;
  String _quranFontKey = 'amiri_quran';
  bool _fullScreen = false;
  String? _highlightVerseKey;
  Timer? _highlightTimer;
  final List<GestureRecognizer> _verseRecognizers = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final savedFontKey = widget.preferences.quranFontKey;
    _quranFontKey = _mushafFontKeys.contains(savedFontKey)
        ? savedFontKey
        : 'amiri_quran';
    _fontSize = widget.preferences.quranPageFontSize.clamp(20, 48).toDouble();
    _fontWeightValue = widget.preferences.quranPageFontWeight
        .clamp(100, 900)
        .toDouble();
    _fullScreen = widget.preferences.quranPageFullScreen;
    _loadInitialPage();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _disposeVerseRecognizers();
    _aiClient.close();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPage() async {
    if (widget.preferences.isKahfGateActiveToday) {
      await _loadPage(293);
      return;
    }

    final session = _linkedSession();
    final restoredPage = session == null
        ? await _service.restoreLastReadPageFromHive()
        : await _service.restoreLastReadPageFromFirestore(session.uid) ??
              await _service.restoreLastReadPageFromHive();

    final sharedProgress = await widget.repository.load();
    if (sharedProgress.lastUpdatedAt != null) {
      final seedPayload = await _service.getAyah(
        QuranReadingPosition(
          surah: sharedProgress.lastReadSurah,
          ayah: sharedProgress.lastReadAyah,
        ).key,
      );
      if (seedPayload != null) {
        await _loadPage(seedPayload.page);
        return;
      }
    }

    await _loadPage(restoredPage);
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pageNumber = page;
    });

    final result = await _service.loadPageForReader(page);
    if (!mounted) {
      return;
    }

    final payload = result.payload;
    final hasMismatch = payload != null && payload.page != page;
    if (payload == null) {
      debugPrint('[QuranProgress] skip save because payload is null');
    }
    if (hasMismatch) {
      debugPrint('[QuranProgress] skip save because payload.page mismatch');
    }

    final resolvedPayload = hasMismatch ? null : payload;
    final resolvedError = hasMismatch
        ? 'تعذر قراءة بيانات الصفحة'
        : result.errorMessage;

    setState(() {
      _pagePayload = resolvedPayload;
      _pageNumber = resolvedPayload?.page ?? page;
      _isLoading = false;
      _errorMessage = resolvedError;
    });

    if (resolvedPayload == null) {
      return;
    }

    final verseKey = resolvedPayload.verses.isEmpty
        ? null
        : resolvedPayload.verses.first.key;
    if (verseKey != null) {
      await saveReadingPosition(widget.repository, verseKey);
      await widget.preferences.setQuranPageBookmarkVerseKey(verseKey);
    }
    await _service.saveLastReadPageToHive(
      resolvedPayload.page,
      verseKey: verseKey,
    );

    final session = _linkedSession();
    if (session != null) {
      await _service.saveLastReadPageToFirestore(
        session.uid,
        pageNumber: resolvedPayload.page,
        verseKey: verseKey,
      );
    }

    _syncPageControllerTo(resolvedPayload.page);
    _showSavedVerseHighlightIfNeeded(resolvedPayload);
    await _markKahfCompletedIfNeeded(resolvedPayload.page);
  }

  Future<void> _markKahfCompletedIfNeeded(int page) async {
    if (!widget.preferences.isKahfGateActiveToday ||
        !isKahfCompletionPage(page)) {
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

  Future<void> _saveVersePosition(QuranVersePayload verse) async {
    await saveReadingPosition(widget.repository, verse.key);
    await widget.preferences.setQuranPageBookmarkVerseKey(verse.key);
    await _service.saveLastReadPageToHive(verse.page, verseKey: verse.key);

    final session = _linkedSession();
    if (session != null) {
      await _service.saveLastReadPageToFirestore(
        session.uid,
        pageNumber: verse.page,
        verseKey: verse.key,
      );
    }

    _highlightVerse(verse.key);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم حفظ موضع الآية ${verse.key}.')));
  }

  void _showSavedVerseHighlightIfNeeded(QuranPagePayload payload) {
    final savedVerseKey = widget.preferences.quranPageBookmarkVerseKey;
    if (savedVerseKey == null) return;
    final existsOnPage = payload.verses.any(
      (verse) => verse.key == savedVerseKey,
    );
    if (existsOnPage) {
      _highlightVerse(savedVerseKey);
    }
  }

  void _highlightVerse(String verseKey) {
    _highlightTimer?.cancel();
    if (!mounted) return;
    setState(() => _highlightVerseKey = verseKey);
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _highlightVerseKey == verseKey) {
        setState(() => _highlightVerseKey = null);
      }
    });
  }

  void _disposeVerseRecognizers() {
    for (final recognizer in _verseRecognizers) {
      recognizer.dispose();
    }
    _verseRecognizers.clear();
  }

  Future<void> _sharePage() async {
    final payload = _pagePayload;
    if (payload == null) {
      return;
    }
    final pageText = _formatPageText(payload.verses);
    final text =
        'صفحة ${payload.page}\n\n$pageText\n\nتطبيق صلاتي\n$salatiShareLink';
    final imageBody = pageText;
    try {
      final image = await buildQuranShareImage(
        title: 'صفحة ${payload.page} من القرآن الكريم',
        body: imageBody,
        reference: 'page_${payload.page}',
        quranFontKey: _quranFontKey,
        filePrefix: 'salati_quran_page',
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
          subject: 'مشاركة صفحة ${payload.page}',
          fileNameOverrides: ['salati_page_${payload.page}.png'],
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[QuranShare] page image share failed: $error');
      debugPrint('[QuranShare] ${stackTrace.toString().split('\n').first}');
      try {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'مشاركة صفحة ${payload.page}'),
        );
      } catch (fallbackError) {
        debugPrint('[QuranShare] page text share failed: $fallbackError');
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذرت المشاركة، فتم نسخ نص الصفحة.')),
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

  AuthSession? _linkedSession() {
    final session = widget.services.authService.currentSession;
    if (!widget.services.firebaseConfigured ||
        session == null ||
        session.isAnonymous) {
      return null;
    }
    return session;
  }

  void _syncPageControllerTo(int page) {
    if (!_pageController.hasClients) {
      return;
    }
    final targetPage = page - 1;
    final currentPage = _pageController.page?.round();
    if (currentPage == targetPage) {
      return;
    }
    _pageController.jumpToPage(targetPage);
  }

  Future<void> _showPageTafsirSheet() {
    final payload = _pagePayload;
    if (payload == null || payload.verses.isEmpty) {
      return Future.value();
    }

    final versesText = payload.verses
        .map(
          (verse) =>
              '${quranAyahDisplayName(verse.key)}: ${_resolveVerseText(verse)}',
        )
        .join('\n');
    final question =
        'اشرح آيات صفحة ${payload.page} شرحا عربيا ميسرا ومختصرا، وركز على المعنى الديني والروحي فقط:\n$versesText';
    final session = _linkedSession();

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
            ),
            builder: (context, snapshot) {
              final response = snapshot.data;
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              final body = isLoading
                  ? 'جاري تجهيز شرح الصفحة...'
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
                      'تفسير الصفحة ${payload.page}',
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

  @override
  Widget build(BuildContext context) {
    final currentVerses = _pagePayload?.verses ?? const <QuranVersePayload>[];

    return Scaffold(
      appBar: _fullScreen
          ? null
          : AppBar(
              title: const Text('المصحف'),
              actions: [
                IconButton(
                  onPressed: _showPageSettingsSheet,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'إعدادات الصفحة',
                ),
              ],
            ),
      floatingActionButton: _pagePayload == null
          ? null
          : FloatingActionButton(
              onPressed: _fullScreen
                  ? _showPageSettingsSheet
                  : _showPageTafsirSheet,
              tooltip: _fullScreen ? 'إعدادات الصفحة' : 'تفسير الصفحة',
              child: Icon(
                _fullScreen ? Icons.tune_rounded : Icons.menu_book_outlined,
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_fullScreen) _buildReaderToolbar(context),
            Expanded(child: _buildReaderBody(context, currentVerses)),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'الصفحة $_pageNumber من 604',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _pageNumber > 1
                ? () => _loadPage(_pageNumber - 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'الصفحة السابقة',
          ),
          IconButton(
            onPressed: _pageNumber < 604
                ? () => _loadPage(_pageNumber + 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'الصفحة التالية',
          ),
          IconButton(
            onPressed: _showPageTafsirSheet,
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'تفسير الصفحة',
          ),
          IconButton(
            onPressed: _sharePage,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'مشاركة الصفحة',
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody(
    BuildContext context,
    List<QuranVersePayload> currentVerses,
  ) {
    final horizontalPadding = _fullScreen ? 8.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        _fullScreen ? 6 : 4,
        horizontalPadding,
        _fullScreen ? 6 : 16,
      ),
      child: Column(
        children: [
          if (_errorMessage != null)
            Expanded(
              child: Center(
                child: InfoCard(title: 'تعذر التحميل', body: _errorMessage!),
              ),
            )
          else if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_pagePayload == null)
            const Expanded(
              child: Center(
                child: InfoCard(
                  title: 'تعذر التحميل',
                  body: 'تعذر تحميل الصفحة ولا توجد نسخة محفوظة',
                ),
              ),
            )
          else if (currentVerses.isEmpty)
            const Expanded(
              child: Center(
                child: InfoCard(
                  title: 'تعذر القراءة',
                  body: 'تعذر قراءة بيانات الصفحة',
                ),
              ),
            )
          else
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 604,
                onPageChanged: (index) {
                  final nextPage = index + 1;
                  if (nextPage != _pageNumber) {
                    _loadPage(nextPage);
                  }
                },
                itemBuilder: (context, index) {
                  final page = index + 1;
                  if (_pagePayload?.page != page) {
                    return _PagePendingPanel(page: page);
                  }
                  return _MushafPagePanel(
                    page: page,
                    verses: currentVerses,
                    quranFontKey: _quranFontKey,
                    fontSize: _fontSize,
                    fontWeightValue: _fontWeightValue,
                    fullScreen: _fullScreen,
                    buildVerseSpans: _buildVerseSpans,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showPageSettingsSheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إعدادات صفحة المصحف',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _quranFontKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Mushaf font',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'amiri_quran',
                          child: Text('Amiri Quran'),
                        ),
                        DropdownMenuItem(value: 'amiri', child: Text('Amiri')),
                        DropdownMenuItem(value: 'naskh', child: Text('Naskh')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setSheetState(() => _quranFontKey = value);
                        setState(() => _quranFontKey = value);
                        unawaited(widget.preferences.setQuranFontKey(value));
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'حجم الخط: ${_fontSize.round()}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: _fontSize,
                      min: 20,
                      max: 48,
                      divisions: 28,
                      label: '${_fontSize.round()}',
                      onChanged: (value) {
                        setSheetState(() => _fontSize = value);
                        setState(() => _fontSize = value);
                        widget.preferences.setQuranPageFontSize(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سمك الخط: ${_fontWeightValue.round()}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: _fontWeightValue,
                      min: 100,
                      max: 900,
                      divisions: 8,
                      label: '${_fontWeightValue.round()}',
                      onChanged: (value) {
                        final rounded = (value / 100).round() * 100;
                        setSheetState(
                          () => _fontWeightValue = rounded.toDouble(),
                        );
                        setState(() => _fontWeightValue = rounded.toDouble());
                        widget.preferences.setQuranPageFontWeight(rounded);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _fullScreen,
                      title: const Text('ملء الشاشة'),
                      subtitle: const Text(
                        'يعرض الصفحة في المنتصف بأكبر مساحة ممكنة.',
                      ),
                      onChanged: (value) {
                        setSheetState(() => _fullScreen = value);
                        setState(() => _fullScreen = value);
                        widget.preferences.setQuranPageFullScreen(value);
                      },
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

  List<InlineSpan> _buildVerseSpans({
    required BuildContext context,
    required List<QuranVersePayload> verses,
    required TextStyle textStyle,
  }) {
    _disposeVerseRecognizers();
    final spans = <InlineSpan>[];

    for (final verse in verses) {
      if (shouldShowBasmalahForKey(verse.key)) {
        spans.add(
          TextSpan(
            text: '\n$quranBasmalahText\n',
            style: textStyle.copyWith(
              fontSize: ((textStyle.fontSize ?? _fontSize) * 0.76)
                  .clamp(20.0, 38.0)
                  .toDouble(),
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
      final isHighlighted = verse.key == _highlightVerseKey;
      final recognizer = LongPressGestureRecognizer(
        duration: const Duration(seconds: 5),
      )..onLongPress = () => _saveVersePosition(verse);
      _verseRecognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: _resolveVerseText(verse),
          recognizer: recognizer,
          style: isHighlighted
              ? textStyle.copyWith(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.72),
                )
              : textStyle,
        ),
      );
      spans.add(const TextSpan(text: ' '));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _AyahNumberMark(
            number: _verseNumberFromKey(verse.key),
            size: textStyle.fontSize ?? _fontSize,
            highlighted: isHighlighted,
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    return spans;
  }
}

class _MushafPagePanel extends StatelessWidget {
  const _MushafPagePanel({
    required this.page,
    required this.verses,
    required this.quranFontKey,
    required this.fontSize,
    required this.fontWeightValue,
    required this.fullScreen,
    required this.buildVerseSpans,
  });

  final int page;
  final List<QuranVersePayload> verses;
  final String quranFontKey;
  final double fontSize;
  final double fontWeightValue;
  final bool fullScreen;
  final List<InlineSpan> Function({
    required BuildContext context,
    required List<QuranVersePayload> verses,
    required TextStyle textStyle,
  })
  buildVerseSpans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = quranTextStyle(
      quranFontKey,
      TextStyle(
        color: scheme.onSurface,
        fontSize: fontSize,
        height: 2.05,
        fontWeight: quranFontWeightFromValue(fontWeightValue),
      ),
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.secondaryContainer.withValues(alpha: 0.20),
                    scheme.surface,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  fullScreen ? 14 : 18,
                  fullScreen ? 16 : 18,
                  fullScreen ? 14 : 18,
                  fullScreen ? 18 : 22,
                ),
                child: Column(
                  children: [
                    Text(
                      'صفحة $page',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 14),
                    if (verses.isEmpty)
                      Text(
                        'تعذر قراءة بيانات الصفحة.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                        textDirection: TextDirection.rtl,
                      )
                    else
                      RichText(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        text: TextSpan(
                          style: textStyle,
                          children: buildVerseSpans(
                            context: context,
                            verses: verses,
                            textStyle: textStyle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PagePendingPanel extends StatelessWidget {
  const _PagePendingPanel({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'انتقل إلى الصفحة $page ليتم تحميل نصها.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _AyahNumberMark extends StatelessWidget {
  const _AyahNumberMark({
    required this.number,
    required this.size,
    required this.highlighted,
  });

  final int number;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markSize = (size * 1.08).clamp(24.0, 48.0);
    final numberText = _toArabicDigits(number.toString());

    return SizedBox(
      width: markSize,
      height: markSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            'assets/icon/aya.svg',
            width: markSize,
            height: markSize,
            colorFilter: ColorFilter.mode(
              highlighted ? scheme.primary : scheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: markSize * 0.02),
            child: Text(
              numberText,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: highlighted ? scheme.primary : scheme.onSurface,
                fontSize: (markSize * 0.26).clamp(8.0, 13.0),
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _resolveVerseText(QuranVersePayload verse) {
  if (verse.text.trim().isNotEmpty) {
    return verse.text.trim();
  }

  return verse.words
      .map((word) => word.text.trim())
      .where((word) => word.isNotEmpty)
      .join(' ');
}

String _formatPageText(List<QuranVersePayload> verses) {
  return verses
      .map((verse) => '${_resolveVerseText(verse)} ${_plainAyahMarker(verse)}')
      .join(' ');
}

String _plainAyahMarker(QuranVersePayload verse) {
  return '۝${_toArabicDigits(_verseNumberFromKey(verse.key).toString())}';
}

int _verseNumberFromKey(String key) {
  final parts = key.split(':');
  if (parts.length != 2) return 0;
  return int.tryParse(parts.last) ?? 0;
}

String _toArabicDigits(String value) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  return value.split('').map((char) {
    final index = western.indexOf(char);
    return index == -1 ? char : eastern[index];
  }).join();
}
