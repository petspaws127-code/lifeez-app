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
import '../models/document_item.dart';
import '../services/eastern_time.dart';

class DocumentsScreen extends StatelessWidget {
  static const route = '/documents';
  const DocumentsScreen({super.key});

  Color _expiryColor(int? days) {
    if (days == null) return AppColors.muted;
    if (days < 0) return AppColors.danger;
    if (days <= 30) return const Color(0xFFB45309);
    return AppColors.deepGreen;
  }

  String _expiryLabel(int? days) {
    if (days == null) return 'No expiry set';
    if (days < 0) return 'Expired ${-days}d ago';
    if (days == 0) return 'Expires today';
    return 'Expires in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (app.documents.isEmpty)
            const EmptyState(
                message:
                    'Track passports, licenses and insurance with expiry alerts.',
                icon: Icons.description_outlined)
          else
            ...app.documents.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppTheme.card3D(radius: 18),
                child: ListTile(
                  leading: const CategoryIcon(
                      category: 'document', size: 44),
                  title: Text(d.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    d.expiryDate == null
                        ? 'No expiry set'
                        : 'Expiry: ${DateFormat('MMM d, yyyy').format(d.expiryDate!)}',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.muted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expiryLabel(d.daysUntilExpiry),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _expiryColor(
                                d.daysUntilExpiry)),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.danger),
                        onPressed: () =>
                            app.deleteDocument(d.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Document suggestions',
            suggestions: [
              for (final d in app.documents)
                if (d.daysUntilExpiry != null &&
                    d.daysUntilExpiry! <= 60)
                  '${d.name}: ${_expiryLabel(d.daysUntilExpiry)} — renew it before it lapses.',
              if (app.documents.isEmpty)
                'Add your passport and driver license so expiry never surprises you.',
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
    DateTime? expiry;
    String type = 'other';
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
              Text('Add document',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(
                  controller: name,
                  label: 'Document name (e.g. Passport)'),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration:
                    const InputDecoration(labelText: 'Type'),
                items: const [
                  'passport',
                  'license',
                  'registration',
                  'insurance',
                  'other'
                ]
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setSheet(() => type = v ?? 'other'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(expiry == null
                    ? 'Pick expiry date'
                    : DateFormat('MMM d, yyyy')
                        .format(expiry!)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: easternNow()
                        .add(const Duration(days: 3650)),
                    initialDate: easternNow(),
                  );
                  if (d != null) {
                    setSheet(() => expiry = d);
                  }
                },
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save document',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addDocument(
                        DocumentItem(
                          id: const Uuid().v4(),
                          userId: uid,
                          name: name.text.trim(),
                          docType: type,
                          expiryDate: expiry,
                        ),
                      );
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
