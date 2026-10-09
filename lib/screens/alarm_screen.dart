import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../models/alarm.dart';

/// Alarm feature: time-based alarms with repeat days.
/// Fires via system notifications (device-local).
class AlarmScreen extends StatelessWidget {
  static const route = '/alarms';
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final alarms = [...app.alarms]
      ..sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return Scaffold(
      appBar: AppBar(title: const Text('Alarms')),
      body: alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No alarms yet',
                      style: GoogleFonts.poppins(
                          fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first alarm',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: alarms.length,
              itemBuilder: (ctx, i) {
                final a = alarms[i];
                return Dismissible(
                  key: ValueKey(a.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      context.read<AppState>().deleteAlarm(a.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          a.enabled
                              ? Icons.alarm_on_rounded
                              : Icons.alarm_off_outlined,
                          color: a.enabled
                              ? const Color(0xFF1A9C63)
                              : Colors.grey[400],
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: a.enabled
                                      ? Colors.black87
                                      : Colors.grey[400],
                                ),
                              ),
                              Text(
                                '${a.label} • ${a.repeatLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: a.enabled,
                          activeColor: const Color(0xFF1A9C63),
                          onChanged: (_) => context
                              .read<AppState>()
                              .toggleAlarm(a.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A9C63),
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final labelCtrl = TextEditingController(text: 'Alarm');
    TimeOfDay time = TimeOfDay.now();
    final days = <int>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New alarm',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                      context: ctx, initialTime: time);
                  if (picked != null) setS(() => time = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_outlined,
                          color: Color(0xFF1A9C63)),
                      const SizedBox(width: 12),
                      Text(
                        time.format(ctx),
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text('Change',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF1A9C63),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Repeat',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (int d = 1; d <= 7; d++)
                    ChoiceChip(
                      label: Text(
                          const [
                            '',
                            'M',
                            'T',
                            'W',
                            'T',
                            'F',
                            'S',
                            'S'
                          ][d],
                          style: GoogleFonts.poppins(fontSize: 13)),
                      selected: days.contains(d),
                      selectedColor: const Color(0xFF1A9C63)
                          .withOpacity(0.2),
                      onSelected: (v) => setS(() =>
                          v ? days.add(d) : days.remove(d)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('No days = rings once',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final app = context.read<AppState>();
                  app.addAlarm(Alarm(
                    label: labelCtrl.text.trim().isEmpty
                        ? 'Alarm'
                        : labelCtrl.text.trim(),
                    hour: time.hour,
                    minute: time.minute,
                    repeatDays: days.toList(),
                  ));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Alarm set!',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF1A9C63),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9C63),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Set alarm',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
