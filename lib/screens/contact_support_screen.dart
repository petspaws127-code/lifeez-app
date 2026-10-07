import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/ui_kit.dart';

/// Contact Support — form that opens the user's email app with a
/// pre-filled support message (works without any backend).
class ContactSupportScreen extends StatefulWidget {
  static const route = '/support';
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() =>
      _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _topic = 'General question';

  static const _topics = [
    'General question',
    'Bug report',
    'Pro & billing',
    'Feature request',
    'Privacy & data',
  ];

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please write your message first.')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@lifeez.app',
      queryParameters: {
        'subject':
            '[Lifeez] $_topic — ${_subject.text.trim().isEmpty ? 'Support request' : _subject.text.trim()}',
        'body': _message.text.trim(),
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No email app found. Email us at support@lifeez.app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CategoryIcon(category: 'family', size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('We are here to help',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(
                          'We usually reply within one business day.',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.card3D(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Topic',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _topics)
                      ChoiceChip(
                        label: Text(t,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5)),
                        selected: _topic == t,
                        selectedColor: AppColors.deepGreen,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: _topic == t
                              ? Colors.white
                              : AppColors.ink,
                        ),
                        onSelected: (_) =>
                            setState(() => _topic = t),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                    controller: _subject,
                    label: 'Subject (optional)'),
                AppTextField(
                  controller: _message,
                  label: 'How can we help?',
                  maxLines: 5,
                ),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Send message',
                    icon: Icons.send_rounded,
                    onPressed: _send,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('or email support@lifeez.app directly',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
