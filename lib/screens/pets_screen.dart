import 'package:flutter/material.dart';
import 'reminders_screen.dart';

/// Thin redirect: the standalone Pets screen is now the "Pets" tab
/// of the unified Reminders screen. The '/pets' route keeps working so
/// old navigation (home pet card, deep links) lands on the Pets tab.
class PetsScreen extends StatelessWidget {
  static const route = '/pets';
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const RemindersScreen(initialTab: 1);
}
