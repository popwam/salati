import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/islamic_chat_response.dart';

class IslamicAiApiClient {
  IslamicAiApiClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const baseUrl = 'https://quran.mmdoh.workers.dev';
  static const _timeout = Duration(seconds: 45);
  static const _dailyLimitMessage = 'انتهى حد المحادثة اليومية';

  final http.Client _client;
  final bool _ownsClient;

  Future<BackendHealth> health() async {
    final response = await _sendWithNetworkHandling(
      () => _client.get(Uri.parse('$baseUrl/health')).timeout(_timeout),
    );
    final decoded = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IslamicAiApiException(_httpErrorMessage(response, decoded));
    }
    return BackendHealth.fromJson(decoded);
  }

  Future<IslamicChatResponse> sendMessage(
    String message, {
    required String userId,
    String? userPlanId,
    int? dailyLimit,
    int? remainingMessages,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return IslamicChatResponse.error('اكتب السؤال أولاً.');
    }

    final response = await _sendWithNetworkHandling(
      () => _client
          .post(
            Uri.parse('$baseUrl/islamic/chat'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-User-Id': userId.trim().isEmpty ? 'anonymous-user' : userId,
              if (userPlanId?.trim().isNotEmpty == true)
                'X-User-Plan-Id': userPlanId!.trim(),
              if (dailyLimit != null) 'X-User-Daily-Limit': '$dailyLimit',
              if (remainingMessages != null)
                'X-User-Remaining-Messages': '$remainingMessages',
            },
            body: jsonEncode({'message': trimmedMessage}),
          )
          .timeout(_timeout),
    );

    final decoded = _decodeJsonMap(response);
    if (_isDailyLimitResponse(response, decoded)) {
      return IslamicChatResponse.error(_dailyLimitMessage);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return IslamicChatResponse.error(_httpErrorMessage(response, decoded));
    }

    if (_stringFromMap(decoded, 'error') == 'daily_chat_limit_reached') {
      return IslamicChatResponse.error(_dailyLimitMessage);
    }

    return IslamicChatResponse.fromJson(decoded);
  }

  Future<IslamicChatResponse> askQuran(
    String question, {
    required String userId,
    String? userPlanId,
    int? dailyLimit,
    int? remainingMessages,
  }) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      return IslamicChatResponse.error('اكتب السؤال أولا.');
    }

    final response = await _sendWithNetworkHandling(
      () => _client
          .post(
            Uri.parse('$baseUrl/quran/ask'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-User-Id': userId.trim().isEmpty ? 'anonymous-user' : userId,
              if (userPlanId?.trim().isNotEmpty == true)
                'X-User-Plan-Id': userPlanId!.trim(),
              if (dailyLimit != null) 'X-User-Daily-Limit': '$dailyLimit',
              if (remainingMessages != null)
                'X-User-Remaining-Messages': '$remainingMessages',
            },
            body: jsonEncode({'question': trimmedQuestion}),
          )
          .timeout(_timeout),
    );

    final decoded = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return IslamicChatResponse.error(_httpErrorMessage(response, decoded));
    }

    return IslamicChatResponse.fromJson(decoded);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<http.Response> _sendWithNetworkHandling(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw const IslamicAiApiException(
        'انتهت مهلة الاتصال بالخدمة. حاول مرة أخرى.',
      );
    } on FormatException {
      throw const IslamicAiApiException('تعذر قراءة استجابة الخادم.');
    } on http.ClientException {
      throw const IslamicAiApiException(
        'تعذر الاتصال بالخدمة. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
      );
    } catch (_) {
      throw const IslamicAiApiException(
        'تعذر الاتصال بالخدمة. تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty) return const {};

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const IslamicAiApiException('تعذر قراءة استجابة الخادم.');
    }

    if (decoded is! Map) {
      throw const IslamicAiApiException('استجابة غير متوقعة من الخادم.');
    }

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  bool _isDailyLimitResponse(
    http.Response response,
    Map<String, dynamic> decoded,
  ) {
    final error = _stringFromMap(decoded, 'error');
    final code = _stringFromMap(decoded, 'code');
    return response.statusCode == 429 ||
        error == 'daily_chat_limit_reached' ||
        code == 'daily_chat_limit_reached';
  }

  String _httpErrorMessage(
    http.Response response,
    Map<String, dynamic> decoded,
  ) {
    final message = _firstNonEmpty([
      _stringFromMap(decoded, 'errorMessage'),
      _stringFromMap(decoded, 'message'),
      _stringFromMap(decoded, 'error'),
    ]);
    if (message.isNotEmpty) return message;
    return 'تعذر تنفيذ الطلب. رمز الخطأ: ${response.statusCode}';
  }

  String _stringFromMap(Map<String, dynamic> map, String key) {
    return map[key]?.toString().trim() ?? '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

class IslamicAiApiException implements Exception {
  const IslamicAiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
