import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../data/usa_states.dart';
import '../services/gemini_service.dart';

/// Trip Planner: automated trip planning.
/// - Explore all 50 US states, tap to auto-generate a trip
/// - AI trip planner: describe your dream trip, get an instant plan
/// - Manual trips still supported
class TripPlannerScreen extends StatefulWidget {
  static const route = '/trip-planner';
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final List<Map<String, String>> _trips = [
    {
      'name': 'Beach Weekend',
      'detail': 'Miami - Dec 12 to Dec 14 - \$400 budget',
    },
  ];
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _aiLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fully automated: one tap on a state creates a complete trip plan.
  void _autoTrip(Map<String, dynamic> s) {
    final attractions = (s['attractions'] as List).join(', ');
    setState(() => _trips.add({
          'name': '${s['state']} Adventure',
          'detail':
              '${s['capital']} • Best: ${s['best']}\nTop spots: $attractions',
        }));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${s['state']} trip added!',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A9C63),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// AI trip planner: describe the trip, get an instant itinerary.
  void _aiPlanner() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('AI Trip Planner',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Describe your dream trip — where, how long, what you love.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g. 5-day beach trip in Florida, love seafood and sunsets',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A9C63)),
            onPressed: () async {
              final prompt = ctrl.text.trim();
              if (prompt.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _aiLoading = true);
              final plan = await GeminiService.ask(
                'Create a concise trip plan for: $prompt. '
                'Include: suggested destination, best time, top 3-4 must-see spots, '
                'and a rough daily outline. Keep it under 200 words, plain US English.',
                systemContext:
                    'You are Lifeez AI trip planner. Be practical and exciting.',
              );
              if (!mounted) return;
              setState(() => _aiLoading = false);
              final text = plan ??
                  'Beach getaway idea: Pick a coastal US state like Florida or Hawaii, '
                      'plan 4-5 days, book beachfront stays early, and leave room for '
                      'sunset walks and local seafood. Tell me a state for a full auto-plan!';
              _showPlan('Your AI trip plan', text, prompt);
            },
            child: const Text('Plan it!'),
          ),
        ],
      ),
    );
  }

  void _showPlan(String title, String plan, String prompt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Text(plan,
                      style: GoogleFonts.poppins(
                          fontSize: 14, height: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A9C63),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() => _trips.add({
                        'name': prompt.length > 40
                            ? '${prompt.substring(0, 37)}...'
                            : prompt,
                        'detail': 'AI-planned trip',
                      }));
                  Navigator.pop(ctx);
                },
                child: Text('Save this trip',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTrip() {
    final nameCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New trip', style: GoogleFonts.poppins()),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Trip name (e.g. Beach Weekend)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: detailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Destination, dates, budget'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A9C63),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() => _trips.add({
                      'name': nameCtrl.text.trim(),
                      'detail': detailCtrl.text.trim(),
                    }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final states = UsaStates.search(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A9C63),
        onPressed: _addTrip,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Container(
            decoration: AppTheme.heroGradient(radius: 24),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CategoryIcon(category: 'event', size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_trips.length} upcoming trips',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plan it all in one place.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI planner button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _aiLoading ? null : _aiPlanner,
              icon: _aiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                  _aiLoading
                      ? 'Planning...'
                      : 'AI Trip Planner — describe it, I\'ll plan it',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A9C63),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Explore USA — tap a state'),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search states…',
              prefixIcon: const Icon(Icons.search_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          ...states.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A9C63)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (s['state'] as String).substring(0, 2),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A9C63),
                        ),
                      ),
                    ),
                  ),
                  title: Text(s['state'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  subtitle: Text(s['tag'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600])),
                  trailing: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF1A9C63)),
                  onTap: () => _autoTrip(s),
                ),
              )),
          const SizedBox(height: 16),
          const SectionHeader(title: 'My trips'),
          if (_trips.isEmpty)
            const EmptyState(
              icon: Icons.flight_outlined,
              message: 'No trips yet. Tap a state above!',
            )
          else
            ..._trips.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CategoryIcon(
                          category: 'transport', size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t['detail'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
