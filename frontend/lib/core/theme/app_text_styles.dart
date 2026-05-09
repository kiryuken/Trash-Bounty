import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter();

  static TextStyle heading1 = _base.copyWith(fontSize: 30, fontWeight: FontWeight.w700);
  static TextStyle heading2 = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle heading3 = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static TextStyle heading4 = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle bodyLarge = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle bodyMedium = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle bodySmall = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);
  static TextStyle caption = _base.copyWith(fontSize: 10, fontWeight: FontWeight.w400);
  static TextStyle button = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle label = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
}
