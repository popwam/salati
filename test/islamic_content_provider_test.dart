import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salati/features/home/data/islamic_content_provider.dart';

void main() {
  test('parses Quran.com reciters', () async {
    final provider = IslamicContentProvider(
      client: MockClient((request) async {
        expect(request.url.host, 'api.quran.com');
        return http.Response(
          '{"recitations":[{"reciter_name":"Reader","style":"Murattal",'
          '"translated_name":{"name":"القارئ"}}]}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await provider.load(IslamicProviderKind.reciters);

    expect(result.source, 'Quran.com API');
    expect(result.items.single.title, 'القارئ');
    expect(result.items.single.subtitle, 'Murattal');
  });

  test('parses HadeethEnc content', () async {
    final provider = IslamicContentProvider(
      client: MockClient((request) async {
        expect(request.url.host, 'hadeethenc.com');
        return http.Response(
          '{"data":[{"id":"1","title":"إنما الأعمال بالنيات"}]}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await provider.load(IslamicProviderKind.hadith);

    expect(result.items.single.title, 'إنما الأعمال بالنيات');
    expect(result.items.single.url, '1');
  });
}
