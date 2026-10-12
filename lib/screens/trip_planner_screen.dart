import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/v2_kit.dart';
import '../services/supabase_client.dart';

/// V2 Trips: upcoming-trip banner + cover-photo cards with
/// Confirmed badges and budget bars, matching the V2 mockup.
class TripPlannerScreen extends StatefulWidget {
  static const route = '/trip-planner';
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  // "My trips" list — persisted per user (no fake sample trips).
  final List<Map<String, String>> _trips = [];

  String _tripsKey() =>
      'v2_trips_${SupabaseService.currentUserId ?? "guest"}';

  Future<void> _loadTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tripsKey());
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
      if (mounted) setState(() => _trips.addAll(list));
    } catch (_) {}
  }

  Future<void> _saveTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tripsKey(), jsonEncode(_trips));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  /// Whole-dollar money, e.g. 1200 -> $1,200.
  String _fmtWhole(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write(',');
    }
    return '\$$buf';
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? V2.green : Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------------------------------------------------- existing bits
  void _addTrip() {
    final nameCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: V2.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
            Text('New trip', style: V2.title(18)),
            const SizedBox(height: 16),
            _V2Field(
                controller: nameCtrl,
                label: 'Trip name (e.g. Beach Weekend)'),
            const SizedBox(height: 12),
            _V2Field(
                controller: detailCtrl,
                label: 'Destination - dates - \$budget'),
            const SizedBox(height: 4),
            Text(
              'Example: Miami - Dec 12 to Dec 14 - \$400 budget',
              style: V2.sub(12),
            ),
            const SizedBox(height: 16),
            V2PrimaryButton(
              label: 'Add trip',
              onTap: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() => _trips.add({
                        'name': nameCtrl.text.trim(),
                        'detail': detailCtrl.text.trim(),
                      }));
                  _saveTrips();
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTrip(int index) async {
    final name = _trips[index]['name'] ?? 'this trip';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: V2.card,
        title: Text('Delete $name?', style: V2.title(18)),
        content:
            Text('This removes the trip from your list.', style: V2.body(14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: V2.greenLabel(14))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: V2.danger))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _trips.removeAt(index));
      _saveTrips();
      _snack('Trip deleted.');
    }
  }

  // ---------------------------------------------------------- trip parsing
  ({String dest, String dates, double budget}) _parseTrip(
      Map<String, String> t) {
    var dest = (t['name'] ?? '').replaceFirst(RegExp(r'^AI:\s*'), '').trim();
    var dates = '';
    var budget = 0.0;
    final detail = (t['detail'] ?? '').trim();
    final budgetRe = RegExp(r'\$\s*([\d,]+(?:\.\d+)?)');
    double parseBudget(String s) {
      final m = budgetRe.firstMatch(s);
      if (m == null) return 0.0;
      return double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0;
    }

    final parts = detail.split(' - ').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      dest = parts.first;
      dates = parts.sublist(1, parts.length - 1).join(' - ');
      budget = parseBudget(parts.last);
    } else if (parts.length == 2) {
      budget = parseBudget(parts[1]);
      final looksLikeDates =
          RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}| to ').hasMatch(parts[0]);
      if (budget > 0 && looksLikeDates) {
        dates = parts[0];
      } else if (budget > 0) {
        dest = parts[0];
      } else {
        dest = parts[0];
        dates = parts[1];
      }
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      final b = parseBudget(parts[0]);
      if (b > 0) {
        budget = b;
      } else {
        dates = parts[0];
      }
    }
    return (dest: dest, dates: dates, budget: budget);
  }

  // ---------------------------------------------------------- UI builders
  Widget _tripCard(Map<String, String> t, int index) {
    final parsed = _parseTrip(t);
    final name = (t['name'] ?? '').trim();
    final title = name.isEmpty ? parsed.dest : name;
    // Real planned total from a linked AI plan (never a fake 0 bar).
    final planned = double.tryParse(t['planned'] ?? '') ?? 0;
    final metaBits = <String>[];
    if (parsed.dest.isNotEmpty &&
        parsed.dest.toLowerCase() != title.toLowerCase()) {
      metaBits.add(parsed.dest);
    }
    if (parsed.dates.isNotEmpty) metaBits.add(parsed.dates);
    return Dismissible(
      key: ValueKey('${title}_${t['detail']}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _deleteTrip(index);
        return false; // handled by the dialog
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: V2.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 28),
      ),
      child: V2Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover-photo area: gradient placeholder with destination icon.
            Container(
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [V2.greenDark, V2.green],
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.flight_takeoff_rounded,
                        color: Colors.white, size: 52),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: V2.green,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Text(
                        'Confirmed',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V2.title(20)),
                  if (metaBits.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(metaBits.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2.sub(13.5)),
                  ],
                  const SizedBox(height: 10),
                  // Honest budget bar: only when we have real planned data.
                  // Never a fake 0 bar. Mockup style: bold amount + grey rest.
                  if (parsed.budget > 0 && planned > 0) ...[
                    V2ProgressBar(
                        value: (planned / parsed.budget).clamp(0.0, 1.0)),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                            fontSize: 13.5, color: V2.muted),
                        children: [
                          TextSpan(
                            text: _fmtWhole(planned),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: V2.ink),
                          ),
                          TextSpan(
                              text:
                                  ' of ${_fmtWhole(parsed.budget)}'),
                        ],
                      ),
                    ),
                  ] else if (parsed.budget > 0)
                    Text('Budget ${_fmtWhole(parsed.budget)}',
                        style: V2.sub(13))
                  else
                    Text('No budget set', style: V2.sub(13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          GoogleFonts.poppins(color: V2.muted, fontSize: 14),
      suffixIcon: suffix,
      filled: true,
      fillColor: V2.bg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: V2.green, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _trips.length;
    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V2TitleRow(
                title: 'Trips',
                trailing: V2AddButton(onTap: _addTrip),
              ),
              // Green upcoming-trip banner (singular/plural).
              Container(
                decoration: V2.heroDeco,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 22),
                child: Row(
                  children: [
                    const Icon(Icons.flight_rounded,
                        color: Colors.white, size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '$n Upcoming Trip${n == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_trips.isEmpty)
                V2Card(
                  child: Column(
                    children: [
                      const V2IconTile(Icons.flight_outlined,
                          size: 56),
                      const SizedBox(height: 12),
                      Text('No trips yet.',
                          style: V2.title(16)),
                      const SizedBox(height: 4),
                      Text('Add one with the + button.',
                          textAlign: TextAlign.center,
                          style: V2.sub(13)),
                    ],
                  ),
                )
              else
                ..._trips.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _tripCard(e.value, e.key),
                    )),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }
}

/// V2-styled text field used by the trip sheets.
class _V2Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _V2Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: V2.ink, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: V2.muted, fontSize: 13.5),
        filled: true,
        fillColor: V2.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: V2.green, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
