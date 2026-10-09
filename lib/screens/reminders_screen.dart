import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../services/eastern_time.dart';
import 'pet_health_ai_screen.dart';

/// Reminders screen: general reminders only.
/// Pet features live in PetsScreen (petMode) — one unified Pets place.
class RemindersScreen extends StatefulWidget {
  static const route = '/reminders';
  const RemindersScreen({super.key, this.initialTab = 0, this.petMode = false});

  /// 0 = Reminders (normal) | 0 = Pets, 1 = Health, 2 = Memories (petMode)
  final int initialTab;

  /// When true, shows Pets | Health | Memories tabs (used by PetsScreen).
  final bool petMode;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _petId;

  static const _petTypes = ['feeding', 'vet', 'grooming', 'walk', 'medicine'];
  static const _quickChips = [
    'Pay a bill',
    'Call family',
    'Doctor appointment',
    'Take medicine',
    'Birthday',
    'Meeting',
  ];

  @override
  void initState() {
    super.initState();
    final len = widget.petMode ? 3 : 1;
    _tabs = TabController(
      length: len,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, len - 1),
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
    final petMode = widget.petMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(petMode ? 'Pets' : 'Reminders'),
        bottom: petMode
            ? TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Pets'),
                  Tab(text: 'Health'),
                  Tab(text: 'Memories'),
                ],
              )
            : null,
      ),
      body: petMode
          ? TabBarView(
              controller: _tabs,
              children: [
                _petsTab(context, app),
                _healthTab(context, app),
                _memoriesTab(context, app),
              ],
            )
          : _generalTab(context, app),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (petMode) {
            if (_tabs.index == 2) {
              if (app.pets.isEmpty) {
                _showEditPet(context, app, null);
              } else {
                _showAddMemory(context, app);
              }
            } else {
              if (app.pets.isEmpty) {
                _showEditPet(context, app, null);
              } else {
                _showAddPetReminder(context, app);
              }
            }
          } else {
            _showAddSheet(context);
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ============================================================ GENERAL TAB
  Widget _generalTab(BuildContext context, AppState app) {
    final active = app.activeReminders;
    final done = app.reminders.where((r) => r.isDone).toList();
    return RefreshIndicator(
      onRefresh: () => app.loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (active.isEmpty && done.isEmpty)
            const EmptyState(
                message:
                    'No reminders. Say "remind me to pay rent on the 1st".',
                icon: Icons.alarm_outlined),
          if (active.isNotEmpty) ...[
            const SectionHeader(title: 'Active'),
            ...active.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.card3D(radius: 18),
                  child: ListTile(
                    leading: const CategoryIcon(
                        category: 'reminder', size: 42),
                    title: Text(r.title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      DateFormat('EEE, MMM d • h:mm a')
                          .format(r.remindAt),
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.deepGreen),
                      onPressed: () =>
                          app.toggleReminder(r.id),
                    ),
                  ),
                )),
          ],
          if (done.isNotEmpty) ...[
            const SectionHeader(title: 'Done'),
            ...done.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppTheme.card3D(radius: 18),
                  child: ListTile(
                    leading: const CategoryIcon(
                        category: 'reminder', size: 42),
                    title: Text(r.title,
                        style: GoogleFonts.poppins(
                            decoration:
                                TextDecoration.lineThrough)),
                    trailing: IconButton(
                      icon: const Icon(Icons.undo_rounded,
                          color: AppColors.muted),
                      onPressed: () =>
                          app.toggleReminder(r.id),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Reminder suggestions',
            suggestions: [
              if (active.isNotEmpty)
                'Your next reminder is "${active.first.title}" — I will keep it on your calendar.',
              'Use "every day" for habits: "remind me to drink water every day at 9am".',
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final title = TextEditingController();
    DateTime when = easternNow().add(const Duration(hours: 1));
    String? repeat;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                Text('New reminder',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickChips
                      .map((c) => ActionChip(
                            label: Text(c,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5)),
                            backgroundColor:
                                AppColors.greenSoft,
                            onPressed: () =>
                                setSheet(() => title.text = c),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: title, label: 'Remind me to…'),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                      DateFormat('EEE, MMM d • h:mm a')
                          .format(when)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: easternNow(),
                      lastDate: easternNow()
                          .add(const Duration(days: 365)),
                      initialDate: when,
                    );
                    if (d == null) return;
                    if (!ctx.mounted) return;
                    final tm = await showTimePicker(
                        context: ctx,
                        initialTime:
                            TimeOfDay.fromDateTime(when));
                    if (tm == null) return;
                    setSheet(() => when = DateTime(d.year, d.month,
                        d.day, tm.hour, tm.minute));
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: repeat,
                  decoration: const InputDecoration(
                      labelText: 'Repeat (optional)'),
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('No repeat')),
                    DropdownMenuItem(
                        value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(
                        value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(
                        value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) =>
                      setSheet(() => repeat = v),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save reminder',
                  onPressed: () async {
                    if (title.text.trim().isEmpty) return;
                    final uid =
                        context.read<AppState>().profile?.id ?? '';
                    await context.read<AppState>().addReminder(
                          Reminder(
                            id: const Uuid().v4(),
                            userId: uid,
                            title: title.text.trim(),
                            remindAt: when,
                            repeat: repeat,
                          ),
                        );
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

  // =============================================================== PETS TAB
  Widget _petsTab(BuildContext context, AppState app) {
    final pets = app.pets;
    return Column(
      children: [
        if (pets.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: pets
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p.name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          selected: _selectedPetId(app) == p.id,
                          selectedColor: AppColors.greenSoft,
                          onSelected: (_) =>
                              setState(() => _petId = p.id),
                        ),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: pets.isEmpty
              ? _noPetState(context, app)
              : RefreshIndicator(
                  onRefresh: () => app.loadAll(),
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    children: [
                      const SectionHeader(title: 'Pet reminders'),
                      ..._petReminderItems(context, app),
                      const SizedBox(height: 8),
                      _petProfileCard(context, app),
                      const SizedBox(height: 10),
                      _lostPetCard(context, app),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _noPetState(BuildContext context, AppState app) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CategoryIcon(category: 'pet', size: 72),
              const SizedBox(height: 16),
              Text('Add your first pet',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Pet Reminders is pets-only: feeding, vet visits, grooming, walks and medicine — all organized per pet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Add a pet',
                icon: Icons.pets_rounded,
                onPressed: () => _showEditPet(context, app, null),
              ),
            ],
          ),
        ),
      );

  List<Widget> _petReminderItems(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final list = app.petRemindersFor(petId);
    if (list.isEmpty) {
      return [
        const EmptyState(
            message:
                'No pet reminders. Add feeding, vet, grooming, walk or medicine reminders.',
            icon: Icons.pets_rounded),
      ];
    }
    return list
        .map((r) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.card3D(radius: 18),
              child: ListTile(
                leading: const CategoryIcon(
                    category: 'pet', size: 42),
                title: Text(r.title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  DateFormat('EEE, MMM d • h:mm a')
                      .format(r.remindAt),
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.muted),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: AppColors.deepGreen),
                  onPressed: () => app.toggleReminder(r.id),
                ),
              ),
            ))
        .toList();
  }

  Widget _petProfileCard(BuildContext context, AppState app) {
    final pet = _currentPet(app)!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showEditPet(context, app, pet),
      child: Container(
        decoration: AppTheme.heroGradient(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(18),
                image: (pet.photoPath ?? '').isNotEmpty
                    ? DecorationImage(
                        image:
                            FileImage(File(pet.photoPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (pet.photoPath ?? '').isEmpty
                  ? const Icon(Icons.pets_rounded,
                      color: Colors.white, size: 30)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pet Profile',
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(pet.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  Text(
                    '${pet.species[0].toUpperCase()}${pet.species.substring(1)}${pet.breed != null ? ' • ${pet.breed}' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _vaccinesCard(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final count = app.vaccinationsFor(petId).length;
    final overdue =
        app.vaccinationsFor(petId).where((v) => v.isOverdue).length;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showVaccinesSheet(context, app),
      child: Container(
        decoration: AppTheme.card3D(radius: 20),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CategoryIcon(category: 'health', size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vaccinations',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(
                    count == 0
                        ? 'No vaccinations recorded'
                        : '$count recorded${overdue > 0 ? ' • $overdue OVERDUE' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: overdue > 0
                            ? AppColors.danger
                            : AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _lostPetCard(BuildContext context, AppState app) {
    return Container(
      decoration: AppTheme.card3D(radius: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CategoryIcon(category: 'health', size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Lost Pet Alert',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If ${_currentPet(app)?.name ?? 'your pet'} goes missing, alert fast and call the 24/7 pet poison helpline if needed.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon:
                      const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share alert'),
                  onPressed: () => _shareLostPet(context, app),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('ASPCA 24/7'),
                  onPressed: () => launchUrl(
                      Uri.parse('tel:+18884264435')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareLostPet(BuildContext context, AppState app) {
    final pet = _currentPet(app);
    final text =
        'LOST PET ALERT: ${pet?.name ?? 'My pet'} (${pet?.species ?? ''}${pet?.breed != null ? ' • ${pet!.breed}' : ''}) is missing. Please contact me if seen!';
    launchUrl(Uri.parse('sms:?body=${Uri.encodeComponent(text)}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Alert drafted — send it to spread the word.')),
    );
  }

  void _showAddPetReminder(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final title = TextEditingController();
    String type = _petTypes.first;
    DateTime when = easternNow().add(const Duration(hours: 1));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Pet reminder — ${app.petName(petId)}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Pets only — pick a type below.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _petTypes
                      .map((t) => ChoiceChip(
                            label: Text(t,
                                style: GoogleFonts.poppins(
                                    fontSize: 13)),
                            selected: type == t,
                            selectedColor: AppColors.greenSoft,
                            onSelected: (_) =>
                                setSheet(() => type = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: title,
                    label: 'Details (e.g. Morning kibble)'),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(DateFormat('EEE, MMM d • h:mm a')
                      .format(when)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: easternNow(),
                      lastDate: easternNow()
                          .add(const Duration(days: 365)),
                      initialDate: when,
                    );
                    if (d == null || !ctx.mounted) return;
                    final tm = await showTimePicker(
                        context: ctx,
                        initialTime:
                            TimeOfDay.fromDateTime(when));
                    if (tm == null) return;
                    setSheet(() => when = DateTime(d.year,
                        d.month, d.day, tm.hour, tm.minute));
                  },
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save pet reminder',
                  onPressed: () async {
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

  // ------------------------------------------------------- pet profile
  void _showEditPet(
      BuildContext context, AppState app, PetProfile? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final breed = TextEditingController(text: existing?.breed ?? '');
    final weight =
        TextEditingController(text: existing?.weightLbs?.toString() ?? '');
    final notes =
        TextEditingController(text: existing?.notes ?? '');
    String species = existing?.species ?? 'dog';
    DateTime? birth = existing?.birthDate;
    String? photoPath = existing?.photoPath;
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Add a pet' : 'Edit pet',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppTextField(
                    controller: name, label: 'Pet name'),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final img = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          imageQuality: 80);
                      if (img != null) {
                        setSheet(
                            () => photoPath = img.path);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      backgroundImage: photoPath != null
                          ? FileImage(File(photoPath!))
                          : null,
                      child: photoPath == null
                          ? const Icon(
                              Icons.add_a_photo_rounded,
                              color: Colors.white,
                              size: 30)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Tap to add a photo',
                      style: GoogleFonts.poppins(
                          color: AppColors.muted,
                          fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['dog', 'cat', 'bird', 'other']
                      .map((s) => ChoiceChip(
                            label: Text(s,
                                style: GoogleFonts.poppins(
                                    fontSize: 13)),
                            selected: species == s,
                            selectedColor:
                                AppColors.greenSoft,
                            onSelected: (_) =>
                                setSheet(() => species = s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: breed,
                    label: 'Breed (optional)'),
                AppTextField(
                    controller: weight,
                    label: 'Weight in lbs (optional)',
                    keyboardType: TextInputType.number),
                OutlinedButton.icon(
                  icon:
                      const Icon(Icons.cake_outlined),
                  label: Builder(builder: (_) {
                    final b = birth;
                    return Text(b == null
                        ? 'Birth date (optional)'
                        : DateFormat('MM/dd/yyyy')
                            .format(b));
                  }),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: easternNow(),
                      initialDate:
                          birth ?? easternNow(),
                    );
                    if (d != null) {
                      setSheet(() => birth = d);
                    }
                  },
                ),
                const SizedBox(height: 8),
                AppTextField(
                    controller: notes,
                    label: 'Notes (optional)'),
                const SizedBox(height: 8),
                GradientButton(
                  label: existing == null
                      ? 'Add pet'
                      : 'Save changes',
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    final w =
                        double.tryParse(weight.text.trim());
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
                        color: AppColors.danger, size: 18),
                    label: Text('Remove ${existing.name}',
                        style: GoogleFonts.poppins(
                            color: AppColors.danger, fontSize: 14)),
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
        title: Text('Remove ${pet.name}?'),
        content: const Text(
            'This deletes the pet profile, its vaccinations, memories and reminders.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Remove',
                  style:
                      TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _petId = null);
      await app.deletePet(pet.id);
      if (context.mounted) Navigator.pop(context); // close edit sheet
    }
  }

  // -------------------------------------------------------- vaccinations
  void _showVaccinesSheet(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final petId = _selectedPetId(app);
          final list = petId == null
              ? <PetVaccination>[]
              : app.vaccinationsFor(petId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Vaccinations — ${app.petName(petId ?? '')}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: EmptyState(
                        message:
                            'No vaccinations recorded. Add rabies, distemper and more.',
                        icon: Icons.medical_services_outlined),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final v = list[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration:
                              AppTheme.card3D(radius: 18),
                          child: ListTile(
                            leading: CategoryIcon(
                                category: v.isOverdue
                                    ? 'health'
                                    : 'task',
                                size: 42),
                            title: Text(v.vaccineName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontWeight:
                                        FontWeight.w600)),
                            subtitle: Text(
                              'Given ${DateFormat('MM/dd/yyyy').format(v.givenDate)}${v.nextDueDate != null ? ' • Due ${DateFormat('MM/dd/yyyy').format(v.nextDueDate!)}' : ''}${v.isOverdue ? ' • OVERDUE' : ''}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: v.isOverdue
                                      ? AppColors.danger
                                      : AppColors.muted),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.muted),
                              onPressed: () async {
                                await app
                                    .deleteVaccination(v.id);
                                setSheet(() {});
                              },
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
                      child: OutlinedButton.icon(
                        icon: const Icon(
                            Icons.document_scanner_outlined,
                            size: 18),
                        label: const Text('Scan vet card'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context)
                              .pushNamed('/scanner');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GradientButton(
                        label: 'Add',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddVaccine(context, app);
                        },
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

  void _showAddVaccine(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final name = TextEditingController();
    DateTime given = easternNow();
    DateTime? nextDue;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Record vaccination',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppTextField(
                    controller: name,
                    label: 'Vaccine name (e.g. Rabies)'),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                      'Given ${DateFormat('MM/dd/yyyy').format(given)}'),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon:
                      const Icon(Icons.event_repeat_rounded),
                  label: Text(nextDue == null
                      ? 'Next due (optional)'
                      : 'Due ${DateFormat('MM/dd/yyyy').format(nextDue!)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: easternNow(),
                      lastDate: easternNow()
                          .add(const Duration(days: 365 * 5)),
                      initialDate: easternNow().add(
                          const Duration(days: 365)),
                    );
                    if (d != null) {
                      setSheet(() => nextDue = d);
                    }
                  },
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save vaccination',
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    await app.addVaccination(PetVaccination(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      petId: petId,
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

  // ============================================================= HEALTH TAB
  Widget _healthTab(BuildContext context, AppState app) {
    final pet = _currentPet(app);
    if (app.pets.isEmpty || pet == null) {
      return _noPetState(context, app);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        const SectionHeader(title: 'Vaccinations'),
        const SizedBox(height: 8),
        _vaccinesCard(context, app),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Health overview'),
        const SizedBox(height: 8),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A9C63).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Color(0xFF1A9C63), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vaccinations, vet visits & health tips in one place.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, PetHealthAiScreen.route),
          icon: const Icon(Icons.health_and_safety_outlined),
          label: Text(
            'Open Pet Health',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A9C63),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================== MEMORIES TAB
  Widget _memoriesTab(BuildContext context, AppState app) {
    final list = app.petMemories;
    if (app.pets.isEmpty) {
      return _noPetState(context, app);
    }
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyState(
            message:
                'Save favorite moments with your pet — first walk, birthdays, silly faces.',
            icon: Icons.photo_library_outlined),
      );
    }
    return RefreshIndicator(
      onRefresh: () => app.loadAll(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final m = list[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openMemoryViewer(context, list, i),
            child: Container(
              decoration: AppTheme.card3D(radius: 18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _memoryPhoto(m.photoPath),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(app.petName(m.petId),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepGreen)),
                        Text(m.caption,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight:
                                    FontWeight.w600)),
                        Text(
                            DateFormat('MM/dd/yyyy')
                                .format(m.memoryDate),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _memoryPhoto(String? photoPath) {
    if ((photoPath ?? '').isNotEmpty) {
      return Image.file(
        File(photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _memoryPlaceholder(),
      );
    }
    return _memoryPlaceholder();
  }

  Widget _memoryPlaceholder() => Container(
        color: AppColors.greenSoft,
        child: const Icon(Icons.pets_rounded,
            size: 44, color: AppColors.deepGreen),
      );

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

  void _showAddMemory(BuildContext context, AppState app) {
    final caption = TextEditingController();
    String? petId = _selectedPetId(app);
    String? photoPath;
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Save a memory',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: app.pets
                      .map((p) => ChoiceChip(
                            label: Text(p.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 13)),
                            selected: petId == p.id,
                            selectedColor:
                                AppColors.greenSoft,
                            onSelected: (_) =>
                                setSheet(() => petId = p.id),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final source = await showModalBottomSheet<
                        ImageSource>(
                      context: ctx,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                  Icons.photo_camera_outlined),
                              title: const Text('Take a photo'),
                              onTap: () => Navigator.pop(
                                  context,
                                  ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(
                                  Icons.photo_library_outlined),
                              title: const Text(
                                  'Choose from gallery'),
                              onTap: () => Navigator.pop(
                                  context,
                                  ImageSource.gallery),
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
                      color: AppColors.greenSoft,
                      borderRadius:
                          BorderRadius.circular(16),
                      image: photoPath != null
                          ? DecorationImage(
                              image: FileImage(
                                  File(photoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: photoPath == null
                        ? const Center(
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                    Icons.add_a_photo_rounded,
                                    color: AppColors.deepGreen,
                                    size: 32),
                                SizedBox(height: 4),
                                Text('Add a photo'),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: caption,
                    label: 'Caption (e.g. First beach day!)'),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save memory',
                  onPressed: () async {
                    if (caption.text.trim().isEmpty ||
                        petId == null) {
                      return;
                    }
                    await app.addPetMemory(PetMemory(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      petId: petId!,
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
        title: const Text('Delete memory?'),
        content: const Text(
            'This memory photo and caption will be removed.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete',
                  style:
                      TextStyle(color: AppColors.danger))),
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
                        color: Colors.white70,
                        fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white70),
                  onPressed: _deleteCurrent,
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _items.length,
                onPageChanged: (i) =>
                    setState(() => _index = i),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: (item.photoPath ?? '')
                              .isNotEmpty
                          ? Image.file(
                              File(item.photoPath!),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(
                                      Icons.pets_rounded,
                                      size: 80,
                                      color:
                                          Colors.white70),
                            )
                          : const Icon(Icons.pets_rounded,
                              size: 80,
                              color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 8, 20, 20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  Text(app.petName(m.petId),
                      style: GoogleFonts.poppins(
                          color: AppColors.goldLight,
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
                  Text(
                      DateFormat('MM/dd/yyyy')
                          .format(m.memoryDate),
                      style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
