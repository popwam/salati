import '../../../core/models/operational_config.dart';

enum QuranReaderMode { ayah, word }

class QuranSessionLimits {
  const QuranSessionLimits._();

  static const ayahFreeAllowance = Duration(minutes: 60);
  static const wordFreeAllowance = Duration(minutes: 30);

  static Duration defaultFreeAllowance(QuranReaderMode mode) {
    return switch (mode) {
      QuranReaderMode.ayah => ayahFreeAllowance,
      QuranReaderMode.word => wordFreeAllowance,
    };
  }

  static Duration configuredFreeAllowance({
    required QuranReaderMode mode,
    required QuranLimitsConfig config,
  }) {
    final minutes = switch (mode) {
      QuranReaderMode.ayah => config.ayahFreeMinutes,
      QuranReaderMode.word => config.wordFreeMinutes,
    };
    return Duration(minutes: minutes);
  }

  static Duration remaining({
    required Duration allowance,
    required int usedSeconds,
  }) {
    final used = usedSeconds.clamp(0, allowance.inSeconds).toInt();
    final remaining = allowance - Duration(seconds: used);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static bool canOpenFreeSession(Duration remaining) {
    return remaining > Duration.zero;
  }
}
