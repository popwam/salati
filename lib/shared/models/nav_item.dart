import 'package:flutter/material.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isCenter = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isCenter;
}
