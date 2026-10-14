import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../theme/app_theme.dart';
import '../widgets/v2_kit.dart';

/// Vaccination + medicine tracker for one pet.
/// Status badges: Done / Due soon (within 30 days) / Overdue.
/// Pro feature (part of the Pets Pro bundle).
class PetVaccinationsScreen extends StatefulWidget {
  static const route = '/pet-vaccinations';
  final PetProfile pet;

  const PetVaccinationsScreen({super.key, required this.pet});

  @override
  State<PetVaccinationsScreen> createState() =>
      _PetVaccinationsScreenState();
}

enum _VacStatus { done, dueSoon, overdue }

class _PetVaccinationsScreenState extends State<PetVaccinationsScreen> {
  _VacStatus _status(PetVaccination v) {
    final due = v.nextDueDate;
    if (due == null) return _VacStatus.done;
    final now = easternNow();
    if (due.isBefore(DateTime(now.year, now.month, now.day))) {
      return _VacStatus.overdue;
    }
    if (due.difference(now).inDays <= 30) return _VacStatus.dueSoon;
    return _VacStatus.done;
  }

  Future<void> _markDone(PetVaccination v) async {
    final app = context.read<AppState>();
    final updated = PetVaccination(
      id: v.id,
      userId: v.userId,
      petId: v.petId,
      vaccineName: v.vaccineName,
      givenDate: easternNow(),
      nextDueDate: null,
    );
    await app.updateVaccination(updated);
  }

  Future<void> _remindMe(PetVaccination v) async {
    final app = context.read<AppState>();
    final due = v.nextDueDate ?? easternNow().add(const Duration(days: 7));
    final r = Reminder(
      id: const Uuid().v4(),
      userId: app.profile?.id ?? '',
      title: '${v.vaccineName} due for ${widget.pet.name}',
      remindAt: DateTime(due.year, due.month, due.day, 9),
      petId: widget.pet.id,
    );
    await app.addReminder(r);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder set!')),
      );
    }
  }

  Future<void> _addVaccination() async {
    final app = context.read<AppState>();
    final name = TextEditingController();
    DateTime? nextDue;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              Text('Add vaccination — ${widget.pet.name}',
                  style: V2.title(18)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: 'Vaccine name (e.g. Rabies)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded, color: V2.green),
                label: Text(
                  nextDue == null
                      ? 'Next due date (optional)'
                      : 'Due ${DateFormat('MM/dd/yyyy').format(nextDue!)}',
                  style: GoogleFonts.poppins(
                      color: V2.ink, fontWeight: FontWeight.w500),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: easternNow().add(const Duration(days: 365)),
                    firstDate: easternNow(),
                    lastDate:
                        easternNow().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) setSheet(() => nextDue = picked);
                },
              ),
              const SizedBox(height: 16),
              V2PrimaryButton(
                label: 'Save',
                onTap: () async {
                  if (name.text.trim().isEmpty) return;
                  final v = PetVaccination(
                    id: const Uuid().v4(),
                    userId: app.profile?.id ?? '',
                    petId: widget.pet.id,
                    vaccineName: name.text.trim(),
                    givenDate: easternNow(),
                    nextDueDate: nextDue,
                  );
                  await app.addVaccination(v);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMedicine() async {
    final app = context.read<AppState>();
    final name = TextEditingController();
    DateTime when = easternNow().add(const Duration(hours: 1));
    String repeat = 'daily';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              Text('Medicine reminder — ${widget.pet.name}',
                  style: V2.title(18)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: 'Medicine name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon:
                    const Icon(Icons.access_time_rounded, color: V2.green),
                label: Text(
                  DateFormat('MM/dd/yyyy hh:mm a').format(when),
                  style: GoogleFonts.poppins(
                      color: V2.ink, fontWeight: FontWeight.w500),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: when,
                    firstDate: easternNow(),
                    lastDate:
                        easternNow().add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  if (!ctx.mounted) return;
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                  if (t != null) {
                    setSheet(() => when = DateTime(
                        d.year, d.month, d.day, t.hour, t.minute));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: repeat,
                decoration: InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'none', child: Text('Once')),
                  DropdownMenuItem(
                      value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Weekly')),
                ],
                onChanged: (v) =>
                    setSheet(() => repeat = v ?? 'daily'),
              ),
              const SizedBox(height: 16),
              V2PrimaryButton(
                label: 'Set reminder',
                onTap: () async {
                  if (name.text.trim().isEmpty) return;
                  final r = Reminder(
                    id: const Uuid().v4(),
                    userId: app.profile?.id ?? '',
                    title:
                        '${name.text.trim()} for ${widget.pet.name}',
                    remindAt: when,
                    repeat: repeat == 'none' ? null : repeat,
                    petId: widget.pet.id,
                  );
                  await app.addReminder(r);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(_VacStatus s) {
    late Color bg;
    late Color fg;
    late String label;
    switch (s) {
      case _VacStatus.done:
        bg = V2.chip;
        fg = V2.green;
        label = 'Done';
        break;
      case _VacStatus.dueSoon:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'Due soon';
        break;
      case _VacStatus.overdue:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = 'Overdue';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final vacs = app.vaccinationsFor(widget.pet.id);
    final meds = app.reminders
        .where((r) => r.petId == widget.pet.id && !r.isDone)
        .toList();
    return Scaffold(
      backgroundColor: V2.bg,
      appBar: AppBar(
        backgroundColor: V2.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: V2.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.pet.name} — Vaccinations',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: V2.ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const V2SectionLabel('Vaccinations'),
            if (vacs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No vaccinations recorded yet.',
                    style: V2.sub(14)),
              ),
            ...vacs.map((v) {
              final st = _status(v);
              return V2Card(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: V2.chip,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                              Icons.vaccines_outlined,
                              color: V2.green,
                              size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(v.vaccineName,
                                  style: V2.title(16)),
                              const SizedBox(height: 2),
                              Text(
                                v.nextDueDate == null
                                    ? 'Given ${DateFormat('MM/dd/yyyy').format(v.givenDate)}'
                                    : 'Due ${DateFormat('MM/dd/yyyy').format(v.nextDueDate!)}',
                                style: V2.sub(13),
                              ),
                            ],
                          ),
                        ),
                        _badge(st),
                      ],
                    ),
                    if (st != _VacStatus.done) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _remindMe(v),
                              child: Text('Remind me',
                                  style: GoogleFonts.poppins(
                                      color: V2.green,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: V2.green),
                              onPressed: () => _markDone(v),
                              child: Text('Mark done',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, color: V2.green),
                label: Text('Add vaccination',
                    style: GoogleFonts.poppins(
                        color: V2.green,
                        fontWeight: FontWeight.w600)),
                onPressed: _addVaccination,
              ),
            ),
            const SizedBox(height: 20),
            const V2SectionLabel('Medicine reminders'),
            if (meds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No medicine reminders set.',
                    style: V2.sub(14)),
              ),
            ...meds.map((m) => V2Card(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: V2.chip,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                            Icons.medication_outlined,
                            color: V2.green,
                            size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(m.title, style: V2.title(15)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MM/dd/yyyy hh:mm a')
                                  .format(m.remindAt),
                              style: V2.sub(13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, color: V2.green),
                label: Text('Add medicine reminder',
                    style: GoogleFonts.poppins(
                        color: V2.green,
                        fontWeight: FontWeight.w600)),
                onPressed: _addMedicine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
