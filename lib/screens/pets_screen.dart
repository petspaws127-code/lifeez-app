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
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/pet.dart';
import '../models/reminder.dart';
import '../services/eastern_time.dart';

/// Pet Reminders — PETS ONLY. Feeding, vet, grooming, walk, medicine
/// presets plus Pet Profile, Vaccination Record, Lost Pet Alert and
/// Save Memories. Non-pet entries are rejected.
class PetsScreen extends StatefulWidget {
  static const route = '/pets';
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  int _tab = 0; // 0 reminders, 1 profile, 2 vaccinations, 3 memories

  static const _petTypes = ['feeding', 'vet', 'grooming', 'walk', 'medicine'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pets = app.pets;

    return Scaffold(
      appBar: AppBar(title: const Text('Pet Reminders')),
      body: Column(
        children: [
          // Pet selector chips
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
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _tabBtn('Reminders', 0),
                _tabBtn('Profile', 1),
                _tabBtn('Vaccines', 2),
                _tabBtn('Memories', 3),
              ],
            ),
          ),
          Expanded(
            child: pets.isEmpty
                ? _noPetState(context)
                : RefreshIndicator(
                    onRefresh: () => app.loadAll(),
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _remindersTab(context, app),
                        _profileTab(context, app),
                        _vaccinesTab(context, app),
                        _memoriesTab(context, app),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: pets.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _tab == 0
                  ? _showAddPetReminder(context, app)
                  : _tab == 2
                      ? _showAddVaccine(context, app)
                      : _tab == 3
                          ? _showAddMemory(context, app)
                          : _showEditPet(context, app, _currentPet(app)!),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  String? _petId;

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

  Widget _tabBtn(String label, int i) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _tab == i
                      ? AppColors.deepGreen
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight:
                    _tab == i ? FontWeight.w700 : FontWeight.w500,
                color: _tab == i
                    ? AppColors.deepGreen
                    : AppColors.muted,
              ),
            ),
          ),
        ),
      );

  Widget _noPetState(BuildContext context) => Center(
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
                onPressed: () => _showEditPet(context,
                    context.read<AppState>(), null),
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------- reminders
  Widget _remindersTab(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final list = app.petRemindersFor(petId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (list.isEmpty)
          const EmptyState(
              message:
                  'No pet reminders. Add feeding, vet, grooming, walk or medicine reminders.',
              icon: Icons.pets_rounded),
        ...list.map((r) => Container(
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
            )),
        const SizedBox(height: 8),
        // Lost pet alert card
        Container(
          decoration: AppTheme.card3D(radius: 20),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CategoryIcon(
                      category: 'health', size: 40),
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
                      icon: const Icon(Icons.share_rounded,
                          size: 18),
                      label: const Text('Share alert'),
                      onPressed: () =>
                          _shareLostPet(context, app),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.call_rounded,
                          size: 18),
                      label: const Text('ASPCA 24/7'),
                      onPressed: () => launchUrl(Uri.parse(
                          'tel:+18884264435')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _shareLostPet(BuildContext context, AppState app) {
    final pet = _currentPet(app);
    final text =
        'LOST PET ALERT: ${pet?.name ?? 'My pet'} (${pet?.species ?? ''}${pet?.breed != null ? ' • ${pet!.breed}' : ''}) is missing. Please contact me if seen!';
    // Share via system share sheet through url_launcher fallback:
    // use a plain share intent text via sms: body.
    launchUrl(Uri.parse(
        'sms:?body=${Uri.encodeComponent(text)}'));
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pet reminder — ${app.petName(petId)}',
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
    );
  }

  // ------------------------------------------------------------ profile
  Widget _profileTab(BuildContext context, AppState app) {
    final pet = _currentPet(app)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        Container(
          decoration: AppTheme.heroGradient(),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    _showEditPet(context, app, pet),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(20),
                    image: (pet.photoPath ?? '').isNotEmpty
                        ? DecorationImage(
                            image: FileImage(
                                File(pet.photoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (pet.photoPath ?? '').isEmpty
                      ? const Icon(Icons.pets_rounded,
                          color: Colors.white, size: 34)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(pet.name,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text(
                      '${pet.species[0].toUpperCase()}${pet.species.substring(1)}${pet.breed != null ? ' • ${pet.breed}' : ''}',
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white),
                onPressed: () =>
                    _showEditPet(context, app, pet),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _infoRow('Birth date',
            pet.birthDate != null ? DateFormat('MM/dd/yyyy').format(pet.birthDate!) : '—'),
        _infoRow('Weight',
            pet.weightLbs != null ? '${pet.weightLbs!.toStringAsFixed(1)} lbs' : '—'),
        if (pet.notes != null && pet.notes!.isNotEmpty)
          _infoRow('Notes', pet.notes!),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmDeletePet(context, app, pet),
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.danger, size: 18),
          label: Text('Remove ${pet.name}',
              style: GoogleFonts.poppins(
                  color: AppColors.danger, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppTheme.card3D(radius: 16),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    color: AppColors.muted, fontSize: 13.5)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      );

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
    }
  }

  // ----------------------------------------------------------- vaccines
  Widget _vaccinesTab(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final list = app.vaccinationsFor(petId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (list.isEmpty)
          const EmptyState(
              message:
                  'No vaccinations recorded. Add rabies, distemper and more.',
              icon: Icons.medical_services_outlined),
        ...list.map((v) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.card3D(radius: 18),
              child: ListTile(
                leading: CategoryIcon(
                    category:
                        v.isOverdue ? 'health' : 'task',
                    size: 42),
                title: Text(v.vaccineName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Given ${DateFormat('MM/dd/yyyy').format(v.givenDate)}${v.nextDueDate != null ? ' • Due ${DateFormat('MM/dd/yyyy').format(v.nextDueDate!)}' : ''}${v.isOverdue ? ' • OVERDUE' : ''}',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: v.isOverdue
                          ? AppColors.danger
                          : AppColors.muted),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.muted),
                  onPressed: () =>
                      app.deleteVaccination(v.id),
                ),
              ),
            )),
      ],
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
                icon: const Icon(Icons.event_repeat_rounded),
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
    );
  }

  // ----------------------------------------------------------- memories
  Widget _memoriesTab(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final list = app.memoriesFor(petId);
    return list.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
                message:
                    'Save favorite moments with your pet — first walk, birthdays, silly faces.',
                icon: Icons.photo_library_outlined),
          )
        : GridView.builder(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 90),
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
              return Container(
                decoration: AppTheme.card3D(radius: 18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        color: AppColors.greenSoft,
                        child: const Icon(
                            Icons.pets_rounded,
                            size: 44,
                            color: AppColors.deepGreen),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(m.caption,
                              maxLines: 2,
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
              );
            },
          );
  }

  void _showAddMemory(BuildContext context, AppState app) {
    final petId = _selectedPetId(app)!;
    final caption = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
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
            Text('Save a memory',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: caption,
                label: 'Caption (e.g. First beach day!)'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save memory',
              onPressed: () async {
                if (caption.text.trim().isEmpty) return;
                await app.addPetMemory(PetMemory(
                  id: const Uuid().v4(),
                  userId: app.profile?.id ?? '',
                  petId: petId,
                  caption: caption.text.trim(),
                  memoryDate: easternNow(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
