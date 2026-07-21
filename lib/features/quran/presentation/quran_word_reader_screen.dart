import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/admob_reward_service.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/app_services.dart';
import '../../auth/models/auth_session.dart';
import '../data/local_quran_progress_repository.dart';
import '../data/quran_service.dart';
import 'quran_access.dart';
import 'quran_reader_support.dart';
import 'quran_session_limits.dart';
import 'quran_typography.dart';

class QuranWordReaderScreen extends StatefulWidget {
  const QuranWordReaderScreen({
    super.key,
    required this.repository,
    required this.services,
    required this.preferences,
  });

  final LocalQuranProgressRepository repository;
  final AppServices services;
  final AppPreferences preferences;

  @override
  State<QuranWordReaderScreen> createState() => _QuranWordReaderScreenState();
}

class _QuranWordReaderScreenState extends State<QuranWordReaderScreen>
    with WidgetsBindingObserver {
  static const _fallbackFreeAllowance = QuranSessionLimits.wordFreeAllowance;
  static const _autoRotationPause = Duration(seconds: 30);

  final QuranService _service = QuranService();
  final AdMobRewardService _rewardService = AdMobRewardService();

  QuranPagePayload? _pagePayload;
  QuranVersePayload? _ayahPayload;
  List<QuranWordPayload> _wordPayload = const [];
  int _pageNumber = 1;
  String _ayahKey = '1:1';
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isPressing = false;
  bool _isAutoMode = false;
  bool _autoPausedForRotation = false;
  bool _controlsVisible = true;
  bool _settingsOpen = false;
  bool _adSessionActive = false;
  bool _freeStateLoaded = false;
  bool _freeReadingSessionActive = false;
  String? _errorMessage;
  double _wordsPerMinute = 90;
  double _fontSize = 180;
  double _fontWeightValue = 300;
  Timer? _wordTimer;
  Timer? _saveTimer;
  Timer? _freeTimer;
  Timer? _rotationResumeTimer;
  int _wordIndex = 0;
  DateTime? _lastRemoteSaveAt;
  Duration _freeAllowance = _fallbackFreeAllowance;
  Duration _rewardedAllowance = _fallbackFreeAllowance;
  Duration _freeRemaining = _fallbackFreeAllowance;
  bool? _lastIsLandscape;

  @override
  void initState() {
    super.initState();
    _fontWeightValue = widget.preferences.quranWordFontWeight.toDouble();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_rewardService.loadRewardedAd());
    unawaited(_bootstrapReader());
  }

  Future<void> _bootstrapReader() async {
    await _loadQuranLimits();
    await _loadInitialWords();
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
          mode: QuranReaderMode.word,
          config: config.quranLimits,
        );
        _rewardedAllowance = Duration(
          minutes: config.quranLimits.rewardedWordMinutes,
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
    _wordTimer?.cancel();
    _saveTimer?.cancel();
    _freeTimer?.cancel();
    _rotationResumeTimer?.cancel();
    _isPressing = false;
    _rewardService.dispose();
    _restoreSystemUi();
    unawaited(_saveCurrentProgress(forceRemote: true));
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

  Future<void> _loadInitialWords() async {
    await _loadFreeAndReaderState();
    if (widget.preferences.isKahfGateActiveToday) {
      await _loadWords('18:1');
      return;
    }

    final session = _linkedSession();
    final restored = session == null
        ? await _service.restoreWordReaderProgressFromHive()
        : await _service.restoreWordReaderProgressFromFirestore(session.uid) ??
              await _service.restoreWordReaderProgressFromHive();

    if (restored != null) {
      _wordsPerMinute = restored.wordsPerMinute.clamp(30, 240).toDouble();
      _fontSize = restored.fontSize.clamp(72, 260).toDouble();
    }

    final sharedProgress = await widget.repository.load();
    if (sharedProgress.lastUpdatedAt == null && restored != null) {
      await _loadWords(restored.verseKey, initialWordIndex: restored.wordIndex);
      return;
    }

    await _loadWords(
      QuranReadingPosition(
        surah: sharedProgress.lastReadSurah,
        ayah: sharedProgress.lastReadAyah,
      ).key,
    );
  }

  Future<void> _loadFreeAndReaderState() async {
    final usedSeconds = await _service.restoreWordFreeUsedSecondsFromHive();
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

  Future<void> _loadWords(
    String key, {
    int initialWordIndex = 0,
    bool continuePlayback = false,
  }) async {
    _wordTimer?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPlaying = false;
      _wordIndex = 0;
      _ayahKey = key;
    });

    final payload = await _service.getAyah(key, includeWords: true);
    QuranPagePayload? pagePayload = _pagePayload;
    if (payload != null && pagePayload?.page != payload.page) {
      pagePayload =
          await _service.getPage(payload.page, includeWords: true) ??
          pagePayload;
    }
    if (!mounted) {
      return;
    }

    final words = payload?.words ?? const <QuranWordPayload>[];
    final resolvedWordIndex = words.isEmpty
        ? 0
        : initialWordIndex.clamp(0, words.length - 1).toInt();

    setState(() {
      _ayahPayload = payload;
      _pagePayload = pagePayload;
      _pageNumber = payload?.page ?? _pageNumber;
      _wordPayload = words;
      _wordIndex = resolvedWordIndex;
      _isLoading = false;
      _errorMessage = payload == null ? 'تعذر تحميل الكلمات حاليا.' : null;
    });

    if (payload != null) {
      await _saveCurrentProgress(forceRemote: true);
      await _markKahfCompletedIfNeeded(payload.key);
      if (continuePlayback &&
          mounted &&
          (_isPressing || (_isAutoMode && !_autoPausedForRotation))) {
        _startWordPlayback();
      }
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

  void _startWordPlayback() {
    if (_wordPayload.isEmpty || _isLoading) {
      return;
    }

    _wordTimer?.cancel();
    setState(() {
      _isPlaying = true;
    });
    _schedulePlaybackTimer();
    _scheduleSaveProgress();
  }

  Future<void> _setAutoMode(bool enabled) async {
    _rotationResumeTimer?.cancel();
    if (enabled) {
      setState(() {
        _isAutoMode = true;
        _autoPausedForRotation = false;
        _controlsVisible = false;
        _isPressing = false;
      });
      _lastIsLandscape = true;
      await _enterAutoSystemUi();
      _startWordPlayback();
      return;
    }

    setState(() {
      _isAutoMode = false;
      _autoPausedForRotation = false;
      _controlsVisible = true;
      _isPressing = false;
    });
    _pauseWordPlayback();
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

  void _schedulePlaybackTimer() {
    _wordTimer?.cancel();
    final milliseconds = max(180, (60000 / _wordsPerMinute).round());
    _wordTimer = Timer.periodic(
      Duration(milliseconds: milliseconds),
      _handlePlaybackTick,
    );
  }

  void _handlePlaybackTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    if (_wordIndex >= _wordPayload.length - 1) {
      timer.cancel();
      _wordTimer = null;
      unawaited(_advanceAyah(continuePlayback: _isAutoMode || _isPressing));
      return;
    }

    setState(() {
      _wordIndex += 1;
    });
    _scheduleSaveProgress();
  }

  void _pauseWordPlayback() {
    _wordTimer?.cancel();
    _wordTimer = null;
    setState(() {
      _isPlaying = false;
    });
    unawaited(_saveCurrentProgress(forceRemote: true));
  }

  void _handlePressStart() {
    if (_isAutoMode) {
      if (_autoPausedForRotation) {
        _resumeAutoAfterPause();
      } else {
        unawaited(_setAutoMode(false));
      }
      return;
    }
    _isPressing = true;
    setState(() {
      _controlsVisible = false;
    });
    _startWordPlayback();
  }

  void _handlePressStop() {
    if (_isAutoMode) {
      return;
    }
    _isPressing = false;
    if (_isPlaying) {
      _pauseWordPlayback();
    }
    setState(() {
      _controlsVisible = true;
    });
  }

  void _pauseForRotation() {
    _rotationResumeTimer?.cancel();
    _wordTimer?.cancel();
    _wordTimer = null;
    setState(() {
      _isPlaying = false;
      _autoPausedForRotation = true;
      _controlsVisible = false;
    });
    _rotationResumeTimer = Timer(_autoRotationPause, _resumeAutoAfterPause);
    unawaited(_saveCurrentProgress(forceRemote: true));
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
    _startWordPlayback();
  }

  Future<void> _advanceAyah({bool continuePlayback = false}) async {
    _wordTimer?.cancel();
    _wordTimer = null;
    await _saveCurrentProgress(forceRemote: true);
    final nextKey = await resolveNextAyahKey(
      service: _service,
      currentKey: _ayahPayload?.key ?? _ayahKey,
      currentPagePayload: _pagePayload,
      currentPageNumber: _pageNumber,
    );
    await _loadWords(nextKey, continuePlayback: continuePlayback);
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
      _scheduleFreeUsagePersist();
    });
  }

  void _scheduleFreeUsagePersist() {
    unawaited(_service.addWordFreeUsedSecondsToHive(1));
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

  void _scheduleSaveProgress() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(_saveCurrentProgress());
    });
  }

  Future<void> _saveCurrentProgress({bool forceRemote = false}) async {
    final ayah = _ayahPayload;
    if (ayah == null || ayah.key.isEmpty) {
      return;
    }

    final wordIndex = _wordPayload.isEmpty
        ? 0
        : _wordIndex.clamp(0, _wordPayload.length - 1).toInt();
    await saveReadingPosition(widget.repository, ayah.key);
    await _service.saveWordReaderProgressToHive(
      verseKey: ayah.key,
      wordIndex: wordIndex,
      pageNumber: ayah.page,
      wordsPerMinute: _wordsPerMinute,
      fontKey: widget.preferences.quranFontKey,
      fontSize: _fontSize,
    );

    final session = _linkedSession();
    if (session != null) {
      final now = DateTime.now();
      final shouldThrottle =
          !forceRemote &&
          _lastRemoteSaveAt != null &&
          now.difference(_lastRemoteSaveAt!) < const Duration(seconds: 8);
      if (shouldThrottle) {
        return;
      }
      await _service.saveWordReaderProgressToFirestore(
        session.uid,
        verseKey: ayah.key,
        wordIndex: wordIndex,
        pageNumber: ayah.page,
        wordsPerMinute: _wordsPerMinute,
        fontKey: widget.preferences.quranFontKey,
        fontSize: _fontSize,
      );
      _lastRemoteSaveAt = now;
    }
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

  double get _estimatedCompletionHours => 77430 / _wordsPerMinute / 60;

  TextStyle _wordTextStyle(Color color) {
    final base = TextStyle(
      fontSize: _fontSize,
      fontWeight: quranFontWeightFromValue(_fontWeightValue),
      height: 1.05,
      color: color,
    );
    return quranTextStyle(widget.preferences.quranFontKey, base);
  }

  String _formatRemaining(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _controlsVisible
          ? AppBar(
              title: const Text('المصحف كلمات'),
              actions: [
                IconButton(
                  tooltip: _settingsOpen
                      ? 'إغلاق الإعدادات'
                      : 'إعدادات القراءة',
                  onPressed: () {
                    setState(() => _settingsOpen = !_settingsOpen);
                  },
                  icon: Icon(
                    _settingsOpen ? Icons.close_rounded : Icons.tune_rounded,
                  ),
                ),
              ],
            )
          : null,
      body: QuranAccessBuilder(
        services: widget.services,
        builder: (context, access) {
          final canRead =
              access.hasWordAccess ||
              _adSessionActive ||
              _freeReadingSessionActive ||
              (_freeStateLoaded && _freeRemaining > Duration.zero);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _syncFreeTimer(canRead: canRead, isPaid: access.hasWordAccess);
            }
          });

          if (!_freeStateLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!canRead) {
            return _WordTrialLockedView(
              onShowRewardedAd: _showRewardedAdForAdSession,
            );
          }

          if (_errorMessage != null) {
            return Center(child: Text(_errorMessage!));
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentWord = _wordPayload.isEmpty
              ? '...'
              : _wordPayload[_wordIndex].text;
          final progress = _wordPayload.isEmpty
              ? 0.0
              : (_wordIndex + 1) / _wordPayload.length;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final completionHours = _estimatedCompletionHours;
          final completionDays = completionHours / 24;
          final showReaderHeader =
              _controlsVisible && !_isPlaying && !_isPressing;
          final showControls = showReaderHeader && _settingsOpen;

          return SafeArea(
            child: Column(
              children: [
                if (showReaderHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_ayahPayload?.key ?? _ayahKey} • الصفحة $_pageNumber • ${_wordIndex + 1}/${max(1, _wordPayload.length)}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (!access.hasWordAccess && !_adSessionActive)
                              Text(
                                'المجاني ${_formatRemaining(_freeRemaining)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        if (showControls)
                          SwitchListTile.adaptive(
                            value: _isAutoMode,
                            onChanged: (value) =>
                                unawaited(_setAutoMode(value)),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('الوضع التلقائي'),
                            subtitle: Text(
                              _autoPausedForRotation
                                  ? 'متوقف مؤقتا بعد دوران الجهاز. المس الشاشة للاستئناف.'
                                  : 'يعمل بملء الشاشة ويتوقف عند دوران الجهاز 30 ثانية.',
                            ),
                          ),
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
                LinearProgressIndicator(
                  value: progress,
                  color: _isPlaying ? scheme.primary : scheme.tertiary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => _handlePressStart(),
                    onPointerUp: (_) => _handlePressStop(),
                    onPointerCancel: (_) => _handlePressStop(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: double.infinity,
                      color: _isPlaying
                          ? scheme.primaryContainer.withValues(alpha: 0.24)
                          : scheme.surface,
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_wordIndex == 0 &&
                              shouldShowBasmalahForKey(
                                _ayahPayload?.key ?? _ayahKey,
                              )) ...[
                            Text(
                              quranBasmalahText,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: quranTextStyle(
                                widget.preferences.quranFontKey,
                                theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ) ??
                                    TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currentWord,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              style: _wordTextStyle(
                                _isPlaying ? scheme.primary : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showControls)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.tertiary.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'الختمة بهذه السرعة',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${completionHours.toStringAsFixed(1)} ساعة',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${completionDays.toStringAsFixed(1)} يوم)',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
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
                          min: 72,
                          max: 260,
                          divisions: 47,
                          label: '${_fontSize.round()}',
                          onChanged: (value) {
                            setState(() => _fontSize = value);
                            _scheduleSaveProgress();
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
                              widget.preferences.setQuranWordFontWeight(
                                value.round(),
                              ),
                            );
                          },
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            'السرعة: ${_wordsPerMinute.round()} كلمة/دقيقة',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        Slider(
                          value: _wordsPerMinute,
                          min: 30,
                          max: 240,
                          divisions: 21,
                          label: '${_wordsPerMinute.round()}',
                          onChanged: (value) {
                            setState(() {
                              _wordsPerMinute = value;
                            });
                            if (_isPlaying) {
                              _schedulePlaybackTimer();
                            }
                            _scheduleSaveProgress();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WordTrialLockedView extends StatelessWidget {
  const _WordTrialLockedView({required this.onShowRewardedAd});

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
                Icon(Icons.timer_off_outlined, size: 46, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  'انتهى وقت الكلمات المجاني',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'الخطة المجانية تمنح 20 دقيقة لوضع الكلمات. بعد مشاهدة إعلان اختبار كامل سيتم فتح جلسة كلمات جديدة.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onShowRewardedAd,
                  icon: const Icon(Icons.ondemand_video_rounded),
                  label: const Text('فتح بجلسة إعلان لاحقا'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
