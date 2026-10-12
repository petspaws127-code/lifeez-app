import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../widgets/v2_kit.dart';

/// Shared per-category budget store, persisted as JSON under a per-user key.
/// MoneyScreen reads from here; BudgetsScreen edits it.
class V2Budgets {
  V2Budgets._();

  /// Per-user prefs key — never share budgets across users on one device.
  static String get prefsKey =>
      'v2_budgets_${SupabaseService.currentUserId ?? "guest"}';

  /// Canonical categories — matches the Expense model exactly.
  static const List<String> categories = [
    'Food',
    'Grocery',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Other',
  ];

  static const Map<String, double> defaultValues = {
    'Food': 300,
    'Grocery': 200,
    'Transport': 150,
    'Shopping': 200,
    'Bills': 250,
    'Health': 120,
    'Other': 100,
  };

  /// Maps any raw category string to one of [categories].
  static String normalize(String raw) {
    final r = raw.trim().toLowerCase();
    for (final c in categories) {
      if (r == c.toLowerCase()) return c;
    }
    if (r.contains('food') || r.contains('din')) return 'Food';
    if (r.contains('groc')) return 'Grocery';
    if (r.contains('trans')) return 'Transport';
    if (r.contains('shop')) return 'Shopping';
    if (r.contains('bill')) return 'Bills';
    if (r.contains('health')) return 'Health';
    return 'Other';
  }

  static IconData iconFor(String category) {
    switch (normalize(category)) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Grocery':
        return Icons.shopping_basket_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Health':
        return Icons.favorite_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Future<Map<String, double>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    final out = Map<String, double>.from(defaultValues);
    if (raw == null) return out;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Load canonical categories first.
      for (final c in categories) {
        final v = json[c];
        if (v is num) out[c] = v.toDouble();
      }
      // Also load custom categories (any extra keys the user added).
      for (final entry in json.entries) {
        final key = entry.key;
        final v = entry.value;
        if (!out.containsKey(key) && v is num) {
          out[key] = v.toDouble();
        }
      }
    } catch (_) {}
    return out;
  }

  static Future<void> save(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(budgets));
  }
}

/// V2 Budgets — total monthly budget card + per-category editable rows.
/// Full-screen route with V2SubNav.
class BudgetsScreen extends StatefulWidget {
  static const route = '/budgets';
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  Map<String, double> _draft =
      Map<String, double>.from(V2Budgets.defaultValues);
  String? _editing; // category currently being edited inline
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    V2Budgets.load().then((m) {
      if (mounted) setState(() => _draft = m);
    });
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _startEditing(String category) {
    _editCtrl.text = _fmt(_draft[category] ?? 0);
    setState(() => _editing = category);
  }

  void _confirmEditing() {
    final cat = _editing;
    if (cat == null) return;
    final v = double.tryParse(_editCtrl.text.trim());
    if (v != null && v >= 0) {
      setState(() {
        _draft[cat] = v;
        _editing = null;
      });
    } else {
      setState(() => _editing = null);
    }
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Add category', style: V2.title(18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: V2.body(),
          decoration: InputDecoration(
            labelText: 'Category name',
            labelStyle: V2.sub(),
            filled: true,
            fillColor: V2.chip,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty && !_draft.containsKey(name)) {
                setState(() => _draft[name] = 0);
              }
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: V2.greenLabel(14)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await V2Budgets.save(_draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budgets saved.')),
    );
  }

  void _editTotal(AppState app) {
    final p = app.profile;
    if (p == null) return;
    final ctrl = TextEditingController(
        text: _fmt(p.monthlyBudget));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Total monthly budget', style: V2.title(18)),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: V2.body(),
          decoration: InputDecoration(
            labelText: 'Budget (USD)',
            labelStyle: V2.sub(),
            filled: true,
            fillColor: V2.chip,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v >= 0) {
                await app.saveProfile(
                    p.copyWith(monthlyBudget: v));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save',
                style: V2.greenLabel(14)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final total = app.profile?.monthlyBudget ?? 0;

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        size: 28, color: V2.ink),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text('Budgets', style: V2.pageHeading()),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text('Set your own limits per category',
                    style: V2.sub(15)),
              ),
              const SizedBox(height: 20),

              // Total monthly budget card.
              V2Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Total monthly budget',
                              style: V2.sub(15)),
                          const SizedBox(height: 4),
                          Text(
                            '\$${NumberFormat('#,##0').format(total)}',
                            style: V2.display(42),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _editTotal(app),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: V2.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        textStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Per-category rows.
              ..._draft.keys.map(_categoryRow),
              const SizedBox(height: 8),

              // Add custom category.
              OutlinedButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add_rounded, color: V2.green),
                label: Text('Add category',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: V2.green)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: V2.green, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              V2PrimaryButton(
                label: 'Save budgets',
                onTap: _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _categoryRow(String category) {
    final editing = _editing == category;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2Card(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            V2IconTile(V2Budgets.iconFor(category), size: 50),
            const SizedBox(width: 14),
            Expanded(
              child: Text(category,
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: V2.ink),
                  overflow: TextOverflow.ellipsis),
            ),
            if (editing) ...[
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _editCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: V2.ink),
                  decoration: InputDecoration(
                    prefixText: '\$',
                    filled: true,
                    fillColor: V2.chip,
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: V2.green, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: V2.green, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _confirmEditing(),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _confirmEditing,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: V2.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ] else
              InkWell(
                onTap: () => _startEditing(category),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: V2.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${_fmt(_draft[category] ?? 0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: V2.greenDark),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined,
                          size: 16, color: V2.green),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
