import 'package:flutter/material.dart';

class PrayerVisualStyle {
  const PrayerVisualStyle({
    required this.key,
    required this.label,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.highlightColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final Color highlightColor;
}
