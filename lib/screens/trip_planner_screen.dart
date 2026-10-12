import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../widgets/v2_kit.dart';
import '../models/trip_models.dart';
import '../models/task_item.dart';
import '../models/reminder.dart';
import '../services/trip_ai_service.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../services/eastern_time.dart';

const _uuid = Uuid();

/// V2 Trip Planner: upcoming-trip banner + cover-photo cards with
/// Confirmed badges and budget bars, plus the full AI trip planner
/// (smart input -> AI processing -> automated output -> app sync).
/// Presentation rewritten to the V2 mockup; all logic kept.
class TripPlannerScreen extends StatefulWidget {
  static const route = '/trip-planner';
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  // "My trips" list — persisted per user (no fake sample trips).
  final List<Map<String, String>> _trips = [];

  String _tripsKey() =>
      'v2_trips_${SupabaseService.currentUserId ?? "guest"}';

  Future<void> _loadTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tripsKey());
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      if (mounted) setState(() => _trips.addAll(list));
    } catch (_) {}
  }

  Future<void> _saveTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tripsKey(), jsonEncode(_trips));
    } catch (_) {}
  }

  // Smart input state.
  final _destCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  TripType _tripType = TripType.solo;

  // AI processing state.
  bool _generating = false;
  GeneratedTripPlan? _plan;
  final Set<String> _packedIds = {};

  // Voice input.
  final _stt = SpeechToText();
  bool _listening = false;

  // Sync state.
  bool _syncing = false;
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _budgetCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _fmtMoney(double v) =>
      '\$${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  /// Whole-dollar money, e.g. 1200 -> $1,200.
  String _fmtWhole(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return '\$$buf';
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? V2.green : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------------------------------------------------- voice input
  Future<void> _toggleListening() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final available = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!available) {
        _snack('Voice input is not available on this device.', ok: false);
        return;
      }
      setState(() => _listening = true);
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
        onResult: (r) {
          if (r.finalResult && mounted) {
            setState(() {
              _destCtrl.text = r.recognizedWords;
              _listening = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      _snack('Voice input failed. Please type instead.', ok: false);
    }
  }

  // ---------------------------------------------------------- date pickers
  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: V2.green),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  // ---------------------------------------------------------- AI generation
  Future<void> _generate() async {
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) {
      _snack('Enter a destination first.', ok: false);
      return;
    }
    if (_startDate == null || _endDate == null) {
      _snack('Pick your start and end dates.', ok: false);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _snack('End date must be after start date.', ok: false);
      return;
    }
    final budget =
        double.tryParse(_budgetCtrl.text.trim().replaceAll(',', '')) ?? 0;

    setState(() {
      _generating = true;
      _plan = null;
      _packedIds.clear();
      _synced = false;
    });
    try {
      final uid = SupabaseService.currentUserId ?? 'local';
      final plan = await TripAiService.generatePlan(
        destination: dest,
        startDate: _startDate!,
        endDate: _endDate!,
        tripType: _tripType,
        budget: budget,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _packedIds
            .addAll(plan.packing.where((p) => p.isPacked).map((p) => p.id));
      });
      // Also reflect in the "My trips" list, with the real planned total
      // so the budget bar shows honest data (never a fake 0 bar).
      setState(() => _trips.add({
            'name': 'AI: $dest',
            'detail':
                '${_fmtDate(_startDate!)} to ${_fmtDate(_endDate!)} - ${_fmtMoney(budget)} budget',
            'planned': plan.totalExpenses.toStringAsFixed(2),
          }));
      _saveTrips();
    } catch (e) {
      _snack('Could not generate the trip. Please try again.', ok: false);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ---------------------------------------------------------- sync to tasks
  DateTime _slotDateTime(DateTime day, String? startTime, int fallbackHour) {
    var hour = fallbackHour;
    var minute = 0;
    if (startTime != null) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(startTime);
      if (m != null) {
        hour = int.parse(m.group(1)!).clamp(0, 23);
        minute = int.parse(m.group(2)!).clamp(0, 59);
      }
    }
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// One-click sync: one task per itinerary day + start/end reminders.
  /// Uses the real AppState tasks & reminders modules (with push
  /// notifications for future reminders).
  Future<void> _syncToReminders() async {
    final plan = _plan;
    if (plan == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final app = context.read<AppState>();
      final uid = SupabaseService.currentUserId ?? 'local';
      final dest = plan.trip.destination;

      var taskCount = 0;
      for (final day in plan.days) {
        final morning = day.slotOf(SlotType.morning);
        final due = _slotDateTime(day.date, morning.startTime, 9);
        await app.addTask(TaskItem(
          id: _uuid.v4(),
          userId: uid,
          title: 'Day ${day.dayNumber} in $dest: ${morning.title}',
          dueDate: due,
          priority: 'normal',
          category: 'event',
          reminderAt: due,
          source: 'trips-ai',
          createdAt: easternNow(),
        ));
        taskCount++;
      }

      final s = plan.trip.startDate;
      final e = plan.trip.endDate;
      await app.addReminder(Reminder(
        id: _uuid.v4(),
        userId: uid,
        title: 'Trip to $dest starts today — have a great trip!',
        remindAt: DateTime(s.year, s.month, s.day, 8, 0),
      ));
      await app.addReminder(Reminder(
        id: _uuid.v4(),
        userId: uid,
        title: 'Trip to $dest ends today',
        remindAt: DateTime(e.year, e.month, e.day, 18, 0),
      ));

      if (!mounted) return;
      setState(() => _synced = true);
      _snack('Synced $taskCount tasks + 2 reminders to your calendar.');
    } catch (e) {
      _snack('Sync failed. Please try again.', ok: false);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ---------------------------------------------------------- existing bits
  void _addTrip() {
    final nameCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New trip', style: V2.title(18)),
            const SizedBox(height: 16),
            _V2Field(
                controller: nameCtrl,
                label: 'Trip name (e.g. Beach Weekend)'),
            const SizedBox(height: 12),
            _V2Field(
                controller: detailCtrl,
                label: 'Destination - dates - \$budget'),
            const SizedBox(height: 4),
            Text(
              'Example: Miami - Dec 12 to Dec 14 - \$400 budget',
              style: V2.sub(12),
            ),
            const SizedBox(height: 16),
            V2PrimaryButton(
              label: 'Add trip',
              onTap: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() => _trips.add({
                        'name': nameCtrl.text.trim(),
                        'detail': detailCtrl.text.trim(),
                      }));
                  _saveTrips();
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTrip(int index) async {
    final name = _trips[index]['name'] ?? 'this trip';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V2.card,
        title: Text('Delete $name?', style: V2.title(18)),
        content:
            Text('This removes the trip from your list.', style: V2.body(14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: V2.greenLabel(14))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: V2.danger))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _trips.removeAt(index));
      _saveTrips();
      _snack('Trip deleted.');
    }
  }

  // ---------------------------------------------------------- trip parsing
  ({String dest, String dates, double budget}) _parseTrip(
      Map<String, String> t) {
    var dest = (t['name'] ?? '').replaceFirst(RegExp(r'^AI:\s*'), '').trim();
    var dates = '';
    var budget = 0.0;
    final detail = (t['detail'] ?? '').trim();
    final budgetRe = RegExp(r'\$\s*([\d,]+(?:\.\d+)?)');
    double parseBudget(String s) {
      final m = budgetRe.firstMatch(s);
      if (m == null) return 0.0;
      return double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0;
    }

    final parts = detail.split(' - ').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      dest = parts.first;
      dates = parts.sublist(1, parts.length - 1).join(' - ');
      budget = parseBudget(parts.last);
    } else if (parts.length == 2) {
      budget = parseBudget(parts[1]);
      final looksLikeDates =
          RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}| to ').hasMatch(parts[0]);
      if (budget > 0 && looksLikeDates) {
        dates = parts[0];
      } else if (budget > 0) {
        dest = parts[0];
      } else {
        dest = parts[0];
        dates = parts[1];
      }
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      final b = parseBudget(parts[0]);
      if (b > 0) {
        budget = b;
      } else {
        dates = parts[0];
      }
    }
    return (dest: dest, dates: dates, budget: budget);
  }

  // ---------------------------------------------------------- UI builders
  Widget _tripCard(Map<String, String> t, int index) {
    final parsed = _parseTrip(t);
    final name = (t['name'] ?? '').trim();
    final title = name.isEmpty ? parsed.dest : name;
    // Real planned total from a linked AI plan (never a fake 0 bar).
    final planned = double.tryParse(t['planned'] ?? '') ?? 0;
    final metaBits = <String>[];
    if (parsed.dest.isNotEmpty &&
        parsed.dest.toLowerCase() != title.toLowerCase()) {
      metaBits.add(parsed.dest);
    }
    if (parsed.dates.isNotEmpty) metaBits.add(parsed.dates);
    return Dismissible(
      key: ValueKey('${title}_${t['detail']}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _deleteTrip(index);
        return false; // handled by the dialog
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: V2.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      child: V2Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover-photo area: gradient placeholder with destination icon.
            Container(
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [V2.greenDark, V2.green],
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.flight_takeoff_rounded,
                        color: Colors.white, size: 52),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: V2.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Text(
                        'Confirmed',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2.title(20)),
                  if (metaBits.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(metaBits.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2.sub(13.5)),
                  ],
                  const SizedBox(height: 10),
                  // Honest budget bar: only when we have real planned data.
                  // Never a fake 0 bar. Mockup style: bold amount + grey rest.
                  if (parsed.budget > 0 && planned > 0) ...[
                    V2ProgressBar(
                        value: (planned / parsed.budget).clamp(0.0, 1.0)),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, color: V2.muted),
                        children: [
                          TextSpan(
                            text: _fmtWhole(planned),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: V2.ink),
                          ),
                          TextSpan(
                              text:
                                  ' of ${_fmtWhole(parsed.budget)}'),
                        ],
                      ),
                    ),
                  ] else if (parsed.budget > 0)
                    Text('Budget ${_fmtWhole(parsed.budget)}',
                        style: V2.sub(13))
                  else
                    Text('No budget set', style: V2.sub(13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(color: V2.muted, fontSize: 14),
      suffixIcon: suffix,
      filled: true,
      fillColor: V2.bg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: V2.green, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: V2.ink)),
    );
  }

  Widget _buildInputCard() {
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const V2IconTile(Icons.auto_awesome_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Trip Planner', style: V2.title(17)),
                    Text('Tell me where and when — I will plan it all.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V2.sub(13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Destination'),
          TextField(
            controller: _destCtrl,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.poppins(color: V2.ink, fontSize: 14.5),
            decoration: _fieldDecor(
              'Where to? e.g. New York',
              suffix: IconButton(
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none_outlined,
                  color: _listening ? V2.danger : V2.green,
                ),
                tooltip: 'Voice input',
                onPressed: _toggleListening,
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Listening… speak your destination',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: V2.danger,
                    fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Start date'),
                    GestureDetector(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: V2.bg,
                          border:
                              Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _startDate == null
                                    ? 'MM/DD/YYYY'
                                    : _fmtDate(_startDate!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  color: _startDate == null
                                      ? V2.muted
                                      : V2.ink,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: V2.green),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('End date'),
                    GestureDetector(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: V2.bg,
                          border:
                              Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _endDate == null
                                    ? 'MM/DD/YYYY'
                                    : _fmtDate(_endDate!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  color: _endDate == null
                                      ? V2.muted
                                      : V2.ink,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: V2.green),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fieldLabel('Trip type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TripType.values.map((t) {
              final selected = _tripType == t;
              final label =
                  t.name[0].toUpperCase() + t.name.substring(1);
              return ChoiceChip(
                label: Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : V2.green,
                    )),
                selected: selected,
                selectedColor: V2.green,
                backgroundColor: V2.chip,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: V2.green.withValues(
                          alpha: selected ? 1 : 0.4)),
                ),
                onSelected: (_) => setState(() => _tripType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Estimated budget (USD)'),
          TextField(
            controller: _budgetCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(color: V2.ink, fontSize: 14.5),
            decoration: _fieldDecor(
              'e.g. 1200',
              suffix: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('\$',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: V2.green)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _generating ? 'Generating your trip…' : 'Generate with AI',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: V2.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _slotIcon(SlotType slot) {
    switch (slot) {
      case SlotType.morning:
        return Icons.wb_sunny_outlined;
      case SlotType.afternoon:
        return Icons.wb_cloudy_outlined;
      case SlotType.evening:
        return Icons.nights_stay_outlined;
    }
  }

  String _slotName(SlotType slot) {
    switch (slot) {
      case SlotType.morning:
        return 'Morning';
      case SlotType.afternoon:
        return 'Afternoon';
      case SlotType.evening:
        return 'Evening';
    }
  }

  Widget _buildItineraryTab(GeneratedTripPlan plan) {
    return Column(
      children: plan.days.map((day) {
        return V2Card(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: V2.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Day ${day.dayNumber}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: V2.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _fmtDate(day.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2.sub(13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...day.slots.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        V2IconTile(_slotIcon(s.slot), size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_slotName(s.slot)} • ${s.title}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              if (s.description.isNotEmpty)
                                Text(
                                  s.description,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: V2.muted,
                                      height: 1.4),
                                ),
                              if (s.spot.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.place_outlined,
                                          size: 14,
                                          color: V2.green),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          s.spot,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: V2.green,
                                              fontWeight:
                                                  FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (s.travelTip.isNotEmpty)
                                Container(
                                  margin:
                                      const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: V2.chip,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                          Icons.lightbulb_outline,
                                          size: 14,
                                          color: V2.green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          s.travelTip,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: V2.muted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPackingTab(GeneratedTripPlan plan) {
    const order = [
      PackingCategory.clothing,
      PackingCategory.electronics,
      PackingCategory.documents,
      PackingCategory.essentials,
    ];
    const names = {
      PackingCategory.clothing: 'Clothing',
      PackingCategory.electronics: 'Electronics',
      PackingCategory.documents: 'Documents',
      PackingCategory.essentials: 'Essentials',
    };
    const icons = {
      PackingCategory.clothing: Icons.checkroom_outlined,
      PackingCategory.electronics: Icons.devices_outlined,
      PackingCategory.documents: Icons.description_outlined,
      PackingCategory.essentials: Icons.backpack_outlined,
    };
    final packedCount =
        plan.packing.where((p) => _packedIds.contains(p.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V2Card(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const V2IconTile(Icons.luggage_outlined, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$packedCount of ${plan.packing.length} packed'
                  '${plan.trip.weatherSummary == null ? '' : ' • ${plan.trip.weatherSummary}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...order.map((cat) {
          final items =
              plan.packing.where((p) => p.category == cat).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: V2Card(
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(10, 8, 10, 2),
                    child: Row(
                      children: [
                        Icon(icons[cat], size: 18, color: V2.green),
                        const SizedBox(width: 8),
                        Text(
                          names[cat]!,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  ...items.map((item) {
                    final checked = _packedIds.contains(item.id);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      activeColor: V2.green,
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8),
                      title: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: checked ? V2.muted : V2.ink,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _packedIds.add(item.id);
                        } else {
                          _packedIds.remove(item.id);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExpensesTab(GeneratedTripPlan plan) {
    const names = {
      ExpenseCategory.stay: 'Stay',
      ExpenseCategory.food: 'Food',
      ExpenseCategory.sightseeing: 'Sightseeing',
      ExpenseCategory.transport: 'Transport',
    };
    const icons = {
      ExpenseCategory.stay: Icons.hotel_outlined,
      ExpenseCategory.food: Icons.restaurant_outlined,
      ExpenseCategory.sightseeing: Icons.camera_alt_outlined,
      ExpenseCategory.transport: Icons.directions_car_outlined,
    };
    final total = plan.totalExpenses;
    final budget = plan.trip.estimatedBudget;
    final ratio = budget > 0 ? (total / budget).clamp(0.0, 1.0) : 0.0;
    final over = budget > 0 && total > budget;
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated total', style: V2.sub(13)),
              Flexible(
                child: Text(
                  _fmtMoney(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: over ? V2.danger : V2.green),
                ),
              ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 8),
            V2ProgressBar(
                value: ratio, color: over ? V2.danger : V2.green),
            const SizedBox(height: 6),
            Text(
              '${_fmtMoney(total)} of ${_fmtMoney(budget)} budget'
              '${over ? ' — over budget' : ''}',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: over ? V2.danger : V2.muted),
            ),
          ],
          const Divider(height: 24),
          ...ExpenseCategory.values.map((cat) {
            final e = plan.expenses.firstWhere(
              (x) => x.category == cat,
              orElse: () => ExpenseBreakdown(
                  id: '', tripId: plan.trip.id, category: cat),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  V2IconTile(icons[cat]!, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          names[cat]!,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        if ((e.note ?? '').isNotEmpty)
                          Text(
                            e.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: V2.sub(12),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _fmtMoney(e.amountUsd),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final plan = _plan!;
    return V2Card(
      padding: EdgeInsets.zero,
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.trip.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2.title(18),
                        ),
                        Text(
                          '${_fmtDate(plan.trip.startDate)} – ${_fmtDate(plan.trip.endDate)}'
                          ' • ${plan.trip.tripType.name[0].toUpperCase()}${plan.trip.tripType.name.substring(1)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V2.sub(12),
                        ),
                      ],
                    ),
                  ),
                  if (plan.trip.weatherSummary != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: V2.chip,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        plan.trip.weatherSummary!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: V2.green),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              labelColor: V2.green,
              unselectedLabelColor: V2.muted,
              indicatorColor: V2.green,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Itinerary'),
                Tab(text: 'Packing List'),
                Tab(text: 'Expenses'),
              ],
            ),
            SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildItineraryTab(plan),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildPackingTab(plan),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildExpensesTab(plan),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_syncing || _synced)
                      ? null
                      : _syncToReminders,
                  icon: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : Icon(_synced
                          ? Icons.check_circle_outline
                          : Icons.sync_outlined),
                  label: Text(
                    _syncing
                        ? 'Syncing…'
                        : _synced
                            ? 'Synced to Reminders'
                            : 'Sync to Reminders',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: V2.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        V2.green.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(26)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final n = _trips.length;
    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2TitleRow(
                title: 'Trips',
                trailing: V2AddButton(onTap: _addTrip),
              ),
              // Green upcoming-trip banner (singular/plural).
              Container(
                decoration: V2.heroDeco,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 22),
                child: Row(
                  children: [
                    const Icon(Icons.flight_rounded,
                        color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '$n Upcoming Trip${n == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_trips.isEmpty)
                V2Card(
                  child: Column(
                    children: [
                      const V2IconTile(Icons.flight_outlined,
                          size: 56),
                      const SizedBox(height: 12),
                      Text('No trips yet.',
                          style: V2.title(16)),
                      const SizedBox(height: 4),
                      Text('Add one with the + button or plan it with AI below.',
                          textAlign: TextAlign.center,
                          style: V2.sub(13)),
                    ],
                  ),
                )
              else
                ..._trips.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _tripCard(e.value, e.key),
                    )),
              const SizedBox(height: 8),
              const V2SectionLabel('AI trip planner'),
              _buildInputCard(),
              const SizedBox(height: 16),
              if (_generating)
                V2Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                            color: V2.green),
                        const SizedBox(height: 12),
                        Text(
                          'AI is building your itinerary, packing list and budget…',
                          textAlign: TextAlign.center,
                          style: V2.sub(13),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_plan != null && !_generating) _buildResultCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }
}

/// V2-styled text field used by the trip sheets.
class _V2Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _V2Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: V2.ink, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: V2.muted, fontSize: 13.5),
        filled: true,
        fillColor: V2.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: V2.green, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
