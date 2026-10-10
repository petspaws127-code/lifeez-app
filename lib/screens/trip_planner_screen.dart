import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../data/usa_states.dart';
import '../models/trip_models.dart';
import '../models/task_item.dart';
import '../models/reminder.dart';
import '../services/trip_ai_service.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../services/eastern_time.dart';

const _uuid = Uuid();
const _green = Color(0xFF1A9C63);

/// Trip Planner: [Smart Input] -> [AI Processing] -> [Automated Output]
/// -> [App System Sync].
///
/// - AI trip generator: destination, dates, trip type, budget -> Gemini
///   builds a day-by-day itinerary, weather-aware packing list and
///   expense breakdown (OpenWeatherMap + local fallback included).
/// - Result shown in 3 tabs: Itinerary | Packing List | Expenses.
/// - "Sync to Reminders" writes real tasks + reminders into the
///   Lifeez Tasks/Calendar module.
/// - Existing "My trips" list + USA states quick-add stay as-is below.
class TripPlannerScreen extends StatefulWidget {
  static const route = '/trip-planner';
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  // Existing "My trips" list (kept working).
  final List<Map<String, String>> _trips = [
    {
      'name': 'Beach Weekend',
      'detail': 'Miami - Dec 12 to Dec 14 - \$400 budget',
    },
  ];

  // Smart input state.
  final _destCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';
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
  void dispose() {
    _destCtrl.dispose();
    _budgetCtrl.dispose();
    _searchCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _fmtMoney(double v) =>
      '\$${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? _green : Colors.red.shade400,
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
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _green),
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
        _packedIds.addAll(
            plan.packing.where((p) => p.isPacked).map((p) => p.id));
      });
      // Also reflect in the "My trips" list.
      setState(() => _trips.add({
            'name': 'AI: $dest',
            'detail':
                '${_fmtDate(_startDate!)} to ${_fmtDate(_endDate!)} - ${_fmtMoney(budget)} budget',
          }));
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
  /// Fully automated: one tap on a state creates a complete trip plan.
  void _autoTrip(Map<String, dynamic> s) {
    final attractions = (s['attractions'] as List).join(', ');
    setState(() => _trips.add({
          'name': '${s['state']} Adventure',
          'detail':
              '${s['capital']} • Best: ${s['best']}\nTop spots: $attractions',
        }));
    _snack('${s['state']} trip added!');
  }

  void _addTrip() {
    final nameCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New trip', style: GoogleFonts.poppins()),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Trip name (e.g. Beach Weekend)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Destination, dates, budget'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() => _trips.add({
                      'name': nameCtrl.text.trim(),
                      'detail': detailCtrl.text.trim(),
                    }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- UI builders
  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _green, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildInputCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: _green),
              const SizedBox(width: 8),
              Text(
                'AI Trip Planner',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tell me where and when — I will plan it all.',
            style:
                GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Destination'),
          TextField(
            controller: _destCtrl,
            textInputAction: TextInputAction.done,
            decoration: _fieldDecor(
              'Where to? e.g. New York',
              suffix: IconButton(
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none_outlined,
                  color: _listening ? Colors.red : _green,
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
                    color: Colors.red,
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
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _startDate == null
                                    ? 'MM/DD/YYYY'
                                    : _fmtDate(_startDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _startDate == null
                                      ? Colors.grey[400]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: _green),
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
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _endDate == null
                                    ? 'MM/DD/YYYY'
                                    : _fmtDate(_endDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _endDate == null
                                      ? Colors.grey[400]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: _green),
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
            children: TripType.values.map((t) {
              final selected = _tripType == t;
              final label = t.name[0].toUpperCase() + t.name.substring(1);
              return ChoiceChip(
                label: Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _green,
                    )),
                selected: selected,
                selectedColor: _green,
                backgroundColor: _green.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: _green.withOpacity(selected ? 1 : 0.4)),
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
            decoration: _fieldDecor(
              'e.g. 1200',
              suffix: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('\$',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _green)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
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
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Day ${day.dayNumber}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtDate(day.date),
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...day.slots.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_slotIcon(s.slot),
                              size: 18, color: _green),
                        ),
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
                                      color: Colors.grey[700],
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
                                          color: _green),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          s.spot,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: _green,
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
                                    color: _green.withOpacity(0.07),
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
                                          color: _green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          s.travelTip,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.luggage_outlined, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$packedCount of ${plan.packing.length} packed'
                  '${plan.trip.weatherSummary == null ? '' : ' • ${plan.trip.weatherSummary}'}',
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
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      Icon(icons[cat], size: 18, color: _green),
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
                    activeColor: _green,
                    controlAffinity:
                        ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8),
                    title: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : null,
                        color: checked
                            ? Colors.grey[500]
                            : Colors.black87,
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated total',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600])),
                  Text(
                    _fmtMoney(total),
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: over ? Colors.red : _green),
                  ),
                ],
              ),
              if (budget > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor:
                        _green.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        over ? Colors.red : _green),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmtMoney(total)} of ${_fmtMoney(budget)} budget'
                  '${over ? ' — over budget' : ''}',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: over
                          ? Colors.red
                          : Colors.grey[600]),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Icon(icons[cat],
                            size: 20, color: _green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _fmtMoney(e.amountUsd),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final plan = _plan!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.trip.destination,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${_fmtDate(plan.trip.startDate)} – ${_fmtDate(plan.trip.endDate)}'
                          ' • ${plan.trip.tripType.name[0].toUpperCase()}${plan.trip.tripType.name.substring(1)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (plan.trip.weatherSummary != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Text(
                        plan.trip.weatherSummary!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _green),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              labelColor: _green,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: _green,
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
              child: ElevatedButton.icon(
                onPressed:
                    (_syncing || _synced) ? null : _syncToReminders,
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
                  backgroundColor: _synced
                      ? _green.withOpacity(0.7)
                      : _green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14)),
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
    final states = UsaStates.search(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _addTrip,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Container(
            decoration: AppTheme.heroGradient(radius: 24),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CategoryIcon(category: 'event', size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_trips.length} upcoming trips',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plan it all in one place.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Smart input: AI trip planner (primary flow)
          _buildInputCard(),
          const SizedBox(height: 12),
          // Automated output
          if (_generating)
            _sectionCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                        color: _green),
                    const SizedBox(height: 12),
                    Text(
                      'AI is building your itinerary, packing list and budget…',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          if (_plan != null && !_generating) _buildResultCard(),
          if (_plan != null && !_generating)
            const SizedBox(height: 12),
          const SizedBox(height: 4),
          const SectionHeader(title: 'Explore USA — tap a state'),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search states…',
              prefixIcon: const Icon(Icons.search_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          ...states.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (s['state'] as String).substring(0, 2),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
                  title: Text(s['state'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  subtitle: Text(s['tag'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600])),
                  trailing: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: _green),
                  onTap: () => _autoTrip(s),
                ),
              )),
          const SizedBox(height: 16),
          const SectionHeader(title: 'My trips'),
          if (_trips.isEmpty)
            const EmptyState(
              icon: Icons.flight_outlined,
              message: 'No trips yet. Plan one above!',
            )
          else
            ..._trips.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CategoryIcon(
                          category: 'transport', size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t['detail'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
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
  }
}
