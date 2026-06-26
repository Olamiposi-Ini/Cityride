import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Primary Greens ────────────────────────────────────────────
  static const Color primary = Color(0xFF147D44);
  static const Color primaryDark = Color(0xFF0F7543);

  // ── Secondary Greens ──────────────────────────────────────────
  static const Color secondary = Color(0xFF38764B);
  static const Color darkBackground = Color(0xFF1E3A28);

  // ── Accents ───────────────────────────────────────────────────
  static const Color accent = Color(0xFFC5E1A5);
  static const Color muted = Color(0xFFA3C1AD);

  // ── Surfaces ──────────────────────────────────────────────────
  static const Color surface = Color(0xFFE9F2EE);
  static const Color surfaceAlt = Color(0xFFEDFAF2);

  // ── Page Backgrounds ──────────────────────────────────────────
  static const Color pageBackground = Color(0xFFF5F9FC);
  static const Color pageBackgroundAlt = Color(0xFFF2F4F5);
  static const Color pageBackgroundGray = Color(0xFFF7F8FA);

  // ── Text ──────────────────────────────────────────────────────
  static const Color darkText = Color(0xFF051D30);
  static const Color darkTextAlt = Color(0xFF0A1C2A);
  static const Color greyText = Color(0xFF4A5A6A);
  static const Color lightGreyText = Color(0xFF7A868F);

  // ── Misc ──────────────────────────────────────────────────────
  static const Color indicatorInactive = Color(0xFFC4D1C9);
  static const Color cardFill = Color(0xFFF5F5F5);
  static const Color inputBackground = Color(0xFFF4F6F8);
  static const Color errorBackground = Color(0xFFFDECEC);
  static const Color borderLight = Color(0xFFEFF1F3);
}

/// Consistent spacing scale for the "clean minimal" design language.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
}

/// Consistent corner-radius scale.
abstract class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 30;
}

/// Soft, low-contrast shadows instead of hard black box-shadows — the
/// signature look of the clean-minimal/fintech style.
abstract class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F0A1C2A), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0A0A1C2A), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x140A1C2A), blurRadius: 30, offset: Offset(0, 12)),
  ];
}

/// Restrained typography scale.
abstract class AppText {
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
    letterSpacing: -0.4,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
    letterSpacing: -0.2,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.darkText,
  );
  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.greyText,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.lightGreyText,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.lightGreyText,
    letterSpacing: 0.3,
  );
}
