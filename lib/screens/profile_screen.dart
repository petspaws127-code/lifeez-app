import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/user_profile_service.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../services/auth_service.dart';
import '../widgets/v2_kit.dart';
import 'login_screen.dart';

/// V2 Profile — tab body (MainTabs owns the Scaffold + bottom nav).
/// Avatar card + edit, 3 stat cards, menu list (Settings, Notifications,
/// Go Pro, Refer & Earn, Help & FAQ, Log out).
class ProfileScreen extends StatefulWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();

  String _displayName(AppState app) {
    // EXACT Home screen pattern: direct from Supabase auth metadata.
    String? raw;
    try {
      final user = SupabaseService.client.auth.currentUser;
      raw = user?.userMetadata?['full_name'] as String?;
      raw ??= user?.userMetadata?['name'] as String?;
      raw ??= user?.userMetadata?['display_name'] as String?;
    } catch (_) {}
    raw ??= app.profile?.name;
    if (raw == null || raw.trim().isEmpty) return 'Lifeez User';
    return raw.trim();
  }

  String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? 'L' : t[0].toUpperCase();
  }

  Future<void> _changePhoto() async {
    final app = context.read<AppState>();
    // Never operate on a null profile: build it from the signed-in user.
    final p = app.profile ?? await app.ensureProfile();
    if (!mounted || p == null) return;
    final hasPhoto = (p.photoPath ?? '').isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: V2.green),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: V2.green),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: V2.danger),
                title: const Text('Remove photo',
                    style: TextStyle(color: V2.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      await app.saveProfile(p.copyWith(clearPhoto: true));
      return;
    }
    // Request photo permission explicitly before opening the picker.
    // On Android 13+ this is READ_MEDIA_IMAGES; on older it falls back.
    try {
      Permission perm;
      if (choice == 'camera') {
        perm = Permission.camera;
      } else {
        // Photos permission (Android 13+ uses READ_MEDIA_IMAGES)
        perm = Permission.photos;
      }
      var status = await perm.status;
      if (status.isDenied || status.isRestricted) {
        status = await perm.request();
      }
      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Photo access is blocked. Please allow it in Settings > Apps > Lifeez > Permissions.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        await openAppSettings();
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Photo access is needed to set a profile photo.')),
          );
        }
        return;
      }
    } catch (_) {
      // Permission check failed — try picker anyway.
    }
    try {
      final img = await _picker.pickImage(
          source: choice == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 512,
          imageQuality: 80);
      if (img == null || !mounted) return;
      await app.saveProfile(p.copyWith(photoPath: img.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      // Permission denied or picker failed — tell the user what to do.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not access photos. Please allow photo access in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final app = context.read<AppState>();
    // Never silently no-op: build the profile from the signed-in user
    // when it is missing.
    final p = app.profile ?? await app.ensureProfile();
    if (!mounted || p == null) return;
    // Show the real account name even if the stored profile name is empty.
    final initialName =
        p.name.trim().isEmpty ? _displayName(app) : p.name.trim();
    final nameCtrl = TextEditingController(text: initialName);
    final emailCtrl = TextEditingController(text: p.email);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Edit profile', style: V2.title(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl, 'Name'),
            const SizedBox(height: 10),
            _field(emailCtrl, 'Email',
                keyboard: TextInputType.emailAddress),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              await app.saveProfile(p.copyWith(
                name: newName,
                email: emailCtrl.text.trim(),
              ));
              // Persist the display name into Supabase auth metadata too,
              // so it survives reinstalls and shows on Home instantly.
              try {
                await UserProfileService.saveDisplayName(newName);
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved.')),
                );
              }
            },
            child: Text('Save',
                style: V2.greenLabel(14).copyWith(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: V2.body(),
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Log out?', style: V2.title(18)),
        content: Text('You will need to sign in again to use the app.',
            style: V2.body()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Log out',
                  style: GoogleFonts.poppins(
                      color: V2.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = context.read<AuthService>();
    final app = context.read<AppState>();
    // Push any pending offline writes to the cloud before wiping local.
    await app.flushBeforeSignOut();
    app.clearLocal();
    await auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final name = _displayName(app);
    final email = (p?.email ?? '').trim();
    final isPro = p?.isPro ?? false;

    final streak = app.habits.fold<int>(0, (m, h) => max(m, h.streak));
    final tasksDone = app.tasks.where((t) => t.isDone).length;
    final habitCount = app.habits.length;
    final localPhoto =
        (p?.photoPath ?? '').isNotEmpty ? p!.photoPath : null;
    // Google avatar: EXACT direct pattern from Supabase auth metadata.
    String? avatarUrl;
    try {
      final user = SupabaseService.client.auth.currentUser;
      avatarUrl = user?.userMetadata?['avatar_url'] as String?;
      avatarUrl ??= user?.userMetadata?['picture'] as String?;
    } catch (_) {}
    final photoPath =
        (localPhoto ?? avatarUrl ?? '').isNotEmpty ? (localPhoto ?? avatarUrl) : null;
    final isNetworkPhoto =
        photoPath != null && photoPath.startsWith('http');

    return SingleChildScrollView(
      padding: v2PagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar card.
          V2Card(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _changePhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: V2.green,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: photoPath != null
                            ? (isNetworkPhoto
                                ? Image.network(photoPath,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover)
                                : Image.file(File(photoPath),
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover))
                            : Text(
                                _initial(name),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: V2.greenDark,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: V2.title(19),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (email.isNotEmpty)
                        Text(email,
                            style: V2.sub(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        isPro ? 'Lifeez Pro' : 'Free plan',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isPro ? V2.amber : V2.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _editProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: V2.ink,
                    side: const BorderSide(
                        color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: V2.muted),
                  label: Text('Edit',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stat cards.
          Row(
            children: [
              Expanded(
                  child: _statCard(Icons.local_fire_department_rounded,
                      '$streak', 'day streak')),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(Icons.check_circle_rounded,
                      '$tasksDone', 'tasks done')),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard(Icons.eco_rounded,
                      '$habitCount', 'habits')),
            ],
          ),
          const SizedBox(height: 14),

          // Menu list.
          _menuRow(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          _menuRow(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () =>
                Navigator.pushNamed(context, '/notifications'),
          ),
          _menuRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Go Pro',
            badge: 'PRO',
            onTap: () => Navigator.pushNamed(context, '/pro'),
          ),
          _menuRow(
            icon: Icons.card_giftcard_outlined,
            title: 'Refer & Earn',
            onTap: () =>
                Navigator.pushNamed(context, '/referrals'),
          ),
          _menuRow(
            icon: Icons.help_outline_rounded,
            title: 'Help & FAQ',
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          _menuRow(
            icon: Icons.logout_rounded,
            title: 'Log out',
            danger: true,
            onTap: _signOut,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return V2Card(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: V2.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: V2.green, size: 28),
          ),
          const SizedBox(height: 8),
          Text(value, style: V2.display(26)),
          Text(label, style: V2.sub(13)),
        ],
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String title,
    String? badge,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2Card(
        onTap: onTap,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: danger
                    ? V2.danger.withOpacity(0.12)
                    : V2.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: danger ? V2.danger : V2.green, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: danger ? V2.danger : V2.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: V2.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: V2.muted, size: 26),
          ],
        ),
      ),
    );
  }
}
