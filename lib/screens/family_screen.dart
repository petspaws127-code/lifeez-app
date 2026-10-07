import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/family_member.dart';
import '../services/eastern_time.dart';

class FamilyScreen extends StatelessWidget {
  static const route = '/family';
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sorted = [...app.familyMembers]..sort((a, b) {
        final da = a.daysUntilBirthday ?? 9999;
        final db = b.daysUntilBirthday ?? 9999;
        return da.compareTo(db);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (sorted.isEmpty)
            const EmptyState(
                message:
                    'Add family members to never miss a birthday.',
                icon: Icons.people_outline)
          else
            ...sorted.map(
              (f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: const CategoryIcon(
                      category: 'family', size: 44),
                  title: Text(f.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (f.relationship.isNotEmpty)
                        f.relationship,
                      if (f.birthday != null)
                        'Birthday ${DateFormat('MMM d').format(f.birthday!)}'
                    ].join(' • ',
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.muted),
                  ),
                  trailing: f.daysUntilBirthday == null
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            f.daysUntilBirthday == 0
                                ? 'Today!'
                                : '${f.daysUntilBirthday}d',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen),
                          ),
                        ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Family suggestions',
            suggestions: [
              for (final f in sorted.take(2))
                if (f.daysUntilBirthday != null &&
                    f.daysUntilBirthday! <= 14)
                  '${f.name}\u2019s birthday is in ${f.daysUntilBirthday} days — plan something nice.',
              if (sorted.isEmpty)
                'Birthdays you add here also appear on your calendar.',
            ],
          ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final name = TextEditingController();
    final relation = TextEditingController();
    DateTime? birthday;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add family member',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(controller: name, label: 'Name'),
              AppTextField(
                  controller: relation,
                  label: 'Relationship (e.g. Mom)'),
              OutlinedButton.icon(
                icon: const Icon(Icons.cake_outlined),
                label: Text(birthday == null
                    ? 'Pick birthday'
                    : DateFormat('MMM d, yyyy')
                        .format(birthday!)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(1920),
                    lastDate: easternNow(),
                    initialDate:
                        DateTime(easternNow().year - 30),
                  );
                  if (d != null) {
                    setSheet(() => birthday = d);
                  }
                },
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context
                      .read<AppState>()
                      .addFamilyMember(FamilyMember(
                        id: const Uuid().v4(),
                        userId: uid,
                        name: name.text.trim(),
                        relationship:
                            relation.text.trim(),
                        birthday: birthday,
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
}
