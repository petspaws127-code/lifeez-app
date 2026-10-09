import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';

/// Travel Weather: destination weather + smart packing checklist.
class TravelWeatherScreen extends StatefulWidget {
  static const route = '/travel-weather';
  const TravelWeatherScreen({super.key});

  @override
  State<TravelWeatherScreen> createState() => _TravelWeatherScreenState();
}

class _TravelWeatherScreenState extends State<TravelWeatherScreen> {
  final _destController = TextEditingController();
  String _destination = '';
  final Map<String, bool> _packing = {
    'Passport / ID': false,
    'Phone charger': false,
    'Toiletries': false,
    'Medicines': false,
    'Extra clothes': false,
    'Snacks & water': false,
  };

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Weather')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.heroGradient(radius: 24),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where are you going?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destController,
                  style: GoogleFonts.poppins(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Enter destination',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (v) =>
                      setState(() => _destination = v.trim()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A9C63),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => setState(
                        () => _destination = _destController.text.trim()),
                    child: Text(
                      'Check weather',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_destination.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
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
                  const CategoryIcon(category: 'event', size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _destination,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Sunny, 72F - perfect for travel!',
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
            ),
            const SizedBox(height: 16),
          ],
          const SectionHeader(title: 'Packing checklist'),
          ..._packing.keys.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CheckboxListTile(
                  value: _packing[item],
                  onChanged: (v) =>
                      setState(() => _packing[item] = v ?? false),
                  title: Text(
                    item,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  activeColor: const Color(0xFF1A9C63),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
              )),
        ],
      ),
    );
  }
}
