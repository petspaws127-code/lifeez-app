import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pet.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/v2_kit.dart';

/// Digital Pet ID card with QR code.
/// Scanning the QR shows the pet's name, breed and owner contact.
/// Pro feature (part of the Pets Pro bundle).
class PetDigitalIdScreen extends StatelessWidget {
  static const route = '/pet-digital-id';
  final PetProfile pet;

  const PetDigitalIdScreen({super.key, required this.pet});

  String _qrData(AppState app) {
    final ownerContact = app.profile?.email ?? '';
    final buf = StringBuffer()
      ..writeln('PET ID — ${pet.name}')
      ..writeln('Breed: ${pet.breed ?? '-'}');
    if (ownerContact.isNotEmpty) buf.writeln('Owner: $ownerContact');
    buf.writeln('If found, please contact the owner.');
    return buf.toString();
  }

  Future<void> _share(AppState app) async {
    await Share.share(
      '${_qrData(app)}\n— via Lifeez',
      subject: '${pet.name}\'s Pet ID',
    );
  }

  Widget _photo() {
    final path = pet.photoPath;
    Widget placeholder() => Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: V2.chip,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.pets_rounded, color: V2.green, size: 44),
        );
    if (path == null || path.isEmpty) return placeholder();
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final qrData = _qrData(app);
    return Scaffold(
      backgroundColor: V2.bg,
      appBar: AppBar(
        backgroundColor: V2.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: V2.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${pet.name} — Pet ID',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: V2.ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ID card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _photo(),
                  const SizedBox(height: 12),
                  Text(pet.name,
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: V2.ink)),
                  const SizedBox(height: 2),
                  Text(
                      '${pet.breed?.isNotEmpty == true ? pet.breed : 'Pet'}'
                      '${app.profile?.email.isNotEmpty == true ? '\n${app.profile!.email}' : ''}',
                      textAlign: TextAlign.center,
                      style: V2.sub(14)),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text('Scan if found — help ${pet.name} get home',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: V2.green)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            V2PrimaryButton(
              label: 'Share Pet ID',
              onTap: () => _share(app),
            ),
            const SizedBox(height: 12),
            Text(
              'Print this QR on a collar tag — anyone who scans it can reach you.',
              textAlign: TextAlign.center,
              style: V2.sub(13),
            ),
          ],
        ),
      ),
    );
  }
}
