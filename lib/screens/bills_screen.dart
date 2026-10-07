import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/bill.dart';

class BillsScreen extends StatelessWidget {
  static const route = '/bills';
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final unpaid = app.unpaidBills;
    final paid = app.bills.where((b) => b.paidThisMonth).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (app.bills.isEmpty)
            const EmptyState(
                message:
                    'No bills yet. Say "add bill rent \$1800 on the 1st".',
                icon: Icons.receipt_long_outlined),
          if (unpaid.isNotEmpty) ...[
            const SectionHeader(title: 'Due'),
            ...unpaid.map((b) => _billTile(context, b)),
          ],
          if (paid.isNotEmpty) ...[
            const SectionHeader(title: 'Paid this month'),
            ...paid.map((b) => _billTile(context, b)),
          ],
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Bill suggestions',
            suggestions: _suggestions(app),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _billTile(BuildContext context, Bill b) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading:
            const CategoryIcon(category: 'bills', size: 44),
        title: Text(b.name,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                decoration: b.paidThisMonth
                    ? TextDecoration.lineThrough
                    : null)),
        subtitle: Text('Due on the ${b.dueDay}',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.muted)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${b.amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700)),
            Checkbox(
              value: b.paidThisMonth,
              activeColor: AppColors.deepGreen,
              onChanged: (v) =>
                  app.setBillPaid(b.id, v ?? false),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _suggestions(AppState app) {
    final out = <String>[];
    for (final b in app.unpaidBills.take(2)) {
      out.add(
          '${b.name} (\$${b.amount.toStringAsFixed(0)}) is due on the ${b.dueDay} — tick it off when paid.');
    }
    if (out.isEmpty) {
      out.add('All bills are handled. Add one with "add bill internet \$70 on the 15th".');
    }
    return out;
  }

  void _showAddSheet(BuildContext context) {
    final name = TextEditingController();
    final amount = TextEditingController();
    int dueDay = 1;
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
              Text('Add bill',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(controller: name, label: 'Bill name (e.g. Rent)'),
              AppTextField(
                  controller: amount,
                  label: 'Amount (USD)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              Row(
                children: [
                  Text('Due day of month:',
                      style: GoogleFonts.poppins(fontSize: 14)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: dueDay,
                    items: List.generate(28, (i) => i + 1)
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text('$d')))
                        .toList(),
                    onChanged: (v) =>
                        setSheet(() => dueDay = v ?? 1),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save bill',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final amt =
                      double.tryParse(amount.text.trim()) ?? 0;
                  final uid =
                      context.read<AppState>().profile?.id ?? '';
                  await context.read<AppState>().addBill(Bill(
                        id: const Uuid().v4(),
                        userId: uid,
                        name: name.text.trim(),
                        amount: amt,
                        dueDay: dueDay,
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
