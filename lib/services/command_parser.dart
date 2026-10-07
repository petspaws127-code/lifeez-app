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
  createExpense,
  createBill,
  markBillPaid,
  createSubscription,
  addShoppingItems,
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
  static ParsedCommand parse(String raw) {
    final input = raw.trim();
    final t = input.toLowerCase();
    if (t.isEmpty) return const ParsedCommand(intent: CommandIntent.unknown);

    if (t == 'help' || t.contains('what can you do')) {
      return const ParsedCommand(intent: CommandIntent.help);
    }

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

    // --------------------------------------------------------- reminder
    // "remind me to pay rent on the 1st" / "remind me to call mom tomorrow 5pm"
    m = RegExp(r'remind me to (.+)').firstMatch(t);
    if (m != null) {
      final rest = m.group(1)!;
      final when = extractDateTime(rest);
      return ParsedCommand(
        intent: CommandIntent.createReminder,
        params: {
          'title': _titleCase(_stripDateWords(rest)),
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
    m = RegExp(r'^(add|create)( a| new)? task (.+)').firstMatch(t);
    if (m != null) {
      final rest = m.group(3)!;
      final when = extractDateTime(rest);
      final title = _titleCase(_stripDateWords(rest));
      return ParsedCommand(
        intent: CommandIntent.createTask,
        params: {
          'title': title.isEmpty ? _titleCase(rest) : title,
          'dueAt': when?.toIso8601String(),
          'category': detectTaskCategory(rest),
          'repeat': extractRepeat(rest),
        },
      );
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
  /// Parses "tomorrow 5pm", "on the 1st", "next monday", "every day", etc.
  static DateTime? extractDateTime(String raw) {
    final t = raw.toLowerCase();
    final now = DateTime.now();
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
    final tm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)').firstMatch(t);
    if (tm != null) {
      hour = int.parse(tm.group(1)!);
      minute = tm.group(2) != null ? int.parse(tm.group(2)!) : 0;
      final ap = tm.group(3)!;
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
  static String _stripDateWords(String raw) {
    var s = ' $raw ';
    s = s.replaceAll(
        RegExp(
            r'\b(tomorrow|today|tonight|morning|afternoon|evening|night|every day|daily|weekly|monthly|every week|every month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b'),
        ' ');
    s = s.replaceAll(
        RegExp(r'\b(on )?the \d{1,2}(st|nd|rd|th)?\b'), ' ');
    s = s.replaceAll(
        RegExp(r'\bat \d{1,2}(:\d{2})?\s*(am|pm)\b'), ' ');
    s = s.replaceAll(
        RegExp(r'\b\d{1,2}(:\d{2})?\s*(am|pm)\b'), ' ');
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
