import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/bill_scanner_service.dart';
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
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadAll(),
        child: ListView(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  /// FAB menu: scan with camera, upload from gallery, or add manually.
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add bill',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _addOptionTile(
                ctx,
                icon: Icons.document_scanner_outlined,
                title: 'Scan bill',
                subtitle: 'Use the camera to scan a paper bill',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndScan(context, ImageSource.camera);
                },
              ),
              _addOptionTile(
                ctx,
                icon: Icons.upload_file_outlined,
                title: 'Upload bill',
                subtitle: 'Pick a photo from your gallery',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndScan(context, ImageSource.gallery);
                },
              ),
              _addOptionTile(
                ctx,
                icon: Icons.edit_outlined,
                title: 'Add manually',
                subtitle: 'Type the bill details yourself',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddSheet(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addOptionTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.deepGreen),
      ),
      title: Text(title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.muted)),
      onTap: onTap,
    );
  }

  /// Pick an image, run OCR with a loading indicator, then open review.
  Future<void> _pickAndScan(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600);
    if (picked == null || !context.mounted) return;

    // Show a loading indicator while OCR runs.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlg) => const Center(
        child: SizedBox(
          width: 46,
          height: 46,
          child: CircularProgressIndicator(color: AppColors.deepGreen),
        ),
      ),
    );

    final result =
        await BillScannerService().extractFromImage(picked.path);
    if (context.mounted) Navigator.pop(context); // dismiss loading

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillReviewScreen(
          imagePath: picked.path,
          scan: result,
        ),
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

/// Full review screen shown after scanning/uploading a bill photo.
/// The bill photo is shown at the top; extracted details are pre-filled
/// and editable. OCR failures just leave the fields empty for manual entry.
class BillReviewScreen extends StatefulWidget {
  final String imagePath;
  final BillScanResult scan;

  const BillReviewScreen({
    super.key,
    required this.imagePath,
    required this.scan,
  });

  @override
  State<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends State<BillReviewScreen> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late int _dueDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final scan = widget.scan;
    _name = TextEditingController(text: scan.merchant);
    _amount = TextEditingController(
        text: scan.amount > 0 ? scan.amount.toStringAsFixed(2) : '');
    final scannedDay = scan.date?.day;
    _dueDay = (scannedDay != null && scannedDay >= 1 && scannedDay <= 28)
        ? scannedDay
        : 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bill name.')),
      );
      return;
    }
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    setState(() => _saving = true);
    final uid = context.read<AppState>().profile?.id ?? '';
    await context.read<AppState>().addBill(Bill(
          id: const Uuid().v4(),
          userId: uid,
          name: name,
          amount: amt,
          dueDay: _dueDay,
        ));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bill saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review bill'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: AppColors.deepGreen,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Bill photo thumbnail.
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(widget.imagePath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 180,
                  color: AppColors.greenSoft,
                  alignment: Alignment.center,
                  child: const Icon(Icons.receipt_long_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Check the details — edit anything before saving.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.muted),
            ),
            if (widget.scan.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.card3D(radius: 14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.deepGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Could not read the bill automatically. Fill in the details below.',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(controller: _name, label: 'Bill name (e.g. Rent)'),
            AppTextField(
              controller: _amount,
              label: 'Amount (USD)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            Row(
              children: [
                Text('Due day of month:',
                    style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _dueDay,
                  items: List.generate(28, (i) => i + 1)
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _dueDay = v ?? 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: _saving ? 'Saving…' : 'Save bill',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Retake / pick another',
                  style: GoogleFonts.poppins(
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
