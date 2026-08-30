import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum IslamicProviderKind { qibla, mosques, hadith, reciters, lessons }

class IslamicProviderItem {
  const IslamicProviderItem({
    required this.title,
    this.subtitle = '',
    this.url,
  });

  final String title;
  final String subtitle;
  final String? url;
}

class IslamicProviderResult {
  const IslamicProviderResult({
    required this.title,
    required this.source,
    required this.items,
    this.direction,
  });

  final String title;
  final String source;
  final List<IslamicProviderItem> items;
  final double? direction;
}

class IslamicContentProvider {
  IslamicContentProvider({http.Client? client})
    : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 25);
  static const youtubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const youtubePlaylistId = String.fromEnvironment(
    'YOUTUBE_PLAYLIST_ID',
  );

  final http.Client _client;

  Future<IslamicProviderResult> load(IslamicProviderKind kind) {
    return switch (kind) {
      IslamicProviderKind.qibla => _loadQibla(),
      IslamicProviderKind.mosques => _loadMosques(),
      IslamicProviderKind.hadith => _loadHadith(),
      IslamicProviderKind.reciters => _loadReciters(),
      IslamicProviderKind.lessons => _loadLessons(),
    };
  }

  Future<Position> _position() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const IslamicProviderException(
        'يلزم السماح بالوصول إلى الموقع لتشغيل هذه الميزة.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<IslamicProviderResult> _loadQibla() async {
    final position = await _position();
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/qibla/'
      '${position.latitude}/${position.longitude}',
    );
    final json = await _getJson(uri);
    final data = _map(json['data']);
    final direction = (data['direction'] as num?)?.toDouble();
    if (direction == null) {
      throw const IslamicProviderException('تعذر قراءة اتجاه القبلة.');
    }
    return IslamicProviderResult(
      title: 'اتجاه القبلة',
      source: 'AlAdhan API',
      direction: direction,
      items: [
        IslamicProviderItem(
          title: '${direction.toStringAsFixed(1)}° من الشمال',
          subtitle: 'حرّك الهاتف حتى يشير السهم إلى الدرجة الموضحة.',
        ),
      ],
    );
  }

  Future<IslamicProviderResult> _loadMosques() async {
    final position = await _position();
    final query =
        '[out:json][timeout:25];'
        'nwr["amenity"="place_of_worship"]["religion"="muslim"]'
        '(around:7000,${position.latitude},${position.longitude});'
        'out center 30;';
    final response = await _client
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
            'User-Agent': 'SalatiApp/1.0.1',
          },
          body: {'data': query},
        )
        .timeout(_timeout);
    final json = _decode(response);
    final elements = (json['elements'] as List?) ?? const [];
    final items = elements
        .whereType<Map>()
        .map((element) {
          final tags = _map(element['tags']);
          final name = (tags['name:ar'] ?? tags['name'] ?? 'مسجد قريب')
              .toString();
          final address = [tags['addr:street'], tags['addr:city']]
              .where((value) => value?.toString().trim().isNotEmpty == true)
              .join('، ');
          return IslamicProviderItem(
            title: name,
            subtitle: address.isEmpty ? 'ضمن نطاق 7 كم' : address,
          );
        })
        .toList(growable: false);
    return IslamicProviderResult(
      title: 'المساجد القريبة',
      source: 'OpenStreetMap / Overpass',
      items: items,
    );
  }

  Future<IslamicProviderResult> _loadHadith() async {
    final json = await _getJson(
      Uri.parse(
        'https://hadeethenc.com/api/v1/hadeeths/list/'
        '?language=ar&category_id=1&page=1&per_page=30',
      ),
    );
    final data = (json['data'] as List?) ?? const [];
    final items = data
        .whereType<Map>()
        .map(
          (item) => IslamicProviderItem(
            title: (item['title'] ?? '').toString(),
            subtitle: 'اضغط لقراءة الحديث وشرحه',
            url: item['id']?.toString(),
          ),
        )
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
    return IslamicProviderResult(
      title: 'الأحاديث',
      source: 'موسوعة الأحاديث النبوية HadeethEnc',
      items: items,
    );
  }

  Future<IslamicProviderResult> _loadReciters() async {
    final json = await _getJson(
      Uri.parse(
        'https://api.quran.com/api/v4/resources/recitations?language=ar',
      ),
    );
    final data = (json['recitations'] as List?) ?? const [];
    final items = data
        .whereType<Map>()
        .map((item) {
          final translated = _map(item['translated_name']);
          return IslamicProviderItem(
            title: (translated['name'] ?? item['reciter_name'] ?? '')
                .toString(),
            subtitle: (item['style'] ?? 'تلاوة').toString(),
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
    return IslamicProviderResult(
      title: 'القراء',
      source: 'Quran.com API',
      items: items,
    );
  }

  Future<IslamicProviderResult> _loadLessons() async {
    if (youtubeApiKey.isEmpty || youtubePlaylistId.isEmpty) {
      throw const IslamicProviderException(
        'أضف YOUTUBE_API_KEY و YOUTUBE_PLAYLIST_ID عند بناء التطبيق لعرض الدروس والحلقات.',
      );
    }
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', {
      'part': 'snippet,contentDetails',
      'maxResults': '50',
      'playlistId': youtubePlaylistId,
      'key': youtubeApiKey,
    });
    final json = await _getJson(uri);
    final data = (json['items'] as List?) ?? const [];
    final items = data
        .whereType<Map>()
        .map((item) {
          final snippet = _map(item['snippet']);
          final details = _map(item['contentDetails']);
          return IslamicProviderItem(
            title: (snippet['title'] ?? '').toString(),
            subtitle: (snippet['videoOwnerChannelTitle'] ?? '').toString(),
            url: details['videoId']?.toString(),
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
    return IslamicProviderResult(
      title: 'الدروس والحلقات',
      source: 'YouTube Data API',
      items: items,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri).timeout(_timeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IslamicProviderException(
        'تعذر الاتصال بمزوّد المحتوى (${response.statusCode}).',
      );
    }
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is! Map) {
      throw const IslamicProviderException('استجابة غير متوقعة من المزوّد.');
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}

class IslamicProviderException implements Exception {
  const IslamicProviderException(this.message);
  final String message;

  @override
  String toString() => message;
}
