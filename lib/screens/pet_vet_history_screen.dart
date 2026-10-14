import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/pet.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../theme/app_theme.dart';
import '../widgets/v2_kit.dart';

/// Vet history timeline with PDF export.
/// Pro feature (part of the Pets Pro bundle).
class PetVetHistoryScreen extends StatefulWidget {
  static const route = '/pet-vet-history';
  final PetProfile pet;

  const PetVetHistoryScreen({super.key, required this.pet});

  @override
  State<PetVetHistoryScreen> createState() => _PetVetHistoryScreenState();
}

class _PetVetHistoryScreenState extends State<PetVetHistoryScreen> {
  bool _exporting = false;

  Future<void> _addVisit() async {
    final app = context.read<AppState>();
    final reason = TextEditingController();
    final vetName = TextEditingController();
    final notes = TextEditingController();
    final costCtrl = TextEditingController();
    DateTime date = easternNow();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Log vet visit — ${widget.pet.name}',
                    style: V2.title(18)),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  decoration: InputDecoration(
                    labelText: 'Reason (e.g. Annual checkup)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon:
                      const Icon(Icons.event_rounded, color: V2.green),
                  label: Text(
                    DateFormat('MM/dd/yyyy').format(date),
                    style: GoogleFonts.poppins(
                        color: V2.ink, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: easternNow(),
                    );
                    if (picked != null) {
                      setSheet(() => date = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vetName,
                  decoration: InputDecoration(
                    labelText: 'Vet name (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cost \$ (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                V2PrimaryButton(
                  label: 'Save visit',
                  onTap: () async {
                    if (reason.text.trim().isEmpty) return;
                    final v = PetVetVisit(
                      id: const Uuid().v4(),
                      userId: app.profile?.id ?? '',
                      petId: widget.pet.id,
                      visitDate: date,
                      reason: reason.text.trim(),
                      vetName: vetName.text.trim().isEmpty
                          ? null
                          : vetName.text.trim(),
                      notes: notes.text.trim().isEmpty
                          ? null
                          : notes.text.trim(),
                      cost: double.tryParse(
                          costCtrl.text.trim()),
                    );
                    await app.addVetVisit(v);
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

  Future<void> _exportPdf(List<PetVetVisit> visits) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      final pet = widget.pet;
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                '${pet.name} — Vet History',
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              'Breed: ${pet.breed ?? '-'}   '
              'Exported: ${DateFormat('MM/dd/yyyy').format(easternNow())}',
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            if (visits.isEmpty)
              pw.Text('No vet visits recorded.',
                  style: const pw.TextStyle(fontSize: 13)),
            ...visits.map((v) => pw.Container(
                  margin:
                      const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey300),
                    borderRadius:
                        pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment
                                .spaceBetween,
                        children: [
                          pw.Text(v.reason,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      pw.FontWeight.bold)),
                          pw.Text(
                            DateFormat('MM/dd/yyyy')
                                .format(v.visitDate),
                            style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      if (v.vetName?.isNotEmpty ==
                          true)
                        pw.Text('Vet: ${v.vetName}',
                            style: const pw.TextStyle(
                                fontSize: 12)),
                      if (v.notes?.isNotEmpty == true)
                        pw.Padding(
                          padding:
                              const pw.EdgeInsets.only(
                                  top: 4),
                          child: pw.Text(
                              'Notes: ${v.notes}',
                              style: const pw.TextStyle(
                                  fontSize: 12)),
                        ),
                      if (v.cost != null)
                        pw.Text(
                            'Cost: \$${v.cost!.toStringAsFixed(2)}',
                            style: const pw.TextStyle(
                                fontSize: 12)),
                    ],
                  ),
                )),
            pw.SizedBox(height: 16),
            pw.Text(
              'Generated by Lifeez — AI guidance only, not a substitute for a vet.',
              style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600),
            ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${pet.name}-vet-history.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final visits = app.vetVisitsFor(widget.pet.id);
    return Scaffold(
      backgroundColor: V2.bg,
      appBar: AppBar(
        backgroundColor: V2.bg,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: V2.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.pet.name} — Vet history',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: V2.ink)),
        actions: [
          TextButton.icon(
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: V2.green),
                  )
                : const Icon(Icons.download_rounded,
                    color: V2.green, size: 20),
            label: Text('PDF',
                style: GoogleFonts.poppins(
                    color: V2.green,
                    fontWeight: FontWeight.w700)),
            onPressed: visits.isEmpty
                ? null
                : () => _exportPdf(visits),
          ),
        ],
      ),
      body: SafeArea(
        child: visits.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const V2IconTile(
                          Icons.medical_services_outlined,
                          size: 72),
                      const SizedBox(height: 16),
                      Text('No vet visits yet',
                          style: V2.title(18)),
                      const SizedBox(height: 8),
                      Text(
                        'Log every vet visit to build a complete health history.',
                        textAlign: TextAlign.center,
                        style: V2.sub(14),
                      ),
                      const SizedBox(height: 16),
                      V2PrimaryButton(
                        label: 'Log first visit',
                        onTap: _addVisit,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ...visits.map((v) => IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration:
                                      const BoxDecoration(
                                    color: V2.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: V2.chip,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 16),
                                child: V2Card(
                                  padding:
                                      const EdgeInsets.all(
                                          14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                                v.reason,
                                                style:
                                                    V2.title(
                                                        16)),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .delete_outline_rounded,
                                                color:
                                                    V2.muted,
                                                size: 20),
                                            onPressed: () =>
                                                app.deleteVetVisit(
                                                    v.id),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        DateFormat(
                                                'MM/dd/yyyy')
                                            .format(
                                                v.visitDate),
                                        style:
                                            V2.sub(13),
                                      ),
                                      if (v.vetName
                                              ?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(
                                            height: 4),
                                        Text(
                                            'Dr. ${v.vetName}',
                                            style:
                                                V2.body(
                                                    13)),
                                      ],
                                      if (v.notes
                                              ?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(
                                            height: 4),
                                        Text(v.notes!,
                                            style:
                                                V2.sub(
                                                    13)),
                                      ],
                                      if (v.cost !=
                                          null) ...[
                                        const SizedBox(
                                            height: 4),
                                        Text(
                                          '\$${v.cost!.toStringAsFixed(2)}',
                                          style: GoogleFonts
                                              .poppins(
                                                  fontSize:
                                                      14,
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                  color: V2
                                                      .green),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  V2PrimaryButton(
                    label: 'Export PDF',
                    onTap: _exporting
                        ? () {}
                        : () => _exportPdf(visits),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded,
                          color: V2.green),
                      label: Text('Log vet visit',
                          style: GoogleFonts.poppins(
                              color: V2.green,
                              fontWeight:
                                  FontWeight.w600)),
                      onPressed: _addVisit,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
