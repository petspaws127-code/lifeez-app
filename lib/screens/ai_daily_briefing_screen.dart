import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/v2_kit.dart';
import '../services/app_state.dart';
import '../services/eastern_time.dart';
import '../services/smart_ai_service.dart';
import 'tasks_screen.dart';
import 'habits_screen.dart';
import 'trip_planner_screen.dart';
import 'pro_screen.dart';

/// Pro upsell card used when a Pro-only AI feature is locked.
Widget _proUpsellCard(BuildContext context, String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: V2Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, ProScreen.route),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              const V2IconTile(Icons.workspace_premium_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: V2.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: V2.muted)),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline_rounded,
                  color: V2.green, size: 22),
            ],
          ),
        ),
      ),
    ),
  );
}

/// V2 AI Daily Briefing: green hero summary card, category cards
/// (Schedule / Priorities / Habits / Weather), Read-aloud via
/// flutter_tts, plus the existing AI Insights. All numbers come from
/// AppState (todayTasks, activeReminders, unpaidBills, habits).
class AiDailyBriefingScreen extends StatefulWidget {
  static const route = '/ai-briefing';
  const AiDailyBriefingScreen({super.key});

  @override
  State<AiDailyBriefingScreen> createState() =>
      _AiDailyBriefingScreenState();
}

class _AiDailyBriefingScreenState extends State<AiDailyBriefingScreen> {
  final _tts = FlutterTts();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isToday(DateTime d) {
    final now = easternNow();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  /// "8 items today" hero numbers.
  ({int total, int beforeNoon}) _heroCounts(AppState app) {
    final tasks = app.todayTasks;
    final remindersToday =
        app.activeReminders.where((r) => _isToday(r.remindAt)).toList();
    final total = tasks.length + remindersToday.length + app.unpaidBills.length;
    var beforeNoon = 0;
    for (final t in tasks) {
      final d = t.dueDate;
      if (d != null && d.hour < 12) beforeNoon++;
    }
    for (final r in remindersToday) {
      if (r.remindAt.hour < 12) beforeNoon++;
    }
    return (total: total, beforeNoon: beforeNoon);
  }

  /// Earliest timed item today (task due or reminder).
  ({String title, DateTime at})? _firstUp(AppState app) {
    DateTime? best;
    String? title;
    for (final t in app.todayTasks) {
      final d = t.dueDate;
      if (d == null) continue;
      if (best == null || d.isBefore(best)) {
        best = d;
        title = t.title;
      }
    }
    for (final r in app.activeReminders) {
      if (!_isToday(r.remindAt)) continue;
      if (best == null || r.remindAt.isBefore(best)) {
        best = r.remindAt;
        title = r.title;
      }
    }
    if (best == null || title == null) return null;
    return (title: title, at: best);
  }

  String _briefingText(AppState app) {
    final c = _heroCounts(app);
    final first = _firstUp(app);
    final high =
        app.todayTasks.where((t) => t.priority == 'high').length;
    final atRisk =
        app.habits.where((h) => !h.isDoneToday && h.streak > 0).length;
    final buf = StringBuffer('${_greeting()}! Here is your day. ');
    buf.write(
        'You have ${c.total} item${c.total == 1 ? '' : 's'} today. ');
    if (c.beforeNoon > 0) {
      buf.write(
          '${c.beforeNoon} need${c.beforeNoon == 1 ? 's' : ''} attention before noon. ');
    }
    if (first != null) {
      buf.write(
          'First up: ${first.title} at ${DateFormat('h:mm a').format(first.at)}. ');
    }
    if (high > 0) {
      buf.write(
          '$high high-priority task${high == 1 ? '' : 's'} due today. ');
    }
    if (atRisk > 0) {
      buf.write(
          '$atRisk habit streak${atRisk == 1 ? '' : 's'} at risk — keep them alive.');
    }
    return buf.toString();
  }

  Future<void> _toggleReadAloud(AppState app) async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    try {
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.95);
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(_briefingText(app));
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ai = context.watch<SmartAiService>();
    final counts = _heroCounts(app);
    final first = _firstUp(app);
    final high =
        app.todayTasks.where((t) => t.priority == 'high').length;
    final atRisk =
        app.habits.where((h) => !h.isDoneToday && h.streak > 0).toList();
    final suggestions = ai.getSmartSuggestions();

    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: V2.green,
          onRefresh: () => context.read<AppState>().loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: v2PagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${DateFormat('EEEE, MMM d').format(easternNow())} — Your day at a glance',
                    style: V2.sub(14.5),
                  ),
                ),
                const SizedBox(height: 16),
                // Green hero summary card.
                Container(
                  decoration: V2.heroDeco,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have ${counts.total} item${counts.total == 1 ? '' : 's'} today.',
                        style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        counts.beforeNoon == 0
                            ? 'Nothing needs attention before noon.'
                            : '${counts.beforeNoon} need${counts.beforeNoon == 1 ? 's' : ''} attention before noon.',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Read aloud.
                Center(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleReadAloud(app),
                      icon: Icon(
                        _speaking
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        color: V2.green,
                        size: 20,
                      ),
                      label: Text(
                        _speaking ? 'Stop' : 'Read aloud',
                        style: GoogleFonts.poppins(
                          color: V2.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: V2.green, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(23)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Category cards.
                _categoryCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Schedule',
                  subtitle: first == null
                      ? 'Nothing scheduled for today.'
                      : 'First up: ${first.title} at ${DateFormat('h:mm a').format(first.at)}',
                  onTap: () => v2GoTab(context, 1),
                ),
                _categoryCard(
                  icon: Icons.flag_outlined,
                  title: 'Priorities',
                  subtitle: high == 0
                      ? 'No high-priority tasks today.'
                      : '$high high-priority task${high == 1 ? '' : 's'} due today',
                  onTap: () =>
                      Navigator.pushNamed(context, TasksScreen.route),
                ),
                _categoryCard(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Habits',
                  subtitle: app.habits.isEmpty
                      ? 'No habits tracked yet.'
                      : atRisk.isEmpty
                          ? 'All habits on track today.'
                          : '${atRisk.length} streak${atRisk.length == 1 ? '' : 's'} at risk — keep them alive',
                  onTap: () =>
                      Navigator.pushNamed(context, HabitsScreen.route),
                ),
                _categoryCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Weather',
                  subtitle:
                      'See weather-aware packing in the Trips planner.',
                  onTap: () => Navigator.pushNamed(
                      context, TripPlannerScreen.route),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const V2SectionLabel('AI Insights'),
                  if (app.profile?.isPro ?? false)
                    ...suggestions.map((s) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: V2Card(
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const V2IconTile(
                                    Icons.auto_awesome_outlined,
                                    size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(s,
                                      style:
                                          GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              height: 1.4)),
                                ),
                              ],
                            ),
                          ),
                        ))
                  else
                    _proUpsellCard(
                      context,
                      'AI Insights is a Pro feature',
                      'Go Pro for smart suggestions about your day.',
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const V2SubNav(),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2Card(
        onTap: onTap,
        child: Row(
          children: [
            V2IconTile(icon, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: V2.title(20)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: V2.ink,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
