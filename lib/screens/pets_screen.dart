import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/v2_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../services/supabase_client.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../models/expense.dart';
import 'pet_health_ai_screen.dart';
import 'pet_ai_chat_screen.dart';
import 'pet_vaccinations_screen.dart';
import 'pet_expense_report_screen.dart';
import 'pet_digital_id_screen.dart';
import 'pet_vet_history_screen.dart';

/// Per-pet daily care tracking (Feed / Walk / Medicine).
/// Stored per-user per-day in SharedPreferences.
class PetCareTracker {
  PetCareTracker._();

  static String _key(String petId) {
    final uid = SupabaseService.currentUserId ?? 'guest';
    final date = DateFormat('yyyy-MM-dd').format(easternNow());
    return 'pet_care_${uid}_${petId}_$date';
  }

  /// Returns {feed: bool, walk: bool, medicine: bool} for today.
  static Future<Map<String, bool>> load(String petId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(petId));
      if (raw == null) return {'feed': false, 'walk': false, 'medicine': false};
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'feed': json['feed'] == true,
        'walk': json['walk'] == true,
        'medicine': json['medicine'] == true,
      };
    } catch (_) {
      return {'feed': false, 'walk': false, 'medicine': false};
    }
  }

  static Future<void> toggle(String petId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await load(petId);
      current[type] = !(current[type] ?? false);
      await prefs.setString(_key(petId), jsonEncode(current));
    } catch (_) {}
  }
}

/// V2 Pets screen: Pets | Health | Memories tabs (V2 pill style).
/// Keeps all existing logic: pets CRUD (with photos), pet reminders,
/// vaccinations, health AI entry, memories + fullscreen viewer,
/// lost-pet alert. Presentation rewritten to the V2 mockup.
class PetsScreen extends StatefulWidget {
  static const route = '/pets';
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  int _tab = 0; // 0 = Pets, 1 = Health, 2 = Memories
  String? _petId;

  static const _petTypes = ['feeding', 'vet', 'grooming', 'walk', 'medicine'];

  String? _selectedPetId(AppState app) {
    if (_petId != null && app.pets.any((p) => p.id == _petId)) {
      return _petId;
    }
    return app.pets.isEmpty ? null : app.pets.first.id;
  }

  PetProfile? _currentPet(AppState app) {
    final id = _selectedPetId(app);
    if (id == null) return null;
    return app.pets.firstWhere((p) => p.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pets = app.pets;
    // Selected pet for the care dashboard (defaults to first pet).
    final selectedId = _petId != null && pets.any((p) => p.id == _petId)
        ? _petId
        : (pets.isEmpty ? null : pets.first.id);

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pets.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pets',
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: V2.ink)),
                      const SizedBox(height: 2),
                      Text('Your furry family', style: V2.sub(14)),
                    ],
                  ),
                )
              else
                V2TitleRow(
                  title: 'Pets',
                  trailing: V2AddButton(
                    onTap: () => _showEditPet(context, app, null),
                  ),
                ),
              if (pets.isEmpty)
                _noPetState(context, app)
              else ...[
                // Pet selector — horizontal avatars.
                _petSelector(context, app, pets, selectedId),
                const SizedBox(height: 20),
                // Today's care — one-tap Feed / Walk / Medicine.
                _todaysCare(context, app, selectedId!),
                const SizedBox(height: 20),
                // Upcoming — vet visits & vaccinations.
                _upcomingSection(context, app, selectedId),
                const SizedBox(height: 16),
                // Health quick-log.
                OutlinedButton.icon(
                  onPressed: () =>
                      _showAddVaccine(context, app, petId: selectedId),
                  icon: const Icon(Icons.add_rounded, color: V2.green),
                  label: Text('+ Health quick-log',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: V2.green)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: V2.green, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                // Details tabs (existing functionality).
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      V2Pill(
                          label: 'Details',
                          selected: _tab == 0,
                          outlined: true,
                          onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 10),
                      V2Pill(
                          label: 'Health',
                          selected: _tab == 1,
                          outlined: true,
                          onTap: () => setState(() => _tab = 1)),
                      const SizedBox(width: 10),
                      V2Pill(
                          label: 'Memories',
                          selected: _tab == 2,
                          outlined: true,
                          onTap: () => setState(() => _tab = 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_tab == 0)
                  _petsTab(context, app)
                else if (_tab == 1)
                  _healthTab(context, app)
                else
                  _memoriesTab(context, app),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  /// Horizontal pet avatar selector.
  Widget _petSelector(BuildContext context, AppState app,
      List<PetProfile> pets, String? selectedId) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (ctx, i) {
          final pet = pets[i];
          final selected = pet.id == selectedId;
          return GestureDetector(
            onTap: () => setState(() => _petId = pet.id),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? V2.green : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: V2.chip,
                    backgroundImage: _photoOk(pet.photoPath)
                        ? FileImage(File(pet.photoPath!))
                        : null,
                    child: _photoOk(pet.photoPath)
                        ? null
                        : const Icon(Icons.pets_rounded,
                            size: 32, color: V2.muted),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pet.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? V2.ink : V2.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Today's care — Feed / Walk / Medicine one-tap cards.
  Widget _todaysCare(
      BuildContext context, AppState app, String petId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's care", style: V2.title(20)),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, bool>>(
          future: PetCareTracker.load(petId),
          builder: (ctx, snap) {
            final care = snap.data ??
                {'feed': false, 'walk': false, 'medicine': false};
            return Row(
              children: [
                Expanded(
                    child: _careCard(
                        context, petId, 'feed', 'Feed',
                        Icons.restaurant_rounded, care['feed']!,
                        'Done', 'Tap when fed')),
                const SizedBox(width: 10),
                Expanded(
                    child: _careCard(
                        context, petId, 'walk', 'Walk',
                        Icons.pets_rounded, care['walk']!,
                        'Done', 'Due 6pm')),
                const SizedBox(width: 10),
                Expanded(
                    child: _careCard(
                        context, petId, 'medicine', 'Medicine',
                        Icons.medication_rounded,
                        care['medicine']!, 'Done', 'Due 9pm')),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _careCard(BuildContext context, String petId, String type,
      String label, IconData icon, bool done, String doneText,
      String pendingText) {
    final bgColor = done
        ? const Color(0xFFD9F2E5)
        : type == 'walk'
            ? const Color(0xFFFBE3C2)
            : V2.chip;
    final iconColor = done
        ? V2.green
        : type == 'walk'
            ? const Color(0xFFE8930C)
            : V2.muted;
    return GestureDetector(
      onTap: () async {
        await PetCareTracker.toggle(petId, type);
        if (context.mounted) setState(() {});
      },
      child: V2Card(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: V2.ink)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 14,
                  color: done ? V2.green : V2.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  done ? doneText : pendingText,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: done ? V2.green : V2.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Upcoming vet visits & vaccinations for the selected pet.
  Widget _upcomingSection(
      BuildContext context, AppState app, String petId) {
    final now = easternNow();
    final upcoming = <Map<String, dynamic>>[];

    // Vet/medicine reminders for this pet.
    for (final r in app.reminders) {
      if (r.petId == petId && r.remindAt.isAfter(now)) {
        upcoming.add({
          'icon': Icons.calendar_month_rounded,
          'title': r.title,
          'subtitle': DateFormat('MMM d, h:mm a').format(r.remindAt),
          'date': r.remindAt,
        });
      }
    }
    // Upcoming vaccinations.
    for (final v in app.vaccinations) {
      if (v.petId == petId &&
          v.nextDueDate != null &&
          v.nextDueDate!.isAfter(now)) {
        upcoming.add({
          'icon': Icons.vaccines_rounded,
          'title': '${v.vaccineName} due',
          'subtitle':
              'in ${v.nextDueDate!.difference(now).inDays} days',
          'date': v.nextDueDate!,
        });
      }
    }
    upcoming.sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming', style: V2.title(20)),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          V2Card(
            child: Row(
              children: [
                const V2IconTile(Icons.event_available_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Nothing scheduled',
                      style: V2.body()),
                ),
              ],
            ),
          )
        else
          ...upcoming.take(3).map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: V2Card(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      V2IconTile(u['icon'] as IconData, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(u['title'] as String,
                                style: V2.title(15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(u['subtitle'] as String,
                                style: V2.sub(13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: V2.muted),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  // ================================================================ PETS TAB
  Widget _petsTab(BuildContext context, AppState app) {
    final pets = app.pets;
    if (pets.isEmpty) return _noPetState(context, app);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...pets.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _petCard(context, app, p),
            )),
        const V2SectionLabel('Pet reminders'),
        ..._petReminderRows(context, app),
        const SizedBox(height: 4),
        _addReminderButton(context, app),
        const SizedBox(height: 16),
        _lostPetCard(context, app),
      ],
    );
  }

  Widget _noPetState(BuildContext context, AppState app) => V2Card(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const V2IconTile(Icons.pets_rounded, size: 72),
            const SizedBox(height: 16),
            Text('Add your first pet', style: V2.title(18)),
            const SizedBox(height: 8),
            Text(
              'Feeding, vet visits, grooming, walks and medicine — all organized per pet.',
              textAlign: TextAlign.center,
              style: V2.sub(14),
            ),
            const SizedBox(height: 20),
            _emptyFeatureRow(
              Icons.smart_toy_outlined,
              'AI Health Assistant',
              true,
              onTap: () =>
                  Navigator.pushNamed(context, PetAiChatScreen.route),
            ),
            _emptyFeatureRow(
              Icons.account_balance_wallet_outlined,
              'Expense insights',
              true,
            ),
            _emptyFeatureRow(
              Icons.qr_code_rounded,
              'Digital Pet ID',
              true,
            ),
            const SizedBox(height: 8),
            V2PrimaryButton(
              label: 'Add a pet',
              onTap: () => _showEditPet(context, app, null),
            ),
          ],
        ),
      );

  Widget _emptyFeatureRow(IconData icon, String label,
          [bool isPro = false, VoidCallback? onTap]) =>
      InkWell(
        onTap: onTap ??
            () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Coming soon in Pro!')),
                ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: V2.chip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: V2.green, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: V2.body(15))),
              if (isPro)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: V2.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('PRO',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
            ],
          ),
        ),
      );

  String _ageLabel(PetProfile p) {
    final b = p.birthDate;
    if (b == null) return '';
    final now = easternNow();
    var years = now.year - b.year;
    if (now.month < b.month ||
        (now.month == b.month && now.day < b.day)) {
      years--;
    }
    if (years <= 0) {
      final months = (now.year - b.year) * 12 + now.month - b.month;
      if (months <= 1) return '1 mo';
      return '$months mos';
    }
    return '$years yr${years == 1 ? '' : 's'}';
  }

  String _petSubtitle(PetProfile p) {
    final breed = (p.breed ?? '').trim();
    final sp = p.species.isEmpty
        ? ''
        : p.species[0].toUpperCase() + p.species.substring(1);
    final base = breed.isNotEmpty ? breed : sp;
    final age = _ageLabel(p);
    if (base.isEmpty) return age;
    return age.isEmpty ? base : '$base • $age';
  }

  bool _photoOk(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  Widget _pawPlaceholder() => const Center(
        child: Icon(Icons.pets_rounded, size: 52, color: V2.green),
      );

  Widget _petPhoto(PetProfile pet, {double height = 150}) {
    final path = pet.photoPath;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: V2.chip,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _photoOk(path)
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _pawPlaceholder(),
            )
          : _pawPlaceholder(),
    );
  }

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: V2.green),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: V2.green,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: V2.green, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
    );
  }

  Widget _petCard(BuildContext context, AppState app, PetProfile pet) {
    return V2Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _petPhoto(pet),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2.title(21)),
                      const SizedBox(height: 2),
                      Text(_petSubtitle(pet),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V2.sub(13.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit pet',
                  icon:
                      const Icon(Icons.edit_outlined, color: V2.muted),
                  onPressed: () =>
                      _showEditPet(context, app, pet),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _outlineBtn(
                  Icons.add_rounded,
                  'Log health',
                  () => _showAddVaccine(context, app, petId: pet.id),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineBtn(
                  Icons.add_photo_alternate_outlined,
                  'Add memory',
                  () => _showAddMemory(context, app, petId: pet.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outlineBtn(
              Icons.smart_toy_outlined,
              'Ask AI about ${pet.name}',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetAiChatScreen(pet: pet),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outlineBtn(
              Icons.vaccines_outlined,
              'Vaccinations & medicine',
              () => Navigator.pushNamed(
                context,
                PetVaccinationsScreen.route,
                arguments: pet,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outlineBtn(
              Icons.qr_code_rounded,
              'Digital Pet ID',
              () => Navigator.pushNamed(
                context,
                PetDigitalIdScreen.route,
                arguments: pet,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outlineBtn(
              Icons.history_rounded,
              'Vet history (PDF)',
              () => Navigator.pushNamed(
                context,
                PetVetHistoryScreen.route,
                arguments: pet,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _outlineBtn(
                  Icons.add_card_outlined,
                  'Log expense',
                  () => _showAddPetExpense(context, app, pet),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineBtn(
                  Icons.bar_chart_outlined,
                  'Expense report',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PetExpenseReportScreen(pet: pet),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _petReminderRows(BuildContext context, AppState app) {
    final rows = <Widget>[];
    for (final pet in app.pets) {
      for (final r in app.petRemindersFor(pet.id)) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: V2Card(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const V2IconTile(Icons.pets_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${pet.name} • ${DateFormat('EEE, MMM d • h:mm a').format(r.remindAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2.sub(12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Mark done',
                  icon: const Icon(Icons.check_circle_outline,
                      color: V2.green),
                  onPressed: () => app.toggleReminder(r.id),
                ),
              ],
            ),
          ),
        ));
      }
    }
    if (rows.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'No pet reminders yet — add feeding, vet, grooming, walk or medicine reminders.',
          style: V2.sub(13),
        ),
      ));
    }
    return rows;
  }

  Widget _addReminderButton(BuildContext context, AppState app) {
    return _outlineBtn(
      Icons.alarm_add_rounded,
      'Add pet reminder',
      () => _showAddPetReminder(context, app),
    );
  }

  Widget _lostPetCard(BuildContext context, AppState app) {
    final pet = app.pets.isEmpty ? null : app.pets.first;
    return V2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const V2IconTile(Icons.health_and_safety_outlined,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Lost Pet Alert', style: V2.title(16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If ${pet?.name ?? 'your pet'} goes missing, alert fast and call the 24/7 pet poison helpline if needed.',
            style: V2.sub(13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _outlineBtn(Icons.share_rounded, 'Share alert',
                    () => _shareLostPet(context, app)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineBtn(Icons.call_rounded, 'ASPCA 24/7',
                    () => launchUrl(Uri.parse('tel:+18884264435'))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareLostPet(BuildContext context, AppState app) {
    final pet = app.pets.isEmpty ? null : app.pets.first;
    final text =
        'LOST PET ALERT: ${pet?.name ?? 'My pet'} (${pet?.species ?? ''}${pet?.breed != null ? ' • ${pet!.breed}' : ''}) is missing. Please contact me if seen!';
    launchUrl(Uri.parse('sms:?body=${Uri.encodeComponent(text)}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Alert drafted — send it to spread the word.')),
    );
  }

  // ------------------------------------------------------- pet profile CRUD
  void _showEditPet(
      BuildContext context, AppState app, PetProfile? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final breed = TextEditingController(text: existing?.breed ?? '');
    final weight =
        TextEditingController(text: existing?.weightLbs?.toString() ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    String species = existing?.species ?? 'dog';
    DateTime? birth = existing?.birthDate;
    String? photoPath = existing?.photoPath;
    final picker = ImagePicker();
    showModalBottomSheet(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Add a pet' : 'Edit pet',
                    style: V2.title(18)),
                const SizedBox(height: 16),
                _V2Field(controller: name, label: 'Pet name'),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          imageQuality: 80);
                      if (img != null) {
                        setSheet(() => photoPath = img.path);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: V2.chip,
                      backgroundImage: _photoOk(photoPath)
                          ? FileImage(File(photoPath!))
                          : null,
                      child: !_photoOk(photoPath)
                          ? const Icon(Icons.add_a_photo_rounded,
                              color: V2.green, size: 30)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: Text('Tap to add a photo', style: V2.sub(12))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['dog', 'cat', 'bird', 'other']
                      .map((s) => ChoiceChip(
                            label: Text(s,
                                style: GoogleFonts.poppins(fontSize: 13)),
                            selected: species == s,
                            selectedColor: V2.green,
                            backgroundColor: V2.chip,
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  species == s ? Colors.white : V2.green,
                            ),
                            onSelected: (_) =>
                                setSheet(() => species = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                _V2Field(controller: breed, label: 'Breed (optional)'),
                const SizedBox(height: 12),
                _V2Field(
                    controller: weight,
                    label: 'Weight in lbs (optional)',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cake_outlined, color: V2.green),
                  label: Text(
                    birth == null
                        ? 'Birth date (optional)'
                        : DateFormat('MM/dd/yyyy').format(birth!),
                    style: GoogleFonts.poppins(
                        color: V2.ink, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: easternNow(),
                      initialDate: birth ?? easternNow(),
                    );
                    if (d != null) setSheet(() => birth = d);
                  },
                ),
                const SizedBox(height: 12),
                _V2Field(controller: notes, label: 'Notes (optional)'),
                const SizedBox(height: 16),
                V2PrimaryButton(
                  label: existing == null ? 'Add pet' : 'Save changes',
                  onTap: () async {
                    if (name.text.trim().isEmpty) return;
                    final w = double.tryParse(weight.text.trim());
                    if (existing == null) {
                      final p = PetProfile(
                        id: const Uuid().v4(),
                        userId: app.profile?.id ?? '',
                        name: name.text.trim(),
                        species: species,
                        breed: breed.text.trim().isEmpty
                            ? null
                            : breed.text.trim(),
                        birthDate: birth,
                        weightLbs: w,
                        notes: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        photoPath: photoPath,
                      );
                      await app.addPet(p);
                      setState(() => _petId = p.id);
                    } else {
                      await app.updatePet(existing.copyWith(
                        name: name.text.trim(),
                        species: species,
                        breed: breed.text.trim().isEmpty
                            ? null
                            : breed.text.trim(),
                        birthDate: birth,
                        weightLbs: w,
                        notes: notes.text.trim().isEmpty
                            ? null
                            : notes.text.trim(),
                        photoPath: photoPath,
                        clearPhoto: photoPath == null,
                      ));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                if (existing != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _confirmDeletePet(context, app, existing),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: V2.danger, size: 18),
                    label: Text('Remove ${existing.name}',
                        style: GoogleFonts.poppins(
                            color: V2.danger, fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePet(
      BuildContext context, AppState app, PetProfile pet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V2.card,
        title: Text('Remove ${pet.name}?', style: V2.title(18)),
        content: Text(
            'This deletes the pet profile, its vaccinations, memories and reminders.',
            style: V2.body(14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: V2.greenLabel(14))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: V2.danger))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _petId = null);
      await app.deletePet(pet.id);
      if (context.mounted) Navigator.pop(context); // close edit sheet
    }
  }

  void _showAddPetReminder(BuildContext context, AppState app) {
    final petId = _selectedPetId(app);
    if (petId == null) {
      _showEditPet(context, app, null);
      return;
    }
    final title = TextEditingController();
    String type = _petTypes.first;
    DateTime when = easternNow().add(const Duration(hours: 1));
    showModalBottomSheet(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pet reminder — ${app.petName(petId)}',
                    overflow: TextOverflow.ellipsis, style: V2.title(18)),
                const SizedBox(height: 4),
                Text('Pets only — pick a type below.', style: V2.sub(13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _petTypes
                      .map((t) => ChoiceChip(
                            label: Text(t,
                                style: GoogleFonts.poppins(fontSize: 13)),
                            selected: type == t,
                            selectedColor: V2.green,
                            backgroundColor: V2.chip,
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  type == t ? Colors.white : V2.green,
                            ),
                            onSelected: (_) =>
                                setSheet(() => type = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                _V2Field(
                    controller: title,
                    label: 'Details (e.g. Morning kibble)'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, color: V2.green),
                  label: Text(
                      DateFormat('EEE, MMM d • h:mm a').format(when),
                      style: GoogleFonts.poppins(
                          color: V2.ink, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: easternNow(),
                      lastDate:
                          easternNow().add(const Duration(days: 365)),
                      initialDate: when,
                    );
                    if (d == null || !ctx.mounted) return;
                    final tm = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(when));
                    if (tm == null) return;
                    setSheet(() => when = DateTime(
                        d.year, d.month, d.day, tm.hour, tm.minute));
                  },
                ),
                const SizedBox(height: 16),
                V2PrimaryButton(
                  label: 'Save pet reminder',
                  onTap: () async {
                    final detail = title.text.trim();
                    await app.addPetReminder(Reminder(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      title:
                          '${type[0].toUpperCase()}${type.substring(1)}${detail.isNotEmpty ? ': $detail' : ''}',
                      remindAt: when,
                      petId: petId,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- vaccinations
  void _showVaccinesSheet(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final petId = _selectedPetId(app);
          final list =
              petId == null ? <PetVaccination>[] : app.vaccinationsFor(petId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Vaccinations — ${app.petName(petId ?? '')}',
                    overflow: TextOverflow.ellipsis, style: V2.title(18)),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No vaccinations recorded. Add rabies, distemper and more.',
                      textAlign: TextAlign.center,
                      style: V2.sub(13.5),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final v = list[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: V2Card(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                V2IconTile(
                                  v.isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.medical_services_outlined,
                                  size: 44,
                                  bg: v.isOverdue
                                      ? const Color(0xFFFDECEC)
                                      : V2.chip,
                                  fg: v.isOverdue
                                      ? V2.danger
                                      : V2.green,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(v.vaccineName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14.5)),
                                      Text(
                                        'Given ${DateFormat('MM/dd/yyyy').format(v.givenDate)}${v.nextDueDate != null ? ' • Due ${DateFormat('MM/dd/yyyy').format(v.nextDueDate!)}' : ''}${v.isOverdue ? ' • OVERDUE' : ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: v.isOverdue
                                                ? V2.danger
                                                : V2.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: V2.muted),
                                  onPressed: () async {
                                    await app.deleteVaccination(v.id);
                                    setSheet(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _outlineBtn(
                        Icons.document_scanner_outlined,
                        'Scan vet card',
                        () {
                          Navigator.pop(ctx);
                          Navigator.of(context).pushNamed('/scanner');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddVaccine(context, app);
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: V2.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddPetExpense(
      BuildContext context, AppState app, PetProfile pet) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'Health';
    const cats = ['Health', 'Food', 'Grooming', 'Toys', 'Other'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Expense for ${pet.name}',
              style: V2.title(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount (\$)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                items: cats
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setDlg(() => category = v ?? 'Health'),
                decoration:
                    const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: V2.sub().copyWith(fontSize: 14))),
            TextButton(
              onPressed: () async {
                final amt =
                    double.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) return;
                await app.addExpense(Expense(
                  id: const Uuid().v4(),
                  userId: app.profile?.id ?? 'local',
                  amount: amt,
                  category: category,
                  note: noteCtrl.text.trim(),
                  spentAt: easternNow(),
                  source: 'app',
                  petId: pet.id,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Save',
                  style: GoogleFonts.poppins(
                      color: V2.green,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVaccine(BuildContext context, AppState app,
      {String? petId}) {
    final id = petId ?? _selectedPetId(app);
    if (id == null) {
      _showEditPet(context, app, null);
      return;
    }
    final name = TextEditingController();
    DateTime given = easternNow();
    DateTime? nextDue;
    showModalBottomSheet(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Record vaccination — ${app.petName(id)}',
                    overflow: TextOverflow.ellipsis, style: V2.title(18)),
                const SizedBox(height: 12),
                _V2Field(
                    controller: name,
                    label: 'Vaccine name (e.g. Rabies)'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_rounded, color: V2.green),
                  label: Text(
                      'Given ${DateFormat('MM/dd/yyyy').format(given)}',
                      style: GoogleFonts.poppins(
                          color: V2.ink, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2015),
                      lastDate: easternNow(),
                      initialDate: given,
                    );
                    if (d != null) setSheet(() => given = d);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_repeat_rounded,
                      color: V2.green),
                  label: Text(
                      nextDue == null
                          ? 'Next due (optional)'
                          : 'Due ${DateFormat('MM/dd/yyyy').format(nextDue!)}',
                      style: GoogleFonts.poppins(
                          color: V2.ink, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: easternNow(),
                      lastDate: easternNow()
                          .add(const Duration(days: 365 * 5)),
                      initialDate:
                          easternNow().add(const Duration(days: 365)),
                    );
                    if (d != null) setSheet(() => nextDue = d);
                  },
                ),
                const SizedBox(height: 16),
                V2PrimaryButton(
                  label: 'Save vaccination',
                  onTap: () async {
                    if (name.text.trim().isEmpty) return;
                    await app.addVaccination(PetVaccination(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      petId: id,
                      vaccineName: name.text.trim(),
                      givenDate: given,
                      nextDueDate: nextDue,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================== HEALTH TAB
  Widget _healthTab(BuildContext context, AppState app) {
    final pet = _currentPet(app);
    if (app.pets.isEmpty || pet == null) {
      return _noPetState(context, app);
    }
    final vaccines = app.vaccinationsFor(pet.id);
    final overdue = vaccines.where((v) => v.isOverdue).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: app.pets
                .map((p) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: V2Pill(
                        label: p.name,
                        selected: _selectedPetId(app) == p.id,
                        onTap: () => setState(() => _petId = p.id),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        const V2SectionLabel('Vaccinations'),
        V2Card(
          onTap: () => _showVaccinesSheet(context, app),
          child: Row(
            children: [
              const V2IconTile(Icons.medical_services_outlined,
                  size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vaccinations', style: V2.title(15.5)),
                    const SizedBox(height: 2),
                    Text(
                      vaccines.isEmpty
                          ? 'No vaccinations recorded'
                          : '${vaccines.length} recorded${overdue > 0 ? ' • $overdue OVERDUE' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color:
                              overdue > 0 ? V2.danger : V2.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: V2.muted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const V2SectionLabel('Health overview'),
        V2Card(
          child: Row(
            children: [
              const V2IconTile(Icons.favorite_rounded, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2.title(16)),
                    const SizedBox(height: 2),
                    Text(
                      'Vaccinations, vet visits & health tips in one place.',
                      style: V2.sub(12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        V2PrimaryButton(
          label: 'Log health',
          onTap: () => _showAddVaccine(context, app, petId: pet.id),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, PetHealthAiScreen.route),
            icon: const Icon(Icons.health_and_safety_outlined,
                color: V2.green),
            label: Text('Open Pet Health',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: V2.green)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: V2.green, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================= MEMORIES TAB
  Widget _memoriesTab(BuildContext context, AppState app) {
    final list = app.petMemories;
    if (app.pets.isEmpty) return _noPetState(context, app);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('Saved moments',
                    style: V2.title(17))),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _showAddMemory(context, app),
                icon: const Icon(Icons.add_rounded,
                    color: V2.green, size: 20),
                label: Text('Add',
                    style: GoogleFonts.poppins(
                        color: V2.green,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: V2.green, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          V2Card(
            child: Column(
              children: [
                const V2IconTile(Icons.photo_library_outlined,
                    size: 56),
                const SizedBox(height: 12),
                Text(
                  'Save favorite moments with your pet — first walk, birthdays, silly faces.',
                  textAlign: TextAlign.center,
                  style: V2.sub(13.5),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              return V2Card(
                padding: EdgeInsets.zero,
                onTap: () => _openMemoryViewer(context, list, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _memoryPhoto(m.photoPath)),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(app.petName(m.petId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: V2.green)),
                            Text(m.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                DateFormat('MM/dd/yyyy')
                                    .format(m.memoryDate),
                                style: V2.sub(11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _memoryPhoto(String? photoPath) {
    if (_photoOk(photoPath)) {
      return Image.file(
        File(photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: V2.chip,
          child: const Icon(Icons.pets_rounded,
              size: 44, color: V2.green),
        ),
      );
    }
    return Container(
      color: V2.chip,
      child: const Icon(Icons.pets_rounded,
          size: 44, color: V2.green),
    );
  }

  void _openMemoryViewer(
      BuildContext context, List<PetMemory> memories, int startIndex) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      barrierLabel: 'Close memory viewer',
      pageBuilder: (_, __, ___) => _MemoryViewer(
        memories: memories,
        initialIndex: startIndex,
      ),
    );
  }

  void _showAddMemory(BuildContext context, AppState app,
      {String? petId}) {
    final caption = TextEditingController();
    String? selected = petId ?? _selectedPetId(app);
    String? photoPath;
    final picker = ImagePicker();
    showModalBottomSheet(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Save a memory', style: V2.title(18)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: app.pets
                      .map((p) => ChoiceChip(
                            label: Text(p.name,
                                style: GoogleFonts.poppins(fontSize: 13)),
                            selected: selected == p.id,
                            selectedColor: V2.green,
                            backgroundColor: V2.chip,
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected == p.id
                                  ? Colors.white
                                  : V2.green,
                            ),
                            onSelected: (_) =>
                                setSheet(() => selected = p.id),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final source =
                        await showModalBottomSheet<ImageSource>(
                      context: ctx,
                      backgroundColor: V2.card,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: V2.green),
                              title: const Text('Take a photo'),
                              onTap: () => Navigator.pop(
                                  context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(
                                  Icons.photo_library_outlined,
                                  color: V2.green),
                              title:
                                  const Text('Choose from gallery'),
                              onTap: () => Navigator.pop(
                                  context, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source == null) return;
                    final img = await picker.pickImage(
                        source: source,
                        maxWidth: 1024,
                        imageQuality: 85);
                    if (img != null) {
                      setSheet(() => photoPath = img.path);
                    }
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: V2.chip,
                      borderRadius: BorderRadius.circular(16),
                      image: _photoOk(photoPath)
                          ? DecorationImage(
                              image: FileImage(File(photoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !_photoOk(photoPath)
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    color: V2.green, size: 32),
                                SizedBox(height: 4),
                                Text('Add a photo',
                                    style: TextStyle(color: V2.green)),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _V2Field(
                    controller: caption,
                    label: 'Caption (e.g. First beach day!)'),
                const SizedBox(height: 16),
                V2PrimaryButton(
                  label: 'Save memory',
                  onTap: () async {
                    if (caption.text.trim().isEmpty ||
                        selected == null) {
                      return;
                    }
                    await app.addPetMemory(PetMemory(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      petId: selected!,
                      caption: caption.text.trim(),
                      memoryDate: easternNow(),
                      photoPath: photoPath,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fullscreen memory viewer: PageView with pinch-to-zoom,
/// caption + date below, swipe through all memories, close + delete.
class _MemoryViewer extends StatefulWidget {
  final List<PetMemory> memories;
  final int initialIndex;
  const _MemoryViewer(
      {required this.memories, required this.initialIndex});

  @override
  State<_MemoryViewer> createState() => _MemoryViewerState();
}

class _MemoryViewerState extends State<_MemoryViewer> {
  late final PageController _page;
  late List<PetMemory> _items;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.memories);
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrent() async {
    final app = context.read<AppState>();
    final m = _items[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V2.card,
        title: Text('Delete memory?', style: V2.title(18)),
        content: Text(
            'This memory photo and caption will be removed.',
            style: V2.body(14)),
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
    if (ok != true) return;
    await app.deletePetMemory(m.id);
    setState(() {
      _items.removeAt(_index);
      if (_items.isEmpty) {
        Navigator.pop(context);
        return;
      }
      if (_index >= _items.length) {
        _index = _items.length - 1;
        _page.jumpToPage(_index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = _items[_index];
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    '${_index + 1} of ${_items.length}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white70),
                  onPressed: _deleteCurrent,
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final ok = (item.photoPath ?? '').isNotEmpty &&
                      File(item.photoPath!).existsSync();
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: ok
                          ? Image.file(
                              File(item.photoPath!),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.pets_rounded,
                                      size: 80,
                                      color: Colors.white70),
                            )
                          : const Icon(Icons.pets_rounded,
                              size: 80, color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(app.petName(m.petId),
                      style: GoogleFonts.poppins(
                          color: V2.amber,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(m.caption,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(DateFormat('MM/dd/yyyy').format(m.memoryDate),
                      style: GoogleFonts.poppins(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// V2-styled text field used by the pets sheets.
class _V2Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  const _V2Field({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: V2.ink, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: V2.muted, fontSize: 13.5),
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
            borderSide: const BorderSide(color: V2.green, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
