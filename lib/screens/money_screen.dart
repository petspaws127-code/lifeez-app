import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../services/smart_ai_service.dart';
import '../services/supabase_client.dart';
import '../widgets/v2_kit.dart';
import 'budgets_screen.dart';

/// V2 Money — hero "Spent today", Today/Week/Month pills, category
/// spent-of-budget bars (budgets from SharedPreferences 'v2_budgets'),
/// transaction rows with delete, add-expense dialog.
/// Full-screen route with V2SubNav.
class MoneyScreen extends StatefulWidget {
  static const route = '/money';
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  int _tab = 0; // 0 = Today, 1 = Week, 2 = Month
  Map<String, double> _budgets =
      Map<String, double>.from(V2Budgets.defaultValues);

  @override
  void initState() {
    super.initState();
    V2Budgets.load().then((m) {
      if (mounted) setState(() => _budgets = m);
    });
  }

  // ------------------------------------------------------------- aggregations

  /// Formats currency with minus sign BEFORE the dollar sign: -$5020.00
  String _fmtMoney(double v) {
    final abs = v.abs();
    final formatted = abs.toStringAsFixed(2);
    return v < 0 ? '-\$$formatted' : '\$$formatted';
  }

  bool _isToday(DateTime d) {
    final n = easternNow();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  double _spentToday(AppState app) => app.expenses
      .where((e) => _isToday(e.spentAt))
      .fold(0.0, (s, e) => s + e.amount);

  List<Expense> _todaysExpenses(AppState app) {
    final list =
        app.expenses.where((e) => _isToday(e.spentAt)).toList();
    list.sort((a, b) => b.spentAt.compareTo(a.spentAt));
    return list;
  }

  /// This month's spend per canonical category.
  Map<String, double> _monthTotalsByCat(AppState app) {
    final now = easternNow();
    final map = {for (final c in V2Budgets.categories) c: 0.0};
    for (final e in app.expenses) {
      if (e.spentAt.year == now.year &&
          e.spentAt.month == now.month) {
        final c = V2Budgets.normalize(e.category);
        map[c] = (map[c] ?? 0) + e.amount;
      }
    }
    return map;
  }

  DateTime get _weekMonday {
    final n = easternNow();
    final today = DateTime(n.year, n.month, n.day);
    return today.subtract(Duration(days: n.weekday - 1));
  }

  /// Spend for Mon..Sun of the current week (7 values).
  List<double> _weekDaily(AppState app) {
    final monday = _weekMonday;
    final days = List<double>.filled(7, 0);
    for (final e in app.expenses) {
      final d = DateTime(
          e.spentAt.year, e.spentAt.month, e.spentAt.day);
      final idx = d.difference(monday).inDays;
      if (idx >= 0 && idx < 7) days[idx] += e.amount;
    }
    return days;
  }

  Map<String, double> _weekTotalsByCat(AppState app) {
    final monday = _weekMonday;
    final sundayEnd = monday.add(const Duration(days: 7));
    final map = <String, double>{};
    for (final e in app.expenses) {
      if (!e.spentAt.isBefore(monday) &&
          e.spentAt.isBefore(sundayEnd)) {
        final c = V2Budgets.normalize(e.category);
        map[c] = (map[c] ?? 0) + e.amount;
      }
    }
    return map;
  }

  // ------------------------------------------------------------------ actions

  Future<void> _confirmDelete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete expense?', style: V2.title(18)),
        content: Text(
            '${e.note.isEmpty ? e.category : e.note} — \$${e.amount.toStringAsFixed(2)}',
            style: V2.body()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.poppins(
                      color: V2.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().deleteExpense(e.id);
    }
  }

  void _showExpenseDetail(Expense e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('-\$${e.amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800, fontSize: 22)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${V2Budgets.normalize(e.category)} • ${DateFormat('MM/dd/yyyy').format(e.spentAt)}',
                  style: V2.sub()),
              if (e.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(e.note, style: V2.body()),
              ],
              if ((e.receiptPath ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(e.receiptPath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: V2.sub().copyWith(fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmDelete(e);
            },
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: V2.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// After an expense is saved: prompt to set a budget for the category
  /// if none is set, or warn if the category is over budget.
  Future<void> _checkBudgetAfterExpense(
      BuildContext ctx, String category, Map<String, double> budgets) async {
    final app = context.read<AppState>();
    final budget = budgets[category] ?? 0;

    // Calculate total spent in this category this month.
    final now = easternNow();
    final spentInCat = app.expenses
        .where((e) =>
            V2Budgets.normalize(e.category) ==
                V2Budgets.normalize(category) &&
            e.spentAt.year == now.year &&
            e.spentAt.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);

    // Case 1: No budget set — prompt to set one.
    if (budget <= 0) {
      final ctrl = TextEditingController();
      final result = await showDialog<double>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Set budget for $category', style: V2.title(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You added an expense in $category. Set a monthly budget for it?',
                  style: V2.sub(14)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monthly budget (USD)',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: V2.chip,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text('Skip', style: V2.sub().copyWith(fontSize: 14)),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.trim());
                Navigator.pop(dctx, v != null && v >= 0 ? v : null);
              },
              child: Text('Save',
                  style: V2.greenLabel(14)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (result != null) {
        budgets[category] = result;
        await V2Budgets.save(budgets);
        if (mounted) setState(() => _budgets = Map.from(budgets));
      }
      return;
    }

    // Case 2: Over budget — show warning.
    if (spentInCat > budget) {
      final over = spentInCat - budget;
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Over budget in $category by ${_fmtMoney(over)}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showAddDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'Other';
    // Load fresh budgets every time the dialog opens, so custom
    // categories added via Budgets > Add category always appear.
    final freshBudgets = await V2Budgets.load();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Add expense', style: V2.title(18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  autofocus: true,
                  style: V2.body(16),
                  decoration: InputDecoration(
                    labelText: 'Amount (USD)',
                    labelStyle: V2.sub(),
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: V2.chip,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  style: V2.body(),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: V2.sub(),
                    filled: true,
                    fillColor: V2.chip,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  // Include custom categories the user added via
                  // Budgets > Add category (e.g. "House Rent"), so the
                  // list stays in sync.
                  items: <String>[
                    ...V2Budgets.categories,
                    ...freshBudgets.keys.where(
                        (k) => !V2Budgets.categories.contains(k)),
                  ]
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => category = v ?? 'Other'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: V2.body(),
                  decoration: InputDecoration(
                    labelText: 'Note (e.g. Walmart)',
                    labelStyle: V2.sub(),
                    filled: true,
                    fillColor: V2.chip,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
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
                final app = context.read<AppState>();
                await app.addExpense(Expense(
                  id: const Uuid().v4(),
                  userId: app.profile?.id ??
                      SupabaseService.currentUserId ??
                      'local',
                  amount: amt,
                  category: category,
                  note: noteCtrl.text.trim(),
                  spentAt: easternNow(),
                  source: 'app',
                ));
                // Auto-create the category in budgets if it's new.
                final budgets = await V2Budgets.load();
                final isNewCategory = !budgets.containsKey(category);
                if (isNewCategory) {
                  budgets[category] = 0;
                  await V2Budgets.save(budgets);
                  if (mounted) {
                    setState(() => _budgets = budgets);
                  }
                }
                try {
                  context
                      .read<SmartAiService>()
                      .recordSpending(amt);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
                // Prompt to set budget for new category, or warn if over budget.
                if (ctx.mounted) {
                  _checkBudgetAfterExpense(ctx, category, budgets);
                }
              },
              child: Text('Save',
                  style: V2.greenLabel(14)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- build

  /// Money tab pill — same tokens as V2Pill (grey unselected per mockup),
  /// but stretched full-width with a centered label.
  Widget _tabPill(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? V2.green : const Color(0xFFE9E9E2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : V2.ink,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2TitleRow(
                title: 'Money',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, BudgetsScreen.route),
                      child: Text('Budgets',
                          style: GoogleFonts.poppins(
                              color: V2.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                    V2AddButton(onTap: _showAddDialog),
                  ],
                ),
              ),

              // Today / Week / Month pills (equal-width, centered labels —
              // V2Pill doesn't center when stretched, so replicate its
              // exact styling here for mockup fidelity).
              Row(
                children: [
                  Expanded(child: _tabPill('Today', 0)),
                  const SizedBox(width: 10),
                  Expanded(child: _tabPill('Week', 1)),
                  const SizedBox(width: 10),
                  Expanded(child: _tabPill('Month', 2)),
                ],
              ),
              const SizedBox(height: 18),

              if (_tab == 0) _todayView(app),
              if (_tab == 1) _weekView(app),
              if (_tab == 2) _monthView(app),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  // ------------------------------------------------------------------- today

  Widget _todayView(AppState app) {
    final spentToday = _spentToday(app);
    final budget = app.profile?.monthlyBudget ?? 0;
    final left = app.leftToSpend;
    final totals = _monthTotalsByCat(app);
    final todays = _todaysExpenses(app);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Green hero.
        Container(
          padding: const EdgeInsets.all(22),
          decoration: V2.heroDeco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spent today',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('\$${spentToday.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
              const SizedBox(height: 6),
              Text(
                'Budget left ${_fmtMoney(left)} of \$${budget.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('Categories', style: V2.title(19)),
        const SizedBox(height: 10),
        V2Card(
          child: Column(
            children: [
              for (var i = 0;
                  i < V2Budgets.categories.length;
                  i++) ...[
                _categoryRow(
                  V2Budgets.categories[i],
                  totals[V2Budgets.categories[i]] ?? 0,
                  _budgets[V2Budgets.categories[i]] ?? 0,
                ),
                if (i < V2Budgets.categories.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text("Today's purchases", style: V2.title(19)),
        const SizedBox(height: 10),
        if (todays.isEmpty)
          V2Card(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text('No purchases logged today yet.',
                    style: V2.sub(14)),
              ),
            ),
          )
        else
          V2Card(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < todays.length; i++) ...[
                  _transactionRow(todays[i]),
                  if (i < todays.length - 1)
                    const Divider(
                        height: 1,
                        indent: 64,
                        endIndent: 12,
                        color: Color(0xFFF0F0EA)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _categoryRow(
      String category, double spent, double budget) {
    final pct = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final barColor = pct >= 1
        ? V2.danger
        : pct >= 0.8
            ? V2.amber
            : V2.green;
    return Row(
      children: [
        V2IconTile(V2Budgets.iconFor(category), size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category,
                  style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: V2.ink)),
              Text(
                  '\$${spent.toStringAsFixed(0)} of \$${budget.toStringAsFixed(0)}',
                  style: V2.sub(13)),
            ],
          ),
        ),
        SizedBox(
          width: 110,
          child: V2ProgressBar(value: pct, color: barColor),
        ),
      ],
    );
  }

  Widget _transactionRow(Expense e) {
    final title = e.note.isEmpty
        ? V2Budgets.normalize(e.category)
        : e.note;
    return InkWell(
      onTap: () => _showExpenseDetail(e),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 10),
        child: Row(
          children: [
            V2IconTile(V2Budgets.iconFor(e.category), size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: V2.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      '-\$${e.amount.toStringAsFixed(2)} • ${DateFormat('h:mm a').format(e.spentAt)}',
                      style: V2.sub(13)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmDelete(e),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: V2.muted, size: 22),
              tooltip: 'Delete',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- week

  Widget _weekView(AppState app) {
    final daily = _weekDaily(app);
    final total = daily.fold(0.0, (s, v) => s + v);
    final byCat = _weekTotalsByCat(app);
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This week', style: V2.title(19)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: V2.display(34)),
              const SizedBox(height: 12),
              _weekChart(daily),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('By category', style: V2.title(19)),
        const SizedBox(height: 10),
        if (sorted.isEmpty)
          V2Card(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text('No spending this week yet.',
                    style: V2.sub(14)),
              ),
            ),
          )
        else
          ...sorted.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _byCatRow(
                    e.key, e.value, total == 0 ? 0 : e.value / total),
              )),
      ],
    );
  }

  Widget _weekChart(List<double> days) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxVal =
        days.fold<double>(0, (m, v) => v > m ? v : m);
    // Label the two tallest non-zero bars, like the mockup.
    final order = List<int>.generate(7, (i) => i)
      ..sort((a, b) => days[b].compareTo(days[a]));
    final labeled = <int>{};
    for (final i in order) {
      if (days[i] > 0 && labeled.length < 2) labeled.add(i);
    }
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = days[i];
          final h = maxVal <= 0
              ? 10.0
              : 14.0 + (v / maxVal) * 108.0;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 20,
                  child: labeled.contains(i)
                      ? Text(
                          '\$${v.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: V2.greenDark),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 2),
                Container(
                  height: h,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: V2.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(letters[i],
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: V2.muted)),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------------- month

  Widget _monthView(AppState app) {
    final totals = _monthTotalsByCat(app);
    final total = totals.values.fold(0.0, (s, v) => s + v);
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final budget = app.profile?.monthlyBudget ?? 0;
    final isOverBudget = total > budget && budget > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isOverBudget ? const Color(0xFFFEE2E2) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOverBudget
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFE8E8E8),
              width: isOverBudget ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This month', style: V2.title(19)),
              Text('\$${total.toStringAsFixed(2)}',
                  style: V2.display(34).copyWith(
                    color: isOverBudget ? const Color(0xFFDC2626) : null,
                  )),
              const SizedBox(height: 4),
              Text(
                  'Budget left ${_fmtMoney(app.leftToSpend)} of \$${(app.profile?.monthlyBudget ?? 0).toStringAsFixed(0)}',
                  style: V2.sub(14).copyWith(
                    color: isOverBudget ? const Color(0xFFDC2626) : null,
                    fontWeight:
                        isOverBudget ? FontWeight.w700 : null,
                  )),
              if (isOverBudget) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⚠️ You have used your monthly budget!',
                    style: V2.sub(14).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('By category', style: V2.title(19)),
        const SizedBox(height: 10),
        if (sorted.every((e) => e.value == 0))
          V2Card(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text('No spending this month yet.',
                    style: V2.sub(14)),
              ),
            ),
          )
        else
          ...sorted
              .where((e) => e.value > 0)
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _byCatRow(e.key, e.value,
                        total == 0 ? 0 : e.value / total),
                  )),
      ],
    );
  }

  Widget _byCatRow(String category, double value, double pct) {
    return Row(
      children: [
        V2IconTile(V2Budgets.iconFor(category), size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(category,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: V2.ink),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                      '\$${value.toStringAsFixed(0)} — ${(pct * 100).round()}%',
                      style: V2.sub(14)),
                ],
              ),
              const SizedBox(height: 8),
              V2ProgressBar(value: pct),
            ],
          ),
        ),
      ],
    );
  }
}
