import 'package:flutter/material.dart';

abstract final class ClinicalOperationsStyle {
  static const accent = Color(0xff43e1ba);
  static Color background(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xff10141a) : const Color(0xfff4f7fa);
  static Color panel(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xff181c22) : Colors.white;
  static Color elevated(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xff1c2026) : const Color(0xffeaf0f6);
  static Color muted(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xffa1a8b6) : const Color(0xff586577);
  static Color teal(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? accent : const Color(0xff007d65);
}
