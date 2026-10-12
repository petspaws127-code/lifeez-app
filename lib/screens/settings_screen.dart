import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../services/supabase_client.dart';
import '../widgets/v2_kit.dart';

/// V2 Settings — grouped rows: General, Notifications (toggles), Data, About.
/// Full-screen route with back affordance + V2SubNav.
class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kStartOfWeekBase = 'v2_start_of_week';
  static const _kTimeFormatBase = 'v2_time_format';
  static const _kHabitStreakNotifsBase = 'v2_habit_streak_notifs';

  // Per-user settings keys (strict user data separation).
  String _uid() => SupabaseService.currentUserId ?? 'guest';
  String get _kStartOfWeek => '${_kStartOfWeekBase}_${_uid()}';
  String get _kTimeFormat => '${_kTimeFormatBase}_${_uid()}';
  String get _kHabitStreakNotifs => '${_kHabitStreakNotifsBase}_${_uid()}';

  String _startOfWeek = 'Monday';
  String _timeFormat = '12h';
  bool _habitStreakNotifs = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
    _loadVersion();
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _startOfWeek = prefs.getString(_kStartOfWeek) ?? 'Monday';
      _timeFormat = prefs.getString(_kTimeFormat) ?? '12h';
      _habitStreakNotifs = prefs.getBool(_kHabitStreakNotifs) ?? true;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  // ------------------------------------------------------------- pickers

  void _themePicker(AppState app) {
    final current = app.profile?.themeMode ?? 'system';
    const modes = ['light', 'system', 'dark'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Theme', style: V2.title(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes
              .map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        m[0].toUpperCase() + m.substring(1),
                        style: V2.body()),
                    trailing: current == m
                        ? const Icon(Icons.check_rounded,
                            color: V2.green)
                        : null,
                    onTap: () async {
                      await app.setThemeMode(m);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
        ],
      ),
    );
  }

  Future<void> _simpleChoicePicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onPick,
  }) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: V2.title(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o, style: V2.body()),
                    trailing: current == o
                        ? const Icon(Icons.check_rounded,
                            color: V2.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, o),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: V2.sub().copyWith(fontSize: 14))),
        ],
      ),
    );
    if (picked != null && picked != current) onPick(picked);
  }

  void _startOfWeekPicker() {
    _simpleChoicePicker(
      title: 'Start of week',
      options: const ['Sunday', 'Monday', 'Saturday'],
      current: _startOfWeek,
      onPick: (v) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kStartOfWeek, v);
        if (mounted) setState(() => _startOfWeek = v);
      },
    );
  }

  void _timeFormatPicker() {
    _simpleChoicePicker(
      title: 'Time format',
      options: const ['12h', '24h'],
      current: _timeFormat,
      onPick: (v) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTimeFormat, v);
        if (mounted) setState(() => _timeFormat = v);
      },
    );
  }

  // ------------------------------------------------------- notification rows

  Future<void> _toggleReminders(bool v) async {
    final app = context.read<AppState>();
    if (v) {
      final granted = await app.requestNotificationPermission();
      if (mounted && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Notification permission was denied. Enable it in system settings to receive alerts.')),
        );
      }
    }
    await app.setNotificationsEnabled(v);
  }

  Future<void> _toggleBriefing(bool v) async {
    final app = context.read<AppState>();
    if (v) {
      final granted = await app.requestNotificationPermission();
      if (mounted && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Notification permission was denied. Enable it in system settings to receive the morning briefing.')),
        );
      }
    }
    await app.setDailyBriefingEnabled(v);
  }

  Future<void> _toggleHabitStreaks(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHabitStreakNotifs, v);
    if (mounted) setState(() => _habitStreakNotifs = v);
  }

  // ------------------------------------------------------------- data group

  void _backupAndSync(AppState app) {
    final email = (app.profile?.email ?? '').trim();
    showDialog(
      context: context,
      builder: (ctx) {
        var syncing = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Backup & sync', style: V2.title(18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Your data is backed up to your Lifeez cloud account whenever you are online.',
                    style: V2.body(14)),
                const SizedBox(height: 10),
                if (email.isNotEmpty)
                  Text('Signed in as $email', style: V2.sub()),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: syncing ? null : () => Navigator.pop(ctx),
                  child: Text('Close',
                      style: V2.sub().copyWith(fontSize: 14))),
              TextButton(
                onPressed: syncing
                    ? null
                    : () async {
                        setDlg(() => syncing = true);
                        await context.read<AppState>().loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content:
                                      Text('Synced with cloud.')));
                        }
                      },
                child: syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5))
                    : Text('Sync now',
                        style: V2.greenLabel(14).copyWith(
                            fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(AppState app) async {
    try {
      final data = {
        'exported_at': DateTime.now().toIso8601String(),
        'profile': app.profile?.toJson(),
        'tasks': app.tasks.map((e) => e.toJson()).toList(),
        'reminders': app.reminders.map((e) => e.toJson()).toList(),
        'habits': app.habits.map((e) => e.toJson()).toList(),
        'expenses': app.expenses.map((e) => e.toJson()).toList(),
      };
      final dir = await getApplicationDocumentsDirectory();
      final name =
          'lifeez-export-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
      final file = File('${dir.path}/$name');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Export complete', style: V2.title(18)),
          content: Text('Your data was saved to:\n${file.path}',
              style: V2.body(13)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done',
                    style: V2.greenLabel(14)
                        .copyWith(fontWeight: FontWeight.w700))),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final themeMode = p?.themeMode ?? 'system';
    final themeLabel =
        themeMode[0].toUpperCase() + themeMode.substring(1);

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: v2PagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded,
                        size: 34, color: V2.ink),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              const SizedBox(height: 16),

              _plainLabel('General'),
              _group([
                _navRow(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Theme',
                  subtitle: themeLabel,
                  onTap: () => _themePicker(app),
                ),
                _navRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Start of week',
                  subtitle: _startOfWeek,
                  onTap: _startOfWeekPicker,
                ),
                _navRow(
                  icon: Icons.schedule_outlined,
                  title: 'Time format',
                  subtitle: _timeFormat,
                  onTap: _timeFormatPicker,
                  last: true,
                ),
              ]),
              const SizedBox(height: 18),

              _plainLabel('Notifications'),
              _group([
                _toggleRow(
                  icon: Icons.notifications_outlined,
                  title: 'Reminders',
                  value: p?.notificationsEnabled ?? true,
                  onChanged: _toggleReminders,
                ),
                _toggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Daily briefing',
                  value: p?.dailyBriefingEnabled ?? true,
                  onChanged: _toggleBriefing,
                ),
                _toggleRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Habit streaks',
                  value: _habitStreakNotifs,
                  onChanged: _toggleHabitStreaks,
                  last: true,
                ),
              ]),
              const SizedBox(height: 18),

              _plainLabel('Data'),
              _group([
                _navRow(
                  icon: Icons.cloud_outlined,
                  title: 'Backup & sync',
                  onTap: () => _backupAndSync(app),
                ),
                _navRow(
                  icon: Icons.download_outlined,
                  title: 'Export data',
                  onTap: () => _exportData(app),
                  last: true,
                ),
              ]),
              const SizedBox(height: 18),

              _plainLabel('About'),
              _group([
                _navRow(
                  icon: Icons.shield_outlined,
                  title: 'Privacy policy',
                  onTap: () =>
                      Navigator.pushNamed(context, '/privacy'),
                ),
                _navRow(
                  icon: Icons.description_outlined,
                  title: 'Terms',
                  onTap: () =>
                      Navigator.pushNamed(context, '/terms'),
                  last: _version.isEmpty,
                ),
                if (_version.isNotEmpty)
                  _infoRow(
                    icon: Icons.info_outline_rounded,
                    title: 'App version',
                    trailing: _version,
                  ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  /// Normal-case grey section label (Settings mockup).
  Widget _plainLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: V2.muted,
        ),
      ),
    );
  }

  /// White grouped card with divider-separated rows.
  Widget _group(List<Widget> rows) {
    return Container(
      decoration: V2.cardDeco,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: Color(0xFFF0F0EA)),
          ],
        ],
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String title,
    String? subtitle,
    bool last = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, last ? 16 : 14),
        child: Row(
          children: [
            SizedBox(
                width: 32,
                child: Icon(icon, color: V2.muted, size: 25)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: V2.ink)),
                  if (subtitle != null)
                    Text(subtitle, style: V2.sub(14)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFB9BEC7), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool last = false,
  }) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(16, 10, 12, last ? 12 : 10),
      child: Row(
        children: [
          SizedBox(
              width: 32,
              child: Icon(icon, color: V2.muted, size: 25)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: V2.ink)),
          ),
          V2Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          SizedBox(
              width: 32,
              child:
                  Icon(icon, color: V2.muted, size: 25)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: V2.ink)),
          ),
          Text(trailing, style: V2.sub(14)),
        ],
      ),
    );
  }
}
