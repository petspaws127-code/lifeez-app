import 'package:flutter/material.dart';

/// In-app notification shown in the Notification Center.
/// These are generated locally from the user's data (bills due, tasks,
/// reminders, trial status) — no push needed.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final DateTime createdAt;
  final String? route;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.createdAt,
    this.route,
  });
}
