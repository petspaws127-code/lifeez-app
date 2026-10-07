import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/document_item.dart';
import '../services/eastern_time.dart';

/// Document Scanner — capture a document photo with the camera (or pick
/// from gallery) and save it as a document entry.
class ScannerScreen extends StatefulWidget {
  static const route = '/scanner';
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _picker = ImagePicker();
  XFile? _scan;
  bool _busy = false;

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      setState(() {
        _scan = file;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open camera: $e')),
      );
    }
  }

  void _saveScan() {
    final name = TextEditingController(
        text:
            'Scan ${easternNow().month}/${easternNow().day}/${easternNow().year}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(26)),
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
            Text('Save scan',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: name, label: 'Document name'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save document',
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final app = context.read<AppState>();
                final messenger =
                    ScaffoldMessenger.of(context);
                await app.addDocument(DocumentItem(
                  id: const Uuid().v4(),
                  userId: app.profile?.id ?? '',
                  name: name.text.trim(),
                  docType: 'other',
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  setState(() => _scan = null);
                  messenger.showSnackBar(
                    const SnackBar(
                        content:
                            Text('Document saved.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Scanner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.card3D(),
            clipBehavior: Clip.antiAlias,
            child: _scan == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 48),
                    child: Column(
                      children: [
                        const CategoryIcon(
                            category: 'scan', size: 72),
                        const SizedBox(height: 12),
                        Text(
                          'Scan receipts, IDs, and papers',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Point the camera at a document and capture it.',
                          style: GoogleFonts.poppins(
                              color: AppColors.muted,
                              fontSize: 13.5),
                        ),
                      ],
                    ),
                  )
                : Image.file(
                    File(_scan!.path),
                    height: 320,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Center(
                child: CircularProgressIndicator(
                    color: AppColors.deepGreen))
          else if (_scan == null) ...[
            GradientButton(
              label: 'Capture with camera',
              icon: Icons.camera_alt_rounded,
              onPressed: () =>
                  _capture(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pick from gallery'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16)),
              ),
              onPressed: () =>
                  _capture(ImageSource.gallery),
            ),
          ] else ...[
            GradientButton(
              label: 'Save this scan',
              icon: Icons.check_rounded,
              onPressed: _saveScan,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16)),
              ),
              onPressed: () =>
                  setState(() => _scan = null),
            ),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'Tips'),
          Text(
            '• Hold the phone steady and fill the frame.\n• Good lighting avoids blurry text.\n• Name scans clearly so you can find them later.',
            style: GoogleFonts.poppins(
                fontSize: 13.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
