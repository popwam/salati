import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:salati/features/islamic_ai/data/islamic_ai_api_client.dart';

void main() {
  test('sendMessage posts to islamic chat with user id header', () async {
    late http.Request capturedRequest;
    final client = IslamicAiApiClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'ok': true,
          'type': 'islamic',
          'answer': 'إجابة مختصرة',
          'ui': {'type': 'chat', 'direction': 'rtl', 'cards': []},
          'conversation': {'remainingUserMessages': 4},
        });
      }),
    );

    final response = await client.sendMessage('السلام عليكم', userId: 'uid-1');
    client.close();

    expect(capturedRequest.url.toString(), endsWith('/islamic/chat'));
    expect(capturedRequest.headers['X-User-Id'], 'uid-1');
    expect(jsonDecode(capturedRequest.body), {'message': 'السلام عليكم'});
    expect(response.answer, 'إجابة مختصرة');
    expect(response.remainingUserMessages, 4);
  });

  test('sendMessage maps 429 to daily limit message', () async {
    final client = IslamicAiApiClient(
      client: MockClient((_) async {
        return _jsonResponse({
          'ok': false,
          'error': 'daily_chat_limit_reached',
        }, statusCode: 429);
      }),
    );

    final response = await client.sendMessage('سؤال', userId: 'uid-1');
    client.close();

    expect(response.hasError, isTrue);
    expect(response.errorMessage, 'انتهى حد المحادثة اليومية');
  });

  test('sendMessage can pass dashboard quota metadata', () async {
    late http.Request capturedRequest;
    final client = IslamicAiApiClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return _jsonResponse({'ok': true, 'answer': 'ok'});
      }),
    );

    await client.sendMessage(
      'question',
      userId: 'uid-1',
      userPlanId: 'pro',
      dailyLimit: 30,
      remainingMessages: 12,
    );
    client.close();

    expect(capturedRequest.headers['X-User-Plan-Id'], 'pro');
    expect(capturedRequest.headers['X-User-Daily-Limit'], '30');
    expect(capturedRequest.headers['X-User-Remaining-Messages'], '12');
  });

  test('sendMessage tolerates missing ui and cards', () async {
    final client = IslamicAiApiClient(
      client: MockClient((_) async {
        return _jsonResponse({'ok': true, 'answer': 'نص فقط'});
      }),
    );

    final response = await client.sendMessage('سؤال', userId: '');
    client.close();

    expect(response.answer, 'نص فقط');
    expect(response.cards, isEmpty);
    expect(response.direction, 'rtl');
  });
}

http.Response _jsonResponse(Map<String, Object?> body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
