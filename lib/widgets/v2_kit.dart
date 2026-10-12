import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// V2 design system — shared tokens and components for the redesign.
/// Light theme only (matches the approved mockups). No blue anywhere.
class V2 {
  V2._();

  static const Color bg = Color(0xFFFAFAF7);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF1a9c63);
  static const Color greenDark = Color(0xFF147A4E);
  static const Color chip = Color(0xFFE7F4EC);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF6B7280);
  static const Color danger = Color(0xFFD64545);
  static const Color amber = Color(0xFFE8A33D);

  static TextStyle display([double size = 30]) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.15,
      );

  static TextStyle title([double size = 17]) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: ink,
      );

  static TextStyle body([double size = 14]) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: ink,
      );

  static TextStyle sub([double size = 13]) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: muted,
      );

  static TextStyle greenLabel([double size = 13]) => GoogleFonts.poppins(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: green,
      );

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x0D1E7D4F),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  static BoxDecoration get cardDeco => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow,
      );

  static BoxDecoration get heroDeco => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [greenDark, green],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E1E7D4F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      );
}

/// White rounded card, radius 20, soft shadow. The default V2 surface.
class V2Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const V2Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: V2.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: V2.softShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

/// Small-caps grey section label, e.g. "MORNING", "TODAY".
class V2SectionLabel extends StatelessWidget {
  final String text;
  const V2SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: V2.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Selectable filter pill, e.g. All | Today | Upcoming | Done.
/// Mockups: stadium pill; selected = green fill + white text; unselected =
/// grey fill + ink text (Tasks/Money) or white + grey border (outlined=true,
/// Pets tabs).
class V2Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool outlined;

  const V2Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border? border;
    if (selected) {
      bg = V2.green;
      fg = Colors.white;
      border = null;
    } else if (outlined) {
      bg = Colors.white;
      fg = V2.muted;
      border = Border.all(color: const Color(0xFFD8D8D2), width: 1.2);
    } else {
      bg = const Color(0xFFE9E9E2);
      fg = V2.ink;
      border = null;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: border,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Light-green circular icon tile used in list rows.
class V2IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;

  const V2IconTile(this.icon,
      {super.key, this.size = 48, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? V2.chip,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: fg ?? V2.green, size: size * 0.48),
    );
  }
}

/// Green circular "+" add button (top-right of screens).
class V2AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const V2AddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: V2.green,
          shape: BoxShape.circle,
          boxShadow: V2.softShadow,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

/// Slim rounded progress bar.
class V2ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;

  const V2ProgressBar({
    super.key,
    required this.value,
    this.color = V2.green,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: V2.chip,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Full-width glossy green button.
class V2PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const V2PrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: V2.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 6,
          shadowColor: V2.green.withOpacity(0.4),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Large screen title row with optional trailing action.
/// Mockups use a ~40pt extra-bold hero title.
class V2TitleRow extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const V2TitleRow({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    // Responsive: scale down on narrow screens to prevent overflow.
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 360 ? 32.0 : (width < 400 ? 36.0 : 40.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: V2.display(fontSize),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Green toggle switch matching the V2 palette.
class V2Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const V2Switch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: V2.green,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD1D5DB),
    );
  }
}

/// Standard V2 page padding for scrollable screens.
const v2PagePadding = EdgeInsets.fromLTRB(20, 12, 20, 100);

/// Navigate from a pushed sub-screen back to a MainTabs tab (0=Home,
/// 1=Today, 2=Upcoming, 3=Profile). MainTabs reads the int argument.
void v2GoTab(BuildContext context, int tab) {
  Navigator.of(context)
      .pushNamedAndRemoveUntil('/home', (r) => false, arguments: tab);
}

/// The V2 bottom nav: floating white rounded bar with a raised glossy green
/// center AI button. Identical on every screen (per the mockups).
class V2BottomNav extends StatelessWidget {
  final int? activeIndex; // 0..3, null = no tab highlighted
  final bool aiActive;
  final ValueChanged<int> onTab;
  final VoidCallback onAi;

  const V2BottomNav({
    super.key,
    this.activeIndex,
    this.aiActive = false,
    required this.onTab,
    required this.onAi,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 96,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: V2.softShadow,
                ),
                child: Row(
                  children: [
                    // Mockups: house, list (Today), clock (Upcoming), person.
                    // Active = filled green icon, inactive = outline grey.
                    _slot(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                    _slot(1, Icons.format_list_bulleted_rounded,
                        Icons.format_list_bulleted_outlined, 'Today'),
                    const Expanded(child: SizedBox()),
                    _slot(2, Icons.schedule_rounded, Icons.schedule_outlined,
                        'Upcoming'),
                    _slot(3, Icons.person_rounded,
                        Icons.person_outline_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              child: GestureDetector(
                onTap: onAi,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [V2.greenDark, V2.green],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: V2.green.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: aiActive
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(int index, IconData filled, IconData outline, String label) {
    final selected = activeIndex == index;
    final color = selected ? V2.green : V2.muted;
    return Expanded(
      child: InkWell(
        onTap: () => onTab(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mockups: active tab = filled icon, inactive = outline.
              Icon(selected ? filled : outline, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop-in bottom nav for pushed sub-screens (Tasks, Money, Settings, ...).
/// Tabs return to MainTabs; the AI button opens the full-screen assistant.
class V2SubNav extends StatelessWidget {
  final int? activeIndex;
  final bool aiActive;

  const V2SubNav({super.key, this.activeIndex, this.aiActive = false});

  @override
  Widget build(BuildContext context) {
    return V2BottomNav(
      activeIndex: activeIndex,
      aiActive: aiActive,
      onTab: (i) => v2GoTab(context, i),
      onAi: () {
        // Don't stack duplicate assistant screens.
        final route = ModalRoute.of(context);
        if (route != null && route.settings.name == '/assistant') return;
        Navigator.of(context).pushNamed('/assistant');
      },
    );
  }
}
