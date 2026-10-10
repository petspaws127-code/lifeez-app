import 'eastern_time.dart';
/// Natural-language command parser — the heart of Lifeez.
///
/// Understands commands like:
///   "I spent \$45 at Walmart" · "remind me to pay rent on the 1st"
///   "add eggs and bread to my shopping list" · "how much do I have left?"
///   "show my tasks" · "done with grocery run" · "set my budget to 2500"
///   "add task buy milk tomorrow 5pm" · "remove task call dentist"
///
/// Pure function: no side effects. [AssistantEngine] executes the result.
enum CommandIntent {
  createTask,
  completeTask,
  deleteTask,
  createReminder,
  createAlarm,
  createHabit,
  addShoppingItems,
  createExpense,
  createBill,
  markBillPaid,
  createSubscription,
  removeShoppingItem,
  setBudget,
  setIncome,
  queryLeft,
  queryTasks,
  queryBills,
  help,
  unknown,
}

class ParsedCommand {
  final CommandIntent intent;
  final Map<String, dynamic> params;
  final bool requiresConfirmation;
  final String summary;

  const ParsedCommand({
    required this.intent,
    this.params = const {},
    this.requiresConfirmation = false,
    this.summary = '',
  });
}

class CommandParser {
  /// Roman Urdu → English normalization map.
  /// Applied before parsing so "kl subah 9 baje dr ke pas jana hai"
  /// becomes "tomorrow morning 9 doctor".
  static String normalizeRomanUrdu(String input) {
    var t = ' ${input.toLowerCase()} ';
    // --- Time words ---
    t = t.replaceAll(RegExp(r'\bkl\b|\bkal\b'), ' tomorrow ');
    t = t.replaceAll(RegExp(r'\baj\b|\baaj\b'), ' today ');
    t = t.replaceAll(RegExp(r'\bparson\b|\bparso\b'), ' day after tomorrow ');
    t = t.replaceAll(RegExp(r'\bsubah\b|\bsubha\b|\bsobh\b'), ' morning ');
    t = t.replaceAll(RegExp(r'\bdopahar\b|\bdupehar\b|\bdopher\b'), ' afternoon ');
    t = t.replaceAll(RegExp(r'\bsham\b|\bshaam\b'), ' evening ');
    t = t.replaceAll(RegExp(r'\braat\b'), ' night ');
    // "9 baje" → "9am" (or "9pm" if evening/night context)
    final isEvening =
        t.contains(' evening ') || t.contains(' night ') || t.contains(' sham ');
    t = t.replaceAllMapped(
        RegExp(r'\b(\d{1,2})\s*baj(e|ay)?\b'),
        (m) => isEvening ? ' ${m.group(1)}pm ' : ' ${m.group(1)}am ');
    // --- Action words ---
    t = t.replaceAll(
        RegExp(r'\byad dilao\b|\byaad dilao\b|\byad dila do\b'), ' remind me ');
    t = t.replaceAll(RegExp(r'\bjana hai\b|\bjana he\b|\bjana\b'), ' ');
    t = t.replaceAll(RegExp(r'\bkarna hai\b|\bkrna hai\b|\bkrna he\b'), ' ');
    t = t.replaceAll(RegExp(r'\bke pas\b|\bk pas\b|\bke paas\b'), ' ');
    t = t.replaceAll(RegExp(r'\bkaam\b|\bkam\b'), ' task ');
    // --- Common nouns ---
    t = t.replaceAll(RegExp(r'\bdr\b|\bdctr\b|\bdocter\b'), ' doctor ');
    t = t.replaceAll(RegExp(r'\bdawai\b|\bdawa\b|\bmedicin\b'), ' medicine ');
    t = t.replaceAll(RegExp(r'\bpaise\b|\bpese\b'), ' money ');
    t = t.replaceAll(RegExp(r'\bdaftar\b|\bofis\b'), ' office ');
    t = t.replaceAll(RegExp(r'\bghar\b'), ' home ');
    t = t.replaceAll(RegExp(r'\bbacha\b|\bbache\b'), ' kid ');
    t = t.replaceAll(RegExp(r'\bami\b|\bammi\b'), ' mom ');
    t = t.replaceAll(RegExp(r'\babu\b|\babba\b'), ' dad ');
    // --- Alarm words ---
    t = t.replaceAll(RegExp(r'\balarm lagao\b|\balarm laga do\b'), ' set alarm ');
    t = t.replaceAll(
        RegExp(r'\butha dena\b|\buthao\b|\bjagao\b'), ' wake me up ');
    t = t.replaceAll(RegExp(r'\bneend\b'), ' sleep ');
    // --- Habit words ---
    t = t.replaceAll(RegExp(r'\broz\b|\bhar roz\b'), ' daily ');
    t = t.replaceAll(RegExp(r'\badat\b|\baadat\b'), ' habit ');
    // --- Shopping words ---
    t = t.replaceAll(RegExp(r'\bgrocery list banao\b|\blist banao\b'), ' add to shopping list ');
    t = t.replaceAll(RegExp(r'\bkhareedna hai\b|\bkhareedna\b'), ' buy ');
    t = t.replaceAll(RegExp(r'\blena hai\b'), ' buy ');
    // --- Voice-to-text artifacts ---
    t = t.replaceAll(RegExp(r'\bplz\b'), ' please ');
    t = t.replaceAll(RegExp(r'\btmrw\b'), ' tomorrow ');
    t = t.replaceAll(RegExp(r'\bdoc\b'), ' doctor ');
    t = t.replaceAll(RegExp(r'\bappt\b|\bappoinment\b'), ' appointment ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Typo-tolerant keyword check: matches if the word is within
  /// 1 edit distance, or is a close substring.
  static bool fuzzyContains(String text, String keyword) {
    if (text.contains(keyword)) return true;
    final words = text.split(' ');
    for (final w in words) {
      if (_editDistance(w, keyword) <= 1 && w.length >= 4) return true;
    }
    return false;
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp =
        List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) dp[i][0] = i;
    for (var j = 0; j <= b.length; j++) dp[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 +
                [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                    .reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  static ParsedCommand parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const ParsedCommand(intent: CommandIntent.unknown);
    }
    // Normalize Roman Urdu / typos / voice artifacts BEFORE parsing.
    final normalized = normalizeRomanUrdu(input);
    final t = normalized.toLowerCase();

    if (t == 'help' || t.contains('what can you do')) {
      return const ParsedCommand(intent: CommandIntent.help);
    }

    // --------------------------------------- implicit appointment/reminder
    // "doctor appointment tomorrow 9am" / "tomorrow morning 9am doctor"
    // (after Roman Urdu normalization) — no "remind me" prefix needed.
    // If it has a date/time AND looks like an event, auto-create a reminder.
    // NEVER hijack explicit "add task" / "create task" commands,
    // or any text that clearly mentions "task".
    final isExplicitTask = RegExp(r'\btask\b').hasMatch(t);
    if (!isExplicitTask) {
      final when = extractDateTime(t);
      final hasEventWord = RegExp(
              r'\b(appointment|meeting|visit|call|doctor|dentist|interview|flight|dinner|lunch|breakfast|party|wedding|birthday|anniversary|deadline|exam|class|gym|workout)\b')
          .hasMatch(t);
      if (when != null && (hasEventWord || _looksLikeReminder(t))) {
        final title = _titleCase(stripDateWords(t));
        if (title.isNotEmpty && title.length > 2) {
          return ParsedCommand(
            intent: CommandIntent.createReminder,
            params: {
              'title': title,
              'remindAt': when.toIso8601String(),
              'repeat': extractRepeat(t),
            },
          );
        }
      }
    } // end if (!isExplicitTask)

    // ---------------------------------------------------------- queries
    if (RegExp(r'how much.*(left|remain)').hasMatch(t) ||
        t.contains('money left') ||
        t.contains('budget left') ||
        t == 'left to spend') {
      return const ParsedCommand(intent: CommandIntent.queryLeft);
    }
    if (RegExp(r'(show|list|what are|get)\s+(my\s+|all\s+)?tasks')
            .hasMatch(t) ||
        t == 'my tasks' ||
        t == 'show my tasks') {
      return const ParsedCommand(intent: CommandIntent.queryTasks);
    }
    if (RegExp(r'(show|list)\s+(my\s+)?bills').hasMatch(t)) {
      return const ParsedCommand(intent: CommandIntent.queryBills);
    }

    // ------------------------------------------------- budget / income
    var m = RegExp(r'set (my )?budget to \$?\s?([\d,]+(?:\.\d+)?)')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.setBudget,
        params: {'amount': _toDouble(m.group(2)!)},
      );
    }
    m = RegExp(r'set (my )?income to \$?\s?([\d,]+(?:\.\d+)?)')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.setIncome,
        params: {'amount': _toDouble(m.group(2)!)},
      );
    }

    // ---------------------------------------------------------- expense
    // "I spent $45 at Walmart" / "spent 20 on gas"
    if (t.contains('spent')) {
      m = RegExp(r'spent \$?\s?([\d,]+(?:\.\d+)?)\s*(?:at|on|for)?\s*([a-z0-9 &.,-]*)')
          .firstMatch(t);
      if (m != null) {
        final note = (m.group(2) ?? '').trim();
        return ParsedCommand(
          intent: CommandIntent.createExpense,
          params: {
            'amount': _toDouble(m.group(1)!),
            'note': _titleCase(note),
            'category': detectExpenseCategory('$note $t'),
          },
        );
      }
    }

    // --------------------------------------------------------- shopping
    // "add eggs and bread to my shopping list"
    m = RegExp(r'add (.+?) to (my )?shopping list').firstMatch(t);
    if (m != null) {
      final items = m
          .group(1)!
          .split(RegExp(r',|\band\b'))
          .map((e) => _titleCase(e.trim()))
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        return ParsedCommand(
          intent: CommandIntent.addShoppingItems,
          params: {'items': items},
        );
      }
    }
    // "remove milk from shopping list"
    m = RegExp(r'(remove|delete) (.+?) from (my )?shopping list')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.removeShoppingItem,
        params: {'query': m.group(2)!.trim()},
      );
    }

    // ------------------------------------------------------------- bill
    // "add bill rent $1800 on the 1st"
    m = RegExp(
            r'add bill ([a-z0-9 ]+?) \$?\s?([\d,]+(?:\.\d+)?)\s*(?:on|due)?\s*(?:the )?(\d{1,2})(?:st|nd|rd|th)?')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.createBill,
        params: {
          'name': _titleCase(m.group(1)!.trim()),
          'amount': _toDouble(m.group(2)!),
          'dueDay': int.parse(m.group(3)!),
        },
      );
    }
    // "mark rent as paid" / "pay electric bill"
    m = RegExp(r'(mark|pay) (.+?) (as )?paid').firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.markBillPaid,
        params: {'query': m.group(2)!.trim()},
      );
    }

    // ------------------------------------------------------------ alarm
    // "set alarm for 8am" / "set alarm every morning 8am" /
    // "wake me up at 7" / "alarm lagao subah 6 baje" (normalized).
    // NEVER ask for rephrasing — always create the alarm immediately.
    if (RegExp(r'\b(set|create|add)\s+(an?\s+)?alarm\b').hasMatch(t) ||
        t.contains('wake me up')) {
      final when = extractDateTime(t);
      // Default to 8am if no time found.
      final hour = when?.hour ?? 8;
      final minute = when?.minute ?? 0;
      // "every morning" / "daily" / "every day" → repeat all 7 days.
      final isDaily = t.contains('every morning') ||
          t.contains('every day') ||
          t.contains('daily') ||
          extractRepeat(t) == 'daily';
      final label = _titleCase(stripDateWords(
              t.replaceAll(RegExp(r'\b(set|create|add)\s+(an?\s+)?alarm\b'), '')
                  .replaceAll('wake me up', '')
                  .trim()));
      return ParsedCommand(
        intent: CommandIntent.createAlarm,
        params: {
          'label': label.isEmpty ? 'Alarm' : label,
          'hour': hour,
          'minute': minute,
          'repeatDays': isDaily ? [1, 2, 3, 4, 5, 6, 7] : <int>[],
        },
      );
    }

    // ------------------------------------------------------------ habit
    // "track habit read daily" / "roz exercise karna hai" (→"daily exercise") /
    // "daily pani peena hai" — no rigid syntax needed.
    if (t.contains('habit') ||
        (t.contains('daily') &&
            RegExp(r'\b(read|exercise|workout|meditat|yoga|water|walk|run|study|practice|pray)\b')
                .hasMatch(t))) {
      var title = t
          .replaceAll(RegExp(r'\btrack habit\b|\bhabit\b'), '')
          .replaceAll(RegExp(r'\bdaily\b'), '')
          .trim();
      title = _titleCase(stripDateWords(title));
      if (title.isNotEmpty) {
        return ParsedCommand(
          intent: CommandIntent.createHabit,
          params: {'title': title, 'repeat': 'daily'},
        );
      }
    }

    // ---------------------------------------------------------- shopping
    // "grocery list banao" (→"add to shopping list") / "doodh lena hai" (→"doodh buy") /
    // "buy milk and eggs" — natural shopping phrases.
    if (t.contains('add to shopping list') ||
        (RegExp(r'\bbuy\b').hasMatch(t) &&
            !t.contains('add task') &&
            !t.contains('remind'))) {
      var itemsStr = t
          .replaceAll('add to shopping list', '')
          .replaceAll(RegExp(r'^\s*buy\s+'), '')
          .trim();
      if (itemsStr.isNotEmpty) {
        final items = itemsStr
            .split(RegExp(r',|\band\b'))
            .map((e) => _titleCase(e.trim()))
            .where((e) => e.isNotEmpty && e.length > 1)
            .toList();
        if (items.isNotEmpty) {
          return ParsedCommand(
            intent: CommandIntent.addShoppingItems,
            params: {'items': items},
          );
        }
      }
    }

    // --------------------------------------------------------- reminder
    // "remind me to pay rent on the 1st" / "remind me to call mom tomorrow 5pm"
    m = RegExp(r'remind me to (.+)').firstMatch(t);
    if (m != null) {
      final rest = m.group(1)!;
      final when = extractDateTime(rest);
      return ParsedCommand(
        intent: CommandIntent.createReminder,
        params: {
          'title': _titleCase(stripDateWords(rest)),
          'remindAt': when?.toIso8601String(),
          'repeat': extractRepeat(rest),
        },
      );
    }

    // ---------------------------------------------------- complete task
    // "done with grocery run" / "mark call dentist done"
    m = RegExp(r'^(done with|finished|complete|completed)\s+(.+)')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.completeTask,
        params: {'query': m.group(2)!.trim()},
      );
    }
    m = RegExp(r'mark (.+?) (as )?done').firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.completeTask,
        params: {'query': m.group(1)!.trim()},
      );
    }

    // ------------------------------------------------------ delete task
    // "remove task call dentist" — always confirmed first.
    m = RegExp(r'^(remove|delete)( the)? task (.+)').firstMatch(t);
    if (m != null) {
      final q = m.group(3)!.trim();
      return ParsedCommand(
        intent: CommandIntent.deleteTask,
        params: {'query': q},
        requiresConfirmation: true,
        summary: 'delete the task matching "$q"',
      );
    }

    // --------------------------------------------------------- add task
    // "add task buy milk tomorrow 5pm"
    // Tasks do NOT get a default time: if the user didn't say a time,
    // the task is due on that date with no specific time.
    m = RegExp(r'^(add|create)( a| new)? task (.+)').firstMatch(t);
    if (m != null) {
      final rest = m.group(3)!;
      final when = extractDateTime(rest);
      final title = _titleCase(stripDateWords(rest));
      return ParsedCommand(
        intent: CommandIntent.createTask,
        params: {
          'title': title.isEmpty ? _titleCase(rest) : title,
          'dueAt': when?.toIso8601String(),
          'hasTime': hasExplicitTime(rest),
          'category': detectTaskCategory(rest),
          'repeat': extractRepeat(rest),
        },
      );
    }

    // "wash car tomorrow task" — "task" at the end.
    // Exclude other command verbs (remove/delete/complete/show/list).
    m = RegExp(r'^(?!remove\b|delete\b|complete\b|done\b|show\b|list\b)(.+?)\s+task$')
        .firstMatch(t);
    if (m != null) {
      final rest = m.group(1)!.trim();
      if (rest.isNotEmpty) {
        final when = extractDateTime(rest);
        final title = _titleCase(stripDateWords(rest));
        return ParsedCommand(
          intent: CommandIntent.createTask,
          params: {
            'title': title.isEmpty ? _titleCase(rest) : title,
            'dueAt': when?.toIso8601String(),
            'hasTime': hasExplicitTime(rest),
            'category': detectTaskCategory(rest),
            'repeat': extractRepeat(rest),
          },
        );
      }
    }

    // ----------------------------------------------------- subscription
    // "add subscription netflix $15.99"
    m = RegExp(r'add subscription ([a-z0-9 .&+-]+?) \$?\s?([\d,]+(?:\.\d+)?)')
        .firstMatch(t);
    if (m != null) {
      return ParsedCommand(
        intent: CommandIntent.createSubscription,
        params: {
          'name': _titleCase(m.group(1)!.trim()),
          'amount': _toDouble(m.group(2)!),
        },
      );
    }

    return const ParsedCommand(intent: CommandIntent.unknown);
  }

  // ------------------------------------------------------------- dates
  /// Returns true if the text contains an explicit time ("5pm", "9:00 am",
  /// "morning", "evening", etc.). Used so tasks don't get a default time
  /// the user never asked for.
  static bool hasExplicitTime(String raw) {
    final t = raw.toLowerCase();
    if (RegExp(r'\d{1,2}(?::\d{2})?\s*(a\.?m\.?|p\.?m\.?)').hasMatch(t)) {
      return true;
    }
    return t.contains('morning') ||
        t.contains('afternoon') ||
        t.contains('evening') ||
        t.contains('night') ||
        t.contains('tonight') ||
        t.contains('noon') ||
        t.contains('midnight');
  }

  /// Parses "tomorrow 5pm", "on the 1st", "next monday", "every day", etc.
  static DateTime? extractDateTime(String raw) {
    final t = raw.toLowerCase();
    final now = easternNow();
    var day = DateTime(now.year, now.month, now.day);
    var foundDay = false;

    if (t.contains('tomorrow')) {
      day = day.add(const Duration(days: 1));
      foundDay = true;
    } else if (t.contains('today') || t.contains('tonight')) {
      foundDay = true;
    } else {
      const weekdays = {
        'monday': 1,
        'tuesday': 2,
        'wednesday': 3,
        'thursday': 4,
        'friday': 5,
        'saturday': 6,
        'sunday': 7,
      };
      for (final entry in weekdays.entries) {
        if (t.contains(entry.key)) {
          day = _nextWeekday(now, entry.value);
          foundDay = true;
          break;
        }
      }
      if (!foundDay) {
        final m =
            RegExp(r'(?:on )?the (\d{1,2})(?:st|nd|rd|th)?').firstMatch(t);
        if (m != null) {
          day = _dayOfMonth(now, int.parse(m.group(1)!));
          foundDay = true;
        }
      }
    }

    var hour = 9;
    var minute = 0;
    var foundTime = false;
    // Handle "9am", "9:00am", "9 a.m.", "9:00 p.m." (with or without periods).
    final tm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)')
        .firstMatch(t);
    if (tm != null) {
      hour = int.parse(tm.group(1)!);
      minute = tm.group(2) != null ? int.parse(tm.group(2)!) : 0;
      final ap = tm.group(3)!.replaceAll('.', '');
      if (ap == 'pm' && hour < 12) hour += 12;
      if (ap == 'am' && hour == 12) hour = 0;
      foundTime = true;
    } else if (t.contains('morning')) {
      hour = 9;
      foundTime = true;
    } else if (t.contains('afternoon')) {
      hour = 14;
      foundTime = true;
    } else if (t.contains('evening')) {
      hour = 18;
      foundTime = true;
    } else if (t.contains('night') || t.contains('tonight')) {
      hour = 21;
      foundTime = true;
    }

    if (!foundDay && !foundTime) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  static DateTime _nextWeekday(DateTime now, int weekday) {
    var delta = (weekday - now.weekday) % 7;
    if (delta <= 0) delta += 7;
    final d = now.add(Duration(days: delta));
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _dayOfMonth(DateTime now, int day) {
    final clamped = day.clamp(1, 28);
    var target = DateTime(now.year, now.month, clamped);
    if (target.isBefore(
        DateTime(now.year, now.month, now.day))) {
      final nextMonth =
          now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      target = DateTime(nextYear, nextMonth, clamped);
    }
    return target;
  }

  static String? extractRepeat(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('every day') || t.contains('daily')) return 'daily';
    if (t.contains('every week') || t.contains('weekly')) return 'weekly';
    if (t.contains('every month') || t.contains('monthly')) return 'monthly';
    return null;
  }

  /// Removes date/time words so "buy milk tomorrow 5pm" → "buy milk".
  /// Public so AssistantEngine can reuse it for fallback titles.
  static String stripDateWords(String raw) {
    var s = ' $raw ';
    s = s.replaceAll(
        RegExp(
            r'\b(tomorrow|today|tonight|morning|afternoon|evening|night|every day|daily|weekly|monthly|every week|every month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b'),
        ' ');
    s = s.replaceAll(
        RegExp(r'\b(on )?the \d{1,2}(st|nd|rd|th)?\b'), ' ');
    s = s.replaceAll(
        RegExp(r'\bat \d{1,2}(:\d{2})?\s*(a\.?m\.?|p\.?m\.?)\b'), ' ');
    s = s.replaceAll(
        RegExp(r'\b\d{1,2}(:\d{2})?\s*(a\.?m\.?|p\.?m\.?)\b'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // -------------------------------------------------------- categories
  static String detectExpenseCategory(String raw) {
    final t = raw.toLowerCase();
    bool any(List<String> words) =>
        words.any((w) => t.contains(w));
    if (any(['restaurant', 'pizza', 'burger', 'coffee', 'lunch', 'dinner',
        'breakfast', 'doordash', 'uber eats', 'mcdonald', 'starbucks',
        'food'])) {
      return 'Food';
    }
    if (any(['grocery', 'groceries', 'supermarket', 'costco', 'eggs',
        'milk', 'bread'])) {
      return 'Grocery';
    }
    if (any(['uber', 'lyft', 'taxi', 'gas', 'fuel', 'bus', 'train',
        'parking', 'metro', 'flight'])) {
      return 'Transport';
    }
    if (any(['amazon', 'mall', 'clothes', 'shoes', 'shirt', 'target',
        'walmart', 'store'])) {
      return 'Shopping';
    }
    if (any(['rent', 'electric', 'water bill', 'internet', 'phone bill',
        'utility'])) {
      return 'Bills';
    }
    if (any(['pharmacy', 'doctor', 'dentist', 'cvs', 'walgreens', 'gym',
        'hospital', 'medicine'])) {
      return 'Health';
    }
    return 'Other';
  }

  static String detectTaskCategory(String raw) {
    final t = raw.toLowerCase();
    bool any(List<String> words) =>
        words.any((w) => t.contains(w));
    if (any(['milk', 'eggs', 'bread', 'grocery', 'groceries', 'buy ',
        'shopping'])) {
      return 'grocery';
    }
    if (any(['doctor', 'dentist', 'pharmacy', 'gym', 'workout'])) {
      return 'health';
    }
    if (any(['rent', 'bill', 'pay '])) return 'bills';
    if (any(['meeting', 'email', 'report', 'project', 'deadline'])) {
      return 'work';
    }
    if (any(['clean', 'laundry', 'home', 'house'])) return 'home';
    if (any(['call ', 'mom', 'dad'])) return 'calls';
    return 'general';
  }

  /// Heuristic: does this look like something the user wants to be
  /// reminded about? Used for implicit reminder detection.
  static bool _looksLikeReminder(String t) {
    // Has a time reference but no explicit action verb — likely an appointment.
    final hasTime = RegExp(
            r'\b(tomorrow|today|tonight|morning|afternoon|evening|night|monday|tuesday|wednesday|thursday|friday|saturday|sunday|\d{1,2}\s*(am|pm))\b')
        .hasMatch(t);
    final hasActionVerb = RegExp(
            r'\b(add|create|remind|set|buy|get|do|make|send|pay|call|book)\b')
        .hasMatch(t);
    // Time + noun phrase without action verb = implicit reminder.
    return hasTime && !hasActionVerb && t.split(' ').length >= 2;
  }

  // ------------------------------------------------------------ helpers
  static double _toDouble(String s) =>
      double.tryParse(s.replaceAll(',', '')) ?? 0;

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
