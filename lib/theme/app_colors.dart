import 'package:flutter/material.dart';

/// Centralized harmonious color palette for FalconLog.
/// Adjust here to propagate across the app.
class AppColors {
  // Dark sky / cockpit inspired surfaces (طبقات خلفية)
  static const Color surfaceUltraDark = Color(0xFF071521); // أعمق درجة (ليل طيران)
  static const Color surfaceDark      = Color(0xFF0B2030); // خلفية رئيسية
  static const Color surfaceMid       = Color(0xFF123045); // تدرج متوسط
  static const Color surfaceAccent    = Color(0xFF18435A); // لمسة أفتح (لوحات / بطاقات)

  // Brand – Sky Blue (هوية مرتبطة بالطيران والسماء)
  static const Color brandPrimary      = Color(0xFF0A7CCF); // أزرق سماوي رئيسي
  static const Color brandPrimaryLight = Color(0xFF41B3FF); // درجة أخف لإضاءة وهايلايت

  // Accents (مساندة – لتفاصيل وأيقونات ثانوية)
  static const Color accentAqua     = Color(0xFF5ED3F3); // سماوي فاتح
  static const Color accentSoftBlue = Color(0xFF8CCBFF); // درجة هادئة ناعمة
  static const Color accentMint     = Color(0xFF3ECF9B); // توازن حيوي أخضر تركوازي

  // نصوص – تباين واضح مع الخلفيات الداكنة
  static const Color textPrimary   = Color(0xFFF2F7FA); // شبه أبيض مريح للعين
  static const Color textSecondary = Color(0xFFA9C2D3); // ثانوي هادئ
  static const Color textFaint     = Color(0xFF6F8897); // تعليمات / عناوين صغيرة

  // Semantic (تبقى كما هي تقريباً)
  static const Color danger  = Colors.redAccent;
  static const Color warning = Color(0xFFF5A524);
  static const Color success = Color(0xFF19B574);

  // Utility overlays (ظلال / طبقات زجاجية)
  static Color overlayLight(double opacity) => Colors.white.withOpacity(opacity);
  static Color overlayDark(double opacity)  => Colors.black.withOpacity(opacity);
}
