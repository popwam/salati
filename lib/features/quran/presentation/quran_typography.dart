import 'package:flutter/material.dart';

TextStyle quranTextStyle(String _, TextStyle base) {
  final textStyle = base.copyWith(locale: const Locale('ar'), letterSpacing: 0);

  return textStyle.copyWith(
    fontFamily: 'AmiriQuran',
    fontFamilyFallback: const ['serif'],
  );
}

FontWeight quranFontWeightFromValue(num value) {
  final normalized = value.round().clamp(100, 900);
  final index = (normalized ~/ 100 - 1).clamp(0, FontWeight.values.length - 1);
  return FontWeight.values[index];
}
