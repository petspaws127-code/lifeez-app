import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../screens/profile_screen.dart';
import '../screens/pro_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/help_faq_screen.dart';
import '../screens/contact_support_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

/// Account popup menu shown when tapping the profile avatar in the header.
/// Contains all the items previously in the "More" tab.
class ProfileMenu {
  /// Shows the account popup anchored near the top-right (below the avatar).
  static Future<void> show(BuildContext context) async {
    final app = context.read<AppState>();
    final name = app.profile?.name ?? 'User';
    final email = app.profile?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    // Position near top-right, below the header.
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width - 240,
        90,
        12,
        size.height - 400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      elevation: 8,
      items: [
        // Header with user info (non-clickable)
        PopupMenuItem(
          enabled: false,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1a9c63),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        _menuItem(
          context,
          icon: Icons.person_outline_rounded,
          label: 'My Profile',
          route: ProfileScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.star_outline_rounded,
          label: 'Lifeez Pro',
          route: ProScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.settings_outlined,
          label: 'Settings',
          route: SettingsScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.help_outline_rounded,
          label: 'Help & FAQ',
          route: HelpFaqScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.support_agent_outlined,
          label: 'Contact Support',
          route: ContactSupportScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          route: PrivacyPolicyScreen.route,
        ),
        _menuItem(
          context,
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          route: TermsScreen.route,
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => _signOut(context),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 20,
                color: Color(0xFFC0392B),
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFFC0392B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static PopupMenuItem _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return PopupMenuItem(
      onTap: () {
        // Delay navigation until the menu is fully dismissed.
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.pushNamed(context, route);
          }
        });
      },
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1a9c63)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign out?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You will need to sign in again to use the app.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign out',
              style: GoogleFonts.poppins(
                color: const Color(0xFFC0392B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final auth = context.read<AuthService>();
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, LoginScreen.route, (_) => false);
  }
}
