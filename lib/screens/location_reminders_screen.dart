import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';

/// Location Reminders: get reminded when you are near a place.
class LocationRemindersScreen extends StatefulWidget {
  static const route = '/location-reminders';
  const LocationRemindersScreen({super.key});

  @override
  State<LocationRemindersScreen> createState() =>
      _LocationRemindersScreenState();
}

class _LocationRemindersScreenState
    extends State<LocationRemindersScreen> {
  final List<Map<String, String>> _items = [
    {
      'task': 'Buy dog food',
      'place': 'Near PetSmart',
    },
    {
      'task': 'Pick up prescription',
      'place': 'Near CVS Pharmacy',
    },
  ];

  void _add() {
    final taskCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New location reminder',
            style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: taskCtrl,
              decoration:
                  const InputDecoration(labelText: 'What to remember?'),
            ),
            TextField(
              controller: placeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Near which place?'),
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
              if (taskCtrl.text.trim().isNotEmpty) {
                setState(() => _items.add({
                      'task': taskCtrl.text.trim(),
                      'place': placeCtrl.text.trim().isEmpty
                          ? 'Nearby'
                          : 'Near ${placeCtrl.text.trim()}',
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
      appBar: AppBar(title: const Text('Location Reminders')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A9C63),
        onPressed: _add,
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
                const CategoryIcon(category: 'reminder', size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_items.length} place alerts',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'We will nudge you when you are close.',
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
          const SectionHeader(title: 'My alerts'),
          if (_items.isEmpty)
            const EmptyState(
              icon: Icons.location_on_outlined,
              message: 'No location alerts yet. Tap + to add one!',
            )
          else
            ..._items.map((it) => Dismissible(
                  key: ValueKey('${it['task']}-${it['place']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      setState(() => _items.remove(it)),
                  child: Container(
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
                                it['task'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                it['place'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF1A9C63),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
