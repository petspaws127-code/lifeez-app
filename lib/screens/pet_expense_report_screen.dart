import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/pet.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../theme/app_theme.dart';
import '../widgets/v2_kit.dart';

/// Pet expense report — total + category breakdown + weekly bars.
/// Pro feature (part of the Pets Pro bundle).
class PetExpenseReportScreen extends StatefulWidget {
  static const route = '/pet-expense-report';
  final PetProfile pet;

  const PetExpenseReportScreen({super.key, required this.pet});

  @override
  State<PetExpenseReportScreen> createState() =>
      _PetExpenseReportScreenState();
}

class _PetExpenseReportScreenState extends State<PetExpenseReportScreen> {
  int _monthOffset = 0; // 0 = current month

  DateTime get _month {
    final now = easternNow();
    return DateTime(now.year, now.month - _monthOffset, 1);
  }

  IconData _catIcon(String c) {
    switch (c.toLowerCase()) {
      case 'health':
      case 'vet':
        return Icons.medical_services_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'grooming':
        return Icons.content_cut_outlined;
      case 'toys':
      case 'shopping':
        return Icons.toys_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final m = _month;
    final monthExpenses = app.expenses.where((e) {
      return e.petId == widget.pet.id &&
          e.spentAt.year == m.year &&
          e.spentAt.month == m.month;
    }).toList();

    final total =
        monthExpenses.fold<double>(0, (s, e) => s + e.amount);

    final byCat = <String, double>{};
    for (final e in monthExpenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = sortedCats.isEmpty ? 1.0 : sortedCats.first.value;

    // Weekly buckets (weeks of the month: 1-7, 8-14, 15-21, 22+).
    final weeks = [0.0, 0.0, 0.0, 0.0];
    for (final e in monthExpenses) {
      var w = (e.spentAt.day - 1) ~/ 7;
      if (w > 3) w = 3;
      weeks[w] += e.amount;
    }
    final maxWeek =
        weeks.fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: V2.bg,
      appBar: AppBar(
        backgroundColor: V2.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: V2.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.pet.name} — ${DateFormat('MMMM').format(m)}',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: V2.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: V2.ink),
            onPressed: () =>
                setState(() => _monthOffset++),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: _monthOffset > 0 ? V2.ink : V2.muted),
            onPressed: _monthOffset > 0
                ? () => setState(() => _monthOffset--)
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            V2Card(
              child: Column(
                children: [
                  Text('Total spent',
                      style: V2.sub(14)),
                  const SizedBox(height: 4),
                  Text('\$${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: V2.ink)),
                  const SizedBox(height: 4),
                  Text(
                      '${monthExpenses.length} expense${monthExpenses.length == 1 ? '' : 's'}',
                      style: V2.sub(13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const V2SectionLabel('By category'),
            if (sortedCats.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    'No pet expenses this month yet.',
                    style: V2.sub(14)),
              ),
            ...sortedCats.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: V2.chip,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: Icon(_catIcon(e.key),
                            color: V2.green, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Text(e.key,
                                    style: V2.title(15)),
                                Text(
                                    '\$${e.value.toStringAsFixed(2)}',
                                    style:
                                        GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: V2.ink)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(4),
                              child:
                                  LinearProgressIndicator(
                                value: maxCat == 0
                                    ? 0
                                    : e.value / maxCat,
                                minHeight: 6,
                                backgroundColor:
                                    V2.chip,
                                valueColor:
                                    const AlwaysStoppedAnimation<
                                        Color>(V2.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            const V2SectionLabel('Weekly spending'),
            if (maxWeek == 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text('No data yet.',
                    style: V2.sub(14)),
              )
            else
              V2Card(
                child: SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children:
                        List.generate(4, (i) {
                      final h = maxWeek == 0
                          ? 0.0
                          : (weeks[i] / maxWeek) * 100;
                      return Column(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Text(
                              '\$${weeks[i].toStringAsFixed(0)}',
                              style: V2.sub(11)),
                          const SizedBox(height: 4),
                          Container(
                            width: 36,
                            height: h < 4 && weeks[i] > 0
                                ? 4
                                : h,
                            decoration: BoxDecoration(
                              color: V2.green.withOpacity(
                                  0.35 + 0.65 * (i / 3)),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('W${i + 1}',
                              style: V2.sub(12)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
