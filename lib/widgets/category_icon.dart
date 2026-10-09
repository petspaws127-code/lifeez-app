import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Unique 3D gradient tile per category/type. Every task, expense, bill,
/// reminder, and shopping item in the app shows one of these.
class CategoryIconSpec {
  final IconData icon;
  final List<Color> colors;
  const CategoryIconSpec(this.icon, this.colors);
}

const Map<String, CategoryIconSpec> kCategoryIcons = {
  'food': CategoryIconSpec(
      Icons.restaurant, [Color(0xFFF59E0B), Color(0xFFEF6C00)]),
  'grocery': CategoryIconSpec(
      Icons.shopping_cart, [Color(0xFF22C55E), Color(0xFF15803D)]),
  'transport': CategoryIconSpec(
      Icons.directions_car, [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
  'shopping': CategoryIconSpec(
      Icons.shopping_bag, [Color(0xFF1A9C63), Color(0xFFBE185D)]),
  'bills': CategoryIconSpec(
      Icons.receipt_long, [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
  'rent': CategoryIconSpec(
      Icons.home, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'health': CategoryIconSpec(
      Icons.favorite, [Color(0xFFEF4444), Color(0xFFB91C1C)]),
  'task': CategoryIconSpec(
      Icons.check_circle, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'general': CategoryIconSpec(
      Icons.check_circle, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'reminder': CategoryIconSpec(
      Icons.alarm, [Color(0xFFF59E0B), Color(0xFFB45309)]),
  'subscription': CategoryIconSpec(
      Icons.autorenew, [Color(0xFF8B5CF6), Color(0xFF5B21B6)]),
  'document': CategoryIconSpec(
      Icons.description, [Color(0xFF1A9C63), Color(0xFF334155)]),
  'car': CategoryIconSpec(
      Icons.directions_car, [Color(0xFF0EA5E9), Color(0xFF0369A1)]),
  'family': CategoryIconSpec(
      Icons.people, [Color(0xFF1A9C63), Color(0xFF9D174D)]),
  'money': CategoryIconSpec(
      Icons.attach_money, [Color(0xFF1A9C63), Color(0xFF926F0E)]),
  'event': CategoryIconSpec(
      Icons.event, [Color(0xFF14B8A6), Color(0xFF0F766E)]),
  'work': CategoryIconSpec(
      Icons.work, [Color(0xFF6366F1), Color(0xFF3730A3)]),
  'home': CategoryIconSpec(
      Icons.home, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'calls': CategoryIconSpec(
      Icons.call, [Color(0xFF22C55E), Color(0xFF15803D)]),
  'other': CategoryIconSpec(
      Icons.circle, [Color(0xFF94A3B8), Color(0xFF1A9C63)]),
  'pet': CategoryIconSpec(
      Icons.pets, [Color(0xFF22C55E), Color(0xFF15803D)]),
  'habit': CategoryIconSpec(
      Icons.repeat_rounded, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'brain': CategoryIconSpec(
      Icons.psychology_outlined, [Color(0xFF8B5CF6), Color(0xFF5B21B6)]),
  'notification': CategoryIconSpec(
      Icons.notifications_outlined, [Color(0xFFF59E0B), Color(0xFFB45309)]),
  'savings': CategoryIconSpec(
      Icons.savings_outlined, [Color(0xFF1A9C63), Color(0xFF926F0E)]),
  'scan': CategoryIconSpec(
      Icons.document_scanner_outlined,
      [Color(0xFF1A9C63), Color(0xFF334155)]),
  'pin': CategoryIconSpec(
      Icons.lock_outline_rounded, [Color(0xFF1A9C63), Color(0xFF146B4F)]),
  'pro': CategoryIconSpec(
      Icons.star_rounded, [Color(0xFF1A9C63), Color(0xFF926F0E)]),
  'myday': CategoryIconSpec(
      Icons.wb_sunny_outlined, [Color(0xFFF59E0B), Color(0xFFB45309)]),
  'share': CategoryIconSpec(
      Icons.share_rounded, [Color(0xFF22C55E), Color(0xFF15803D)]),
};

CategoryIconSpec iconFor(String category) {
  final key = category.trim().toLowerCase();
  return kCategoryIcons[key] ?? kCategoryIcons['other']!;
}

/// 3D gradient tile rendering the category's unique icon.
class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final spec = iconFor(category);
    return Container(
      width: size,
      height: size,
      decoration: AppTheme.tile3D(spec.colors, radius: size * 0.36),
      child: Icon(spec.icon, color: Colors.white, size: size * 0.52),
    );
  }
}
