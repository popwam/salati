import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class QuranTranslationPayload {
  const QuranTranslationPayload({
    required this.resourceId,
    required this.text,
    this.resourceName,
  });

  final int resourceId;
  final String text;
  final String? resourceName;
}

class QuranPagePayload {
  const QuranPagePayload({required this.page, required this.verses});

  final int page;
  final List<QuranVersePayload> verses;
}

class QuranVersePayload {
  const QuranVersePayload({
    required this.key,
    required this.page,
    required this.text,
    required this.words,
    this.translations = const [],
  });

  final String key;
  final int page;
  final String text;
  final List<QuranWordPayload> words;
  final List<QuranTranslationPayload> translations;
}

class QuranWordPayload {
  const QuranWordPayload({
    required this.text,
    this.translation,
    this.transliteration,
  });

  final String text;
  final String? translation;
  final String? transliteration;
}

class QuranWordReaderProgress {
  const QuranWordReaderProgress({
    required this.verseKey,
    required this.wordIndex,
    required this.pageNumber,
    required this.wordsPerMinute,
    required this.fontKey,
    required this.fontSize,
  });

  final String verseKey;
  final int wordIndex;
  final int pageNumber;
  final double wordsPerMinute;
  final String fontKey;
  final double fontSize;
}

class QuranService {
  QuranService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.quran.com/api/v4';
  static const _assetPath = 'assets/data/quran.json';
  static const _boxName = 'quran_cache';
  static const _lastPageKey = 'quran_last_page';
  static const _lastVerseKey = 'quran_last_verse_key';
  static const _lastReadAtKey = 'quran_last_read_at';
  static const _wordVerseKey = 'quran_word_verse_key';
  static const _wordIndexKey = 'quran_word_index';
  static const _wordPageKey = 'quran_word_page';
  static const _wordSpeedKey = 'quran_word_speed_wpm';
  static const _wordFontKey = 'quran_word_font_key';
  static const _wordFontSizeKey = 'quran_word_font_size';
  static const _wordUpdatedAtKey = 'quran_word_updated_at';
  static const _ayahFreeUsedSecondsKey = 'quran_ayah_free_used_seconds';
  static const _ayahFreeUsedDateKey = 'quran_ayah_free_used_date';
  static const _wordFreeUsedSecondsKey = 'quran_word_free_used_seconds';
  static const _wordFreeUsedDateKey = 'quran_word_free_used_date';
  static const _cacheSchemaVersion = 'readable_v2';
  static const _verseFields = 'text_imlaei,text_uthmani,verse_key,page_number';
  static const _wordFields = 'text_imlaei,text_uthmani';
  static bool _hiveReady = false;
  static Future<Map<String, dynamic>?>? _assetQuranFuture;

  final http.Client _client;
  Box<dynamic>? _box;

  Future<int> restoreLastReadPageFromHive() async {
    final box = await _ensureBox();
    final page =
        _normalizePageNumber(_intFromDynamic(box.get(_lastPageKey))) ?? 1;
    debugPrint('[QuranProgress] hive restored page=$page');
    return page;
  }

  Future<int?> restoreLastReadPageFromFirestore(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('quran_progress_main')
          .get();
      final page = _normalizePageNumber(
        _intFromDynamic(snapshot.data()?['lastPage']),
      );
      if (page != null) {
        debugPrint('[QuranProgress] firestore restored page=$page');
      }
      return page;
    } catch (error) {
      debugPrint('[QuranProgress] firestore restore failed error=$error');
      return null;
    }
  }

  Future<QuranWordReaderProgress?> restoreWordReaderProgressFromHive() async {
    final box = await _ensureBox();
    final verseKey = box.get(_wordVerseKey) as String?;
    if (verseKey == null || verseKey.trim().isEmpty) {
      return null;
    }
    return QuranWordReaderProgress(
      verseKey: verseKey,
      wordIndex: (_intFromDynamic(box.get(_wordIndexKey)) ?? 0)
          .clamp(0, 500)
          .toInt(),
      pageNumber:
          _normalizePageNumber(_intFromDynamic(box.get(_wordPageKey))) ?? 1,
      wordsPerMinute: _doubleFromDynamic(box.get(_wordSpeedKey)) ?? 90,
      fontKey: box.get(_wordFontKey) as String? ?? 'amiri_quran',
      fontSize: _doubleFromDynamic(box.get(_wordFontSizeKey)) ?? 180,
    );
  }

  Future<QuranWordReaderProgress?> restoreWordReaderProgressFromFirestore(
    String uid,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('quran_progress_main')
          .get();
      final data = snapshot.data();
      final verseKey = data?['wordVerseKey'] as String?;
      if (verseKey == null || verseKey.trim().isEmpty) {
        return null;
      }
      return QuranWordReaderProgress(
        verseKey: verseKey,
        wordIndex: (_intFromDynamic(data?['wordIndex']) ?? 0)
            .clamp(0, 500)
            .toInt(),
        pageNumber:
            _normalizePageNumber(_intFromDynamic(data?['wordPage'])) ?? 1,
        wordsPerMinute: _doubleFromDynamic(data?['wordWordsPerMinute']) ?? 90,
        fontKey: data?['wordFontKey'] as String? ?? 'amiri_quran',
        fontSize: _doubleFromDynamic(data?['wordFontSize']) ?? 180,
      );
    } catch (error) {
      debugPrint('[QuranProgress] word restore failed error=$error');
      return null;
    }
  }

  Future<void> saveLastReadPageToHive(
    int pageNumber, {
    String? verseKey,
  }) async {
    final box = await _ensureBox();
    await box.put(_lastPageKey, pageNumber);
    await box.put(_lastVerseKey, verseKey);
    await box.put(_lastReadAtKey, DateTime.now().toIso8601String());
    debugPrint('[QuranProgress] saved hive page=$pageNumber');
  }

  Future<void> saveLastReadPageToFirestore(
    String uid, {
    required int pageNumber,
    String? verseKey,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('quran_progress_main')
          .set({
            'recordType': 'quran_progress',
            'lastPage': pageNumber,
            'lastVerseKey': verseKey,
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'quran_page_reader',
          }, SetOptions(merge: true));
      debugPrint('[QuranProgress] saved firestore page=$pageNumber');
    } catch (error) {
      debugPrint(
        '[QuranProgress] firestore save failed page=$pageNumber error=$error',
      );
    }
  }

  Future<void> saveWordReaderProgressToHive({
    required String verseKey,
    required int wordIndex,
    required int pageNumber,
    required double wordsPerMinute,
    required String fontKey,
    required double fontSize,
  }) async {
    final box = await _ensureBox();
    await box.put(_wordVerseKey, verseKey);
    await box.put(_wordIndexKey, wordIndex);
    await box.put(_wordPageKey, pageNumber);
    await box.put(_wordSpeedKey, wordsPerMinute);
    await box.put(_wordFontKey, fontKey);
    await box.put(_wordFontSizeKey, fontSize);
    await box.put(_wordUpdatedAtKey, DateTime.now().toIso8601String());
    await box.put(_lastPageKey, pageNumber);
    await box.put(_lastVerseKey, verseKey);
    await box.put(_lastReadAtKey, DateTime.now().toIso8601String());
  }

  Future<void> saveWordReaderProgressToFirestore(
    String uid, {
    required String verseKey,
    required int wordIndex,
    required int pageNumber,
    required double wordsPerMinute,
    required String fontKey,
    required double fontSize,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sync')
          .doc('quran_progress_main')
          .set({
            'recordType': 'quran_progress',
            'lastPage': pageNumber,
            'lastVerseKey': verseKey,
            'wordVerseKey': verseKey,
            'wordIndex': wordIndex,
            'wordPage': pageNumber,
            'wordWordsPerMinute': wordsPerMinute,
            'wordFontKey': fontKey,
            'wordFontSize': fontSize,
            'wordUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': 'quran_word_reader',
          }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('[QuranProgress] word save failed error=$error');
    }
  }

  Future<int> restoreWordFreeUsedSecondsFromHive() async {
    final box = await _ensureBox();
    await _resetFreeUsageIfNeeded(
      box: box,
      secondsKey: _wordFreeUsedSecondsKey,
      dateKey: _wordFreeUsedDateKey,
    );
    return (_intFromDynamic(box.get(_wordFreeUsedSecondsKey)) ?? 0)
        .clamp(0, 86400)
        .toInt();
  }

  Future<int> restoreAyahFreeUsedSecondsFromHive() async {
    final box = await _ensureBox();
    await _resetFreeUsageIfNeeded(
      box: box,
      secondsKey: _ayahFreeUsedSecondsKey,
      dateKey: _ayahFreeUsedDateKey,
    );
    return (_intFromDynamic(box.get(_ayahFreeUsedSecondsKey)) ?? 0)
        .clamp(0, 86400)
        .toInt();
  }

  Future<void> addWordFreeUsedSecondsToHive(int seconds) async {
    if (seconds <= 0) {
      return;
    }
    final box = await _ensureBox();
    final current = await restoreWordFreeUsedSecondsFromHive();
    await box.put(_wordFreeUsedDateKey, _todayKey());
    await box.put(_wordFreeUsedSecondsKey, current + seconds);
  }

  Future<void> addAyahFreeUsedSecondsToHive(int seconds) async {
    if (seconds <= 0) {
      return;
    }
    final box = await _ensureBox();
    final current = await restoreAyahFreeUsedSecondsFromHive();
    await box.put(_ayahFreeUsedDateKey, _todayKey());
    await box.put(_ayahFreeUsedSecondsKey, current + seconds);
  }

  Future<void> _resetFreeUsageIfNeeded({
    required Box<dynamic> box,
    required String secondsKey,
    required String dateKey,
  }) async {
    final storedDate = box.get(dateKey) as String?;
    final today = _todayKey();
    if (storedDate == today) {
      return;
    }
    await box.put(dateKey, today);
    await box.put(secondsKey, 0);
  }

  String _todayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<QuranPageLoadResult> loadPageForReader(int page) async {
    final cacheKey = 'reader_page_${_cacheSchemaVersion}_$page';
    final uri = _buildPageUri(page, translations: const [], includeWords: true);

    _logPage('requestedPage=$page');
    _logPage('url=$uri');

    final assetPayload = await _assetPage(
      page,
      translations: const [],
      includeWords: false,
    );
    if (assetPayload != null) {
      _logPage(
        'parse=success source=asset verses=${assetPayload.verses.length}',
      );
      return QuranPageLoadResult.success(assetPayload);
    }

    final cached = await _read(cacheKey);
    _logPage('cache=${cached == null ? 'miss' : 'hit'} key=$cacheKey');

    try {
      // TODO(server-sync): replace this network fallback with a complete
      // bundled quran.json update pipeline.
      final response = await _client.get(uri);
      _logPage('statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        final payload = _tryParsePageResponse(response.body);
        if (payload != null) {
          await _write(cacheKey, response.body);
          _logPage(
            'parse=success source=network verses=${payload.verses.length}',
          );
          return QuranPageLoadResult.success(payload);
        }

        _logPage(
          'parse=failure source=network body=${_preview(response.body)}',
        );
        final cachedPayload = _tryParseCachedPage(cached);
        if (cachedPayload != null) {
          return QuranPageLoadResult.success(cachedPayload);
        }
        return const QuranPageLoadResult.failure('تعذر قراءة بيانات الصفحة');
      }

      _logPage('httpFailure body=${_preview(response.body)}');
      final cachedPayload = _tryParseCachedPage(cached);
      if (cachedPayload != null) {
        return QuranPageLoadResult.success(cachedPayload);
      }
      return const QuranPageLoadResult.failure(
        'تعذر تحميل الصفحة ولا توجد نسخة محفوظة',
      );
    } catch (error, stackTrace) {
      _logPage('networkError=$error');
      _logPage('networkStack=${stackTrace.toString().split('\n').first}');
      final cachedPayload = _tryParseCachedPage(cached);
      if (cachedPayload != null) {
        return QuranPageLoadResult.success(cachedPayload);
      }
      return const QuranPageLoadResult.failure(
        'تعذر تحميل الصفحة ولا توجد نسخة محفوظة',
      );
    }
  }

  Future<QuranPagePayload?> getPage(
    int page, {
    List<int> translations = const [],
    bool includeWords = false,
  }) async {
    final assetPayload = await _assetPage(
      page,
      translations: translations,
      includeWords: includeWords,
    );
    if (assetPayload != null) {
      return assetPayload;
    }

    final cacheKey = _pageCacheKey(
      page,
      translations: translations,
      includeWords: includeWords,
    );
    final cached = await _read(cacheKey);
    if (cached != null) {
      return _pageFromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    try {
      // TODO(server-sync): keep remote Quran fetch only as a migration fallback
      // until assets/data/quran.json is complete.
      final response = await _client.get(
        _buildPageUri(
          page,
          translations: translations,
          includeWords: includeWords,
        ),
      );
      if (response.statusCode != 200) {
        return null;
      }
      await _write(cacheKey, response.body);
      return _pageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<QuranVersePayload?> getAyah(
    String key, {
    List<int> translations = const [],
    bool includeWords = false,
  }) async {
    final assetPayload = await _assetAyah(
      key,
      translations: translations,
      includeWords: includeWords,
    );
    if (assetPayload != null) {
      return assetPayload;
    }

    final cacheKey = _ayahCacheKey(
      key,
      translations: translations,
      includeWords: includeWords,
    );
    final cached = await _read(cacheKey);
    if (cached != null) {
      return _ayahFromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    try {
      // TODO(server-sync): keep remote Quran fetch only as a migration fallback
      // until assets/data/quran.json is complete.
      final response = await _client.get(
        _buildAyahUri(
          key,
          translations: translations,
          includeWords: includeWords,
        ),
      );
      if (response.statusCode != 200) {
        return null;
      }
      await _write(cacheKey, response.body);
      return _ayahFromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<QuranWordPayload>?> getWords(
    String key, {
    List<int> translations = const [],
  }) async {
    final ayah = await getAyah(
      key,
      translations: translations,
      includeWords: true,
    );
    return ayah?.words;
  }

  Future<QuranPagePayload?> _assetPage(
    int page, {
    required List<int> translations,
    required bool includeWords,
  }) async {
    final asset = await _loadAssetQuran();
    if (asset == null) {
      return null;
    }

    final pages = asset['pages'];
    Map<String, dynamic>? pageMap;
    if (pages is Map) {
      final value = pages['$page'];
      if (value is Map) {
        pageMap = Map<String, dynamic>.from(value);
      }
    } else if (pages is List) {
      for (final value in pages.whereType<Map>()) {
        final map = Map<String, dynamic>.from(value);
        final pageNumber =
            _intFromDynamic(map['page']) ?? _intFromDynamic(map['page_number']);
        if (pageNumber == page) {
          pageMap = map;
          break;
        }
      }
    }

    if (pageMap == null) {
      return null;
    }
    if (includeWords && !_pageHasWords(pageMap)) {
      return null;
    }

    try {
      return _pageFromJson(pageMap);
    } catch (_) {
      return null;
    }
  }

  Future<QuranVersePayload?> _assetAyah(
    String key, {
    required List<int> translations,
    required bool includeWords,
  }) async {
    final asset = await _loadAssetQuran();
    if (asset == null) {
      return null;
    }

    final ayahs = asset['ayahs'];
    if (ayahs is Map) {
      final value = ayahs[key];
      if (value is Map) {
        try {
          final verseMap = Map<String, dynamic>.from(value);
          if (includeWords && !_verseHasWords(verseMap)) {
            return null;
          }
          return _verseFromMap(verseMap);
        } catch (_) {
          return null;
        }
      }
    }

    final pages = asset['pages'];
    final pageValues = pages is Map
        ? pages.values
        : pages is List
        ? pages
        : const [];
    for (final pageValue in pageValues.whereType<Map>()) {
      final verses = pageValue['verses'];
      if (verses is! List) {
        continue;
      }
      for (final verseValue in verses.whereType<Map>()) {
        final verseMap = Map<String, dynamic>.from(verseValue);
        if (verseMap['verse_key'] == key) {
          try {
            if (includeWords && !_verseHasWords(verseMap)) {
              return null;
            }
            return _verseFromMap(verseMap);
          } catch (_) {
            return null;
          }
        }
      }
    }

    return null;
  }

  bool _pageHasWords(Map<String, dynamic> pageMap) {
    final verses = pageMap['verses'];
    if (verses is! List) {
      return false;
    }
    return verses.whereType<Map>().any(
      (verse) => (verse['words'] as List<dynamic>?)?.isNotEmpty == true,
    );
  }

  bool _verseHasWords(Map<String, dynamic> verseMap) {
    return (verseMap['words'] as List<dynamic>?)?.isNotEmpty == true;
  }

  Future<Map<String, dynamic>?> _loadAssetQuran() {
    _assetQuranFuture ??= _readAssetQuran();
    return _assetQuranFuture!;
  }

  static Future<Map<String, dynamic>?> _readAssetQuran() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _read(String key) async {
    final box = await _ensureBox();
    final value = box.get(key);
    return value is String ? value : null;
  }

  Future<void> _write(String key, String value) async {
    final box = await _ensureBox();
    await box.put(key, value);
  }

  Future<Box<dynamic>> _ensureBox() async {
    if (_box != null) {
      return _box!;
    }
    if (!_hiveReady) {
      await Hive.initFlutter();
      _hiveReady = true;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  String _ayahCacheKey(
    String key, {
    required List<int> translations,
    required bool includeWords,
  }) {
    final parts = key.split(':');
    final suffix = _requestCacheSuffix(
      translations: translations,
      includeWords: includeWords,
    );
    if (parts.length != 2) {
      return 'ayah_${key}_$suffix';
    }
    return 'ayah_${parts.first}_${parts.last}_$suffix';
  }

  String _pageCacheKey(
    int page, {
    required List<int> translations,
    required bool includeWords,
  }) {
    return 'page_${page}_${_requestCacheSuffix(translations: translations, includeWords: includeWords)}';
  }

  String _requestCacheSuffix({
    required List<int> translations,
    required bool includeWords,
  }) {
    final normalizedTranslations = [...translations]..sort();
    final segments = <String>[
      _cacheSchemaVersion,
      includeWords ? 'words' : 'text',
      if (normalizedTranslations.isNotEmpty)
        'tr_${normalizedTranslations.join('_')}',
    ];
    return segments.join('_');
  }

  Uri _buildPageUri(
    int page, {
    required List<int> translations,
    required bool includeWords,
  }) {
    return Uri.parse('$_baseUrl/verses/by_page/$page').replace(
      queryParameters: _buildQueryParameters(
        translations: translations,
        includeWords: includeWords,
        perPage: 50,
      ),
    );
  }

  Uri _buildAyahUri(
    String key, {
    required List<int> translations,
    required bool includeWords,
  }) {
    return Uri.parse('$_baseUrl/verses/by_key/$key').replace(
      queryParameters: _buildQueryParameters(
        translations: translations,
        includeWords: includeWords,
      ),
    );
  }

  Map<String, String> _buildQueryParameters({
    required List<int> translations,
    required bool includeWords,
    int? perPage,
  }) {
    final params = <String, String>{'fields': _verseFields};
    if (perPage != null) {
      params['per_page'] = '$perPage';
    }
    if (includeWords) {
      params['words'] = 'true';
      params['word_fields'] = _wordFields;
    }
    if (translations.isNotEmpty) {
      final normalizedTranslations = [...translations]..sort();
      params['translations'] = normalizedTranslations.join(',');
    }
    return params;
  }

  QuranPagePayload? _tryParsePageResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Page response root is not a map.');
      }
      return _pageFromJson(decoded);
    } catch (error) {
      _logPage('parseException=$error');
      return null;
    }
  }

  QuranPagePayload? _tryParseCachedPage(String? cached) {
    if (cached == null) {
      return null;
    }

    final payload = _tryParsePageResponse(cached);
    if (payload == null) {
      _logPage('parse=failure source=cache body=${_preview(cached)}');
      return null;
    }

    _logPage('parse=success source=cache verses=${payload.verses.length}');
    return payload;
  }

  void _logPage(String message) {
    debugPrint('[QuranPage] $message');
  }

  String _preview(String body) {
    final normalized = body.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    return normalized.substring(0, normalized.length.clamp(0, 300));
  }

  int? _normalizePageNumber(int? value) {
    if (value == null || value < 1 || value > 604) {
      return null;
    }
    return value;
  }

  int? _intFromDynamic(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value');
  }

  double? _doubleFromDynamic(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  QuranPagePayload _pageFromJson(Map<String, dynamic> map) {
    final verseItems = map['verses'];
    if (verseItems is! List<dynamic>) {
      throw const FormatException('Missing verses array in page response.');
    }

    final verses = verseItems
        .whereType<Map<String, dynamic>>()
        .map(_verseFromMap)
        .toList();
    if (verses.isEmpty) {
      throw const FormatException('Empty verses array in page response.');
    }
    final page = verses.first.page;
    return QuranPagePayload(page: page, verses: verses);
  }

  QuranVersePayload _ayahFromJson(Map<String, dynamic> map) {
    final verse = map['verse'] as Map<String, dynamic>? ?? const {};
    return _verseFromMap(verse);
  }

  QuranVersePayload _verseFromMap(Map<String, dynamic> map) {
    final words = (map['words'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((word) => word['char_type_name'] == 'word')
        .map(
          (word) => QuranWordPayload(
            text:
                word['text_imlaei'] as String? ??
                word['text_uthmani'] as String? ??
                word['text'] as String? ??
                '',
            translation:
                (word['translation'] as Map<String, dynamic>?)?['text']
                    as String?,
            transliteration:
                (word['transliteration'] as Map<String, dynamic>?)?['text']
                    as String?,
          ),
        )
        .toList();

    final translations = (map['translations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => QuranTranslationPayload(
            resourceId: (item['resource_id'] as num?)?.toInt() ?? 0,
            text: item['text'] as String? ?? '',
            resourceName: item['resource_name'] as String?,
          ),
        )
        .where((item) => item.text.isNotEmpty)
        .toList();

    final verseText =
        map['text_imlaei'] as String? ?? map['text_uthmani'] as String?;
    final text = verseText?.trim().isNotEmpty == true
        ? verseText!.trim()
        : words
              .map((word) => word.text)
              .where((part) => part.isNotEmpty)
              .join(' ');
    return QuranVersePayload(
      key: map['verse_key'] as String? ?? '',
      page: (map['page_number'] as num?)?.toInt() ?? 1,
      text: text,
      words: words,
      translations: translations,
    );
  }
}

class QuranPageLoadResult {
  const QuranPageLoadResult.success(this.payload) : errorMessage = null;

  const QuranPageLoadResult.failure(this.errorMessage) : payload = null;

  final QuranPagePayload? payload;
  final String? errorMessage;
}
