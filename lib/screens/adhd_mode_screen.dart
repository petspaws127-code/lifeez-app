import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';

/// ADHD Mode: distraction-free focus - one task, one timer.
class AdhdModeScreen extends StatefulWidget {
  static const route = '/adhd-mode';
  const AdhdModeScreen({super.key});

  @override
  State<AdhdModeScreen> createState() => _AdhdModeScreenState();
}

class _AdhdModeScreenState extends State<AdhdModeScreen> {
  static const int _focusMinutes = 25;
  int _secondsLeft = _focusMinutes * 60;
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      setState(() => _running = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_secondsLeft <= 1) {
          t.cancel();
          setState(() {
            _running = false;
            _secondsLeft = _focusMinutes * 60;
          });
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _secondsLeft = _focusMinutes * 60;
    });
  }

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final focusTask =
        app.todayTasks.isNotEmpty ? app.todayTasks.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('ADHD Focus Mode')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.heroGradient(radius: 24),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Focus timer',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _format(_secondsLeft),
                  style: GoogleFonts.poppins(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A9C63),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                      ),
                      onPressed: _toggle,
                      child: Text(
                        _running ? 'Pause' : 'Start',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _reset,
                      child: Text(
                        'Reset',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'One thing at a time'),
          if (focusTask == null)
            const EmptyState(
              icon: Icons.check_circle_outline,
              message: 'No tasks due today. Enjoy your calm!',
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF1A9C63).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const CategoryIcon(category: 'task', size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Focus on this one task now. Nothing else.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
