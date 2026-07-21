import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:salati/features/quran/presentation/quran_share_image.dart';
import 'package:salati/features/quran/presentation/quran_typography.dart';

void main() {
  group('Quran share image helpers', () {
    test('creates safe png file names', () {
      final fileName = quranShareImageFileName(
        filePrefix: 'Salati Quran!',
        reference: 'Al-Fatihah 1:1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(42),
      );

      expect(fileName, 'salati_quran_al-fatihah_1_1_42.png');
    });

    test('compacts long share text without changing short text', () {
      expect(compactQuranShareTextForImage('  one   two  '), 'one two');

      final longText = List.filled(2300, 'a').join();
      final compact = compactQuranShareTextForImage(longText);

      expect(compact.length, 2203);
      expect(compact.endsWith('...'), isTrue);
    });
  });

  group('Quran typography', () {
    test('uses only the bundled Quran font as a safe fallback', () {
      final style = quranTextStyle(
        'remote_font_that_is_not_bundled',
        const TextStyle(fontSize: 24, letterSpacing: 2),
      );

      expect(style.fontFamily, 'AmiriQuran');
      expect(style.fontFamilyFallback, const ['serif']);
      expect(style.letterSpacing, 0);
      expect(style.locale, const Locale('ar'));
    });
  });
}
