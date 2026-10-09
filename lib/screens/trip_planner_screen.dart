import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';

/// Trip Planner: plan trips with destination, dates and budget.
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

  void _addTrip() {
    final nameCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New trip', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Trip name (e.g. Beach Weekend)'),
            ),
            TextField(
              controller: detailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Destination, dates, budget'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A9C63),
        onPressed: _addTrip,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plan it all in one place.',
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
          const SizedBox(height: 16),
          const SectionHeader(title: 'My trips'),
          if (_trips.isEmpty)
            const EmptyState(
              icon: Icons.flight_outlined,
              message: 'No trips yet. Tap + to plan your first trip!',
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
                      const CategoryIcon(category: 'transport', size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['name'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t['detail'] ?? '',
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
