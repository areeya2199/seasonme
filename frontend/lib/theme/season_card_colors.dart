import 'package:flutter/material.dart';
import 'package:frontend/theme/app_theme.dart';
import '../data/season_palette.dart';

/// Gradient for the "your season" cards (Home, Result, Profile).
List<Color> seasonCardGradient(SeasonKey season) {
  switch (season) {
    case SeasonKey.Spring:
      return const [Color(0xff5d8736), Color(0xff809d3c)];
    case SeasonKey.Summer:
      return const [Color(0xffbb596b), Color(0xfff96d80)];
    case SeasonKey.Autumn:
      return const [Color(0xff6b240c), Color(0xff994d1c)];
    case SeasonKey.Winter:
      return const [Color(0xffd9eafd), Color(0xfff8fafc)];
  }
}

/// Solid color matching the card (used for text on the white buttons).
Color seasonCardAccent(SeasonKey season) => seasonCardGradient(season).first;

/// ===== สีตัวหนังสือในการ์ด "ซีซั่นของคุณ" (Home / Result) =====
/// อยากเปลี่ยนสีตัวหนังสือของซีซั่นไหน ให้แก้ที่ฟังก์ชัน seasonCardText
/// ด้านล่างนี้ที่เดียว (ไม่ต้องแก้ใน home_screen / result_screen)
class SeasonCardText {
  /// ข้อความเล็กบนสุด เช่น "YOUR PERSONAL PALETTE IS"
  final Color label;

  /// ชื่อซีซั่นตัวใหญ่ เช่น "Soft Autumn"
  final Color title;

  /// ข้อความคำอธิบายใต้ชื่อ (หน้า Result)
  final Color body;

  /// ตัวหนังสือในป้าย pill เช่น "Warm", "Muted"
  final Color pillText;

  /// พื้นหลังป้าย pill
  final Color pillBg;

  /// พื้นหลังปุ่ม "View My Result" (หน้า Home)
  final Color buttonBg;

  /// ตัวหนังสือ/ไอคอนบนปุ่ม "View My Result"
  final Color buttonText;

  /// ขอบของกล่องสีตัวอย่าง (หน้า Home)
  final Color swatchBorder;

  const SeasonCardText({
    required this.label,
    required this.title,
    required this.body,
    required this.pillText,
    required this.pillBg,
    required this.buttonBg,
    required this.buttonText,
    required this.swatchBorder,
  });
}

SeasonCardText seasonCardText(SeasonKey season) {
  switch (season) {
    // พื้นหลังเขียวเข้ม -> ตัวหนังสือขาว
    case SeasonKey.Spring:
      return SeasonCardText(
        label: const Color(0xffffffff).withOpacity(0.85),
        title: const Color(0xffffffff),
        body: const Color(0xffffffff),
        pillText: const Color(0xffffffff),
        pillBg: const Color(0xffffffff).withOpacity(0.18),
        buttonBg: const Color(0xffffffff),
        buttonText: const Color(0xff5d8736),
        swatchBorder: const Color(0xffffffff),
      );

    // พื้นหลังเขียวมิ้นต์อ่อน -> ตัวหนังสือเขียวเข้ม
    case SeasonKey.Summer:
      return SeasonCardText(
        label: const Color(0xffffffff).withOpacity(0.85),
        title: const Color(0xffffffff),
        body: const Color(0xffffffff),
        pillText: const Color(0xffffffff),
        pillBg: const Color(0xffffffff).withOpacity(0.18),
        buttonBg: const Color(0xffffffff),
        buttonText: const Color(0xffbb596b),
        swatchBorder: const Color(0xffffffff),
      );

    // พื้นหลังน้ำตาลแดงเข้ม -> ตัวหนังสือครีมทอง
    case SeasonKey.Autumn:
      return SeasonCardText(
        label: const Color(0xffffffff).withOpacity(0.85),
        title: const Color(0xffffffff),
        body: const Color(0xffffffff),
        pillText: const Color(0xffffffff),
        pillBg: const Color(0xffffffff).withOpacity(0.18),
        buttonBg: const Color(0xffffffff),
        buttonText: const Color(0xff6b240c),
        swatchBorder: const Color(0xffffffff),
      );

    // พื้นหลังฟ้าอ่อน/ขาว -> ตัวหนังสือกรมท่า
    case SeasonKey.Winter:
      return SeasonCardText(
        label: AppColors.charcoal.withOpacity(0.85),
        title: AppColors.charcoal,
        body: AppColors.charcoal,
        pillText: AppColors.charcoal,
        pillBg: AppColors.charcoal.withOpacity(0.18),
        buttonBg: AppColors.charcoal,
        buttonText: const Color(0xffffffff),
        swatchBorder: const Color(0xffffffff),
      );
  }
}
