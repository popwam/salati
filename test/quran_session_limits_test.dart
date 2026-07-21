import 'package:flutter_test/flutter_test.dart';
import 'package:salati/core/models/operational_config.dart';
import 'package:salati/features/quran/presentation/quran_session_limits.dart';

void main() {
  group('QuranSessionLimits', () {
    test('uses 60 minutes for ayah and 30 minutes for word by default', () {
      expect(
        QuranSessionLimits.defaultFreeAllowance(QuranReaderMode.ayah),
        const Duration(minutes: 60),
      );
      expect(
        QuranSessionLimits.defaultFreeAllowance(QuranReaderMode.word),
        const Duration(minutes: 30),
      );
    });

    test('uses operational config values when provided', () {
      const config = QuranLimitsConfig(
        ayahFreeMinutes: 75,
        wordFreeMinutes: 35,
        rewardedAyahMinutes: 20,
        rewardedWordMinutes: 10,
      );

      expect(
        QuranSessionLimits.configuredFreeAllowance(
          mode: QuranReaderMode.ayah,
          config: config,
        ),
        const Duration(minutes: 75),
      );
      expect(
        QuranSessionLimits.configuredFreeAllowance(
          mode: QuranReaderMode.word,
          config: config,
        ),
        const Duration(minutes: 35),
      );
    });

    test(
      'remaining clamps usage and only allows new sessions with time left',
      () {
        final remaining = QuranSessionLimits.remaining(
          allowance: const Duration(minutes: 30),
          usedSeconds: 31 * 60,
        );

        expect(remaining, Duration.zero);
        expect(QuranSessionLimits.canOpenFreeSession(remaining), isFalse);
        expect(
          QuranSessionLimits.canOpenFreeSession(const Duration(seconds: 1)),
          isTrue,
        );
      },
    );
  });
}
