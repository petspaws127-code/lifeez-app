import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../models/lent_borrowed.dart';
import '../widgets/ui_kit.dart';

/// Lent & Borrowed tracker: who owes whom, due dates, settle flow.
class LentBorrowedScreen extends StatefulWidget {
  static const route = '/lent-borrowed';
  const LentBorrowedScreen({super.key});

  @override
  State<LentBorrowedScreen> createState() =>
      _LentBorrowedScreenState();
}

class _LentBorrowedScreenState extends State<LentBorrowedScreen> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.lentBorrowed
        .where((e) => _showSettled || !e.settled)
        .toList();
    final net = app.lentBorrowedNet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lent & Borrowed'),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => _showSettled = !_showSettled),
            child: Text(_showSettled ? 'Hide settled' : 'Show settled'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sheet(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Container(
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    decoration: AppTheme.tile3D(
                      const [
                        AppColors.deepGreen,
                        AppColors.greenMid
                      ],
                      radius: 14,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                        Icons.handshake_outlined,
                        color: Colors.white,
                        size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Net balance',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: AppColors.muted)),
                        Text(
                          '${net < 0 ? '−' : ''}\$${net.abs().toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: net >= 0
                                ? AppColors.deepGreen
                                : AppColors.danger,
                          ),
                        ),
                        Text(
                          net >= 0
                              ? 'Others owe you'
                              : 'You owe others',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyState(
                message:
                    'Nothing here. Add money or items you lent or borrowed.',
                icon: Icons.handshake_outlined,
              ),
            for (final e in items) _card(context, app, e),
          ],
        ),
      ),
    );
  }

  Widget _card(
      BuildContext context, AppState app, LentBorrowed e) {
    final lent = e.direction == 'lent';
    final overdue = !e.settled &&
        e.dueDate != null &&
        DateTime(e.dueDate!.year, e.dueDate!.month,
                e.dueDate!.day)
            .isBefore(easternToday());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          decoration: AppTheme.tile3D(
            lent
                ? const [Color(0xFF22C55E), Color(0xFF15803D)]
                : const [Color(0xFFF59E0B), Color(0xFFB45309)],
            radius: 14,
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            lent
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          e.item,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            decoration:
                e.settled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lent ? 'Lent to' : 'Borrowed from'} ${e.person}'
              '${e.amount != null ? ' • \$${e.amount!.toStringAsFixed(2)}' : ''}',
              style: GoogleFonts.poppins(
                  fontSize: 12.5, color: AppColors.muted),
            ),
            if (e.dueDate != null)
              Text(
                overdue
                    ? 'Overdue since ${mmddyyyy(e.dueDate!)}'
                    : 'Due ${mmddyyyy(e.dueDate!)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: overdue
                      ? AppColors.danger
                      : AppColors.muted,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: e.settled
                  ? 'Mark as unsettled'
                  : 'Mark as settled',
              onPressed: () =>
                  app.toggleLentBorrowedSettled(e.id),
              icon: Icon(
                e.settled
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: e.settled
                    ? AppColors.deepGreen
                    : AppColors.muted,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  _sheet(context, e);
                } else {
                  _confirmDelete(context, app, e);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style:
                            TextStyle(color: AppColors.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState app, LentBorrowed e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('Remove "${e.item}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await app.deleteLentBorrowed(e.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _sheet(BuildContext context, LentBorrowed? existing) {
    final app = context.read<AppState>();
    final personCtrl =
        TextEditingController(text: existing?.person ?? '');
    final itemCtrl =
        TextEditingController(text: existing?.item ?? '');
    final amountCtrl = TextEditingController(
        text: existing?.amount?.toStringAsFixed(2) ?? '');
    final noteCtrl =
        TextEditingController(text: existing?.note ?? '');
    String direction = existing?.direction ?? 'lent';
    DateTime? dueDate = existing?.dueDate;

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
            left: 20,
            right: 20,
            top: 16,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(existing == null ? 'Add entry' : 'Edit entry',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'lent',
                        label: Text('I lent'),
                        icon: Icon(Icons.arrow_upward_rounded,
                            size: 18)),
                    ButtonSegment(
                        value: 'borrowed',
                        label: Text('I borrowed'),
                        icon: Icon(Icons.arrow_downward_rounded,
                            size: 18)),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) =>
                      setSheet(() => direction = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.deepGreen,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: personCtrl,
                    label: 'Person’s name'),
                AppTextField(
                    controller: itemCtrl,
                    label: 'What? (e.g. \$50, Lawn mower)'),
                AppTextField(
                  controller: amountCtrl,
                  label: 'Amount in USD (optional)',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                ),
                AppTextField(
                    controller: noteCtrl,
                    label: 'Note (optional)'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dueDate == null
                            ? 'No due date'
                            : 'Due ${mmddyyyy(dueDate!)}',
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: AppColors.muted),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: dueDate ??
                              easternNow()
                                  .add(const Duration(days: 7)),
                          firstDate: easternNow().subtract(
                              const Duration(days: 365)),
                          lastDate: easternNow().add(
                              const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setSheet(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18),
                      label: const Text('Due date'),
                    ),
                    if (dueDate != null)
                      IconButton(
                        onPressed: () =>
                            setSheet(() => dueDate = null),
                        icon: const Icon(Icons.clear_rounded,
                            size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: existing == null ? 'Add' : 'Save',
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      if (personCtrl.text.trim().isEmpty ||
                          itemCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Add a person and what was lent or borrowed.')),
                        );
                        return;
                      }
                      final amount = double.tryParse(
                          amountCtrl.text.trim());
                      if (existing == null) {
                        await app.addLentBorrowed(LentBorrowed(
                          id: const Uuid().v4(),
                          person: personCtrl.text.trim(),
                          item: itemCtrl.text.trim(),
                          amount: amount,
                          direction: direction,
                          date: easternToday(),
                          dueDate: dueDate,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        ));
                      } else {
                        await app.updateLentBorrowed(
                            existing.copyWith(
                          person: personCtrl.text.trim(),
                          item: itemCtrl.text.trim(),
                          amount: amount,
                          clearAmount: amount == null,
                          direction: direction,
                          dueDate: dueDate,
                          clearDueDate: dueDate == null,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        ));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
