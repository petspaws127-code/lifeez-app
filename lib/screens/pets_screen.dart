import 'package:flutter/material.dart';
import 'reminders_screen.dart';

/// Unified Pets place: Pets | Health | Memories tabs.
/// All pet features (profiles, reminders, health, memories) live here —
/// nothing pet-related stays in the Reminders screen.
class PetsScreen extends StatelessWidget {
  static const route = '/pets';
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const RemindersScreen(petMode: true);
}
