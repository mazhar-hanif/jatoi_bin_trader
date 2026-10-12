import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const compactBreakpoint = 600.0;
  static const expandedBreakpoint = 1024.0;

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;

  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radius20 = 20.0;
  static const radius28 = 28.0;

  static const elevation1 = 1.0;
  static const elevation2 = 2.0;
  static const shortMotion = Duration(milliseconds: 180);
  static const standardMotion = Duration(milliseconds: 260);

  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
  static const body = TextStyle(fontSize: 16);
  static const caption = TextStyle(fontSize: 12);
}
