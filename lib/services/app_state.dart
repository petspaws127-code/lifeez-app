import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'supabase_client.dart';
import 'command_parser.dart';
import '../models/profile.dart';
import '../models/task_item.dart';
import '../models/expense.dart';
import '../models/bill.dart';
import '../models/subscription.dart';
import '../models/shopping_item.dart';
import '../models/reminder.dart';
import '../models/document_item.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';
import '../models/family_member.dart';

const _uuid = Uuid();

/// Central state: all user data, Supabase persistence, and computed values.
/// Everything the UI shows comes from here, so any change (app, AI bar,
/// WhatsApp chat) updates every screen instantly via [notifyListeners].
class AppState extends ChangeNotifier {
  Profile? profile;
  List<TaskItem> tasks = [];
  List<Expense> expenses = [];
  List<Bill> bills = [];
  List<Subscription> subscriptions = [];
  List<ShoppingItem> shoppingItems = [];
  List<Reminder> reminders = [];
  List<DocumentItem> documents = [];
  List<Vehicle> vehicles = [];
  List<MaintenanceItem> maintenanceItems = [];
  List<FamilyMember> familyMembers = [];

  bool loading = false;
  String? error;

  String? get _uid => SupabaseService.currentUserId;

  // ------------------------------------------------------------- loading
  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final uid = _uid;
      if (uid == null) return;
      final c = SupabaseService.client;
      final results = await Future.wait([
        c.from('profiles').select().eq('id', uid).maybeSingle(),
        c.from('tasks').select().eq('user_id', uid).order('created_at'),
        c.from('expenses').select().eq('user_id', uid).order('spent_at'),
        c.from('bills').select().eq('user_id', uid).order('due_day'),
        c.from('subscriptions').select().eq('user_id', uid),
        c.from('shopping_items').select().eq('user_id', uid),
        c.from('reminders').select().eq('user_id', uid).order('remind_at'),
        c.from('documents').select().eq('user_id', uid),
        c.from('vehicles').select().eq('user_id', uid),
        c.from('maintenance_items').select().eq('user_id', uid),
        c.from('family_members').select().eq('user_id', uid),
      ]);
      List<Map<String, dynamic>> list(dynamic r) =>
          r == null ? [] : List<Map<String, dynamic>>.from(r as List);

      final p = results[0];
      profile = p == null
          ? null
          : Profile.fromJson(Map<String, dynamic>.from(p as Map));
      tasks = list(results[1]).map(TaskItem.fromJson).toList();
      expenses = list(results[2]).map(Expense.fromJson).toList();
      bills = list(results[3]).map(Bill.fromJson).toList();
      subscriptions =
          list(results[4]).map(Subscription.fromJson).toList();
      shoppingItems =
          list(results[5]).map(ShoppingItem.fromJson).toList();
      reminders = list(results[6]).map(Reminder.fromJson).toList();
      documents =
          list(results[7]).map(DocumentItem.fromJson).toList();
      vehicles = list(results[8]).map(Vehicle.fromJson).toList();
      maintenanceItems =
          list(results[9]).map(MaintenanceItem.fromJson).toList();
      familyMembers =
          list(results[10]).map(FamilyMember.fromJson).toList();
    } catch (e) {
      error = 'Could not load your data: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearLocal() {
    profile = null;
    tasks = [];
    expenses = [];
    bills = [];
    subscriptions = [];
    shoppingItems = [];
    reminders = [];
    documents = [];
    vehicles = [];
    maintenanceItems = [];
    familyMembers = [];
    notifyListeners();
  }

  Future<void> _save(String table, Map<String, dynamic> row) async {
    try {
      await SupabaseService.client.from(table).upsert(row);
    } catch (e) {
      error = 'Sync issue ($table): $e';
    }
  }

  Future<void> _delete(String table, String id) async {
    try {
      await SupabaseService.client.from(table).delete().eq('id', id);
    } catch (e) {
      error = 'Sync issue ($table): $e';
    }
  }

  // ------------------------------------------------------------- profile
  Future<void> saveProfile(Profile p) async {
    profile = p;
    notifyListeners();
    await _save('profiles', p.toJson());
    notifyListeners();
  }

  // --------------------------------------------------------------- tasks
  Future<void> addTask(TaskItem t) async {
    tasks.add(t);
    notifyListeners();
    await _save('tasks', t.toJson());
  }

  Future<void> updateTask(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i != -1) tasks[i] = t;
    notifyListeners();
    await _save('tasks', t.toJson());
  }

  Future<void> toggleTask(String id) async {
    final i = tasks.indexWhere((e) => e.id == id);
    if (i == -1) return;
    tasks[i] = tasks[i].copyWith(isDone: !tasks[i].isDone);
    notifyListeners();
    await _save('tasks', tasks[i].toJson());
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('tasks', id);
  }

  // ------------------------------------------------------------ expenses
  Future<void> addExpense(Expense e) async {
    expenses.add(e);
    notifyListeners();
    await _save('expenses', e.toJson());
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('expenses', id);
  }

  // --------------------------------------------------------------- bills
  Future<void> addBill(Bill b) async {
    bills.add(b);
    notifyListeners();
    await _save('bills', b.toJson());
  }

  Future<void> setBillPaid(String id, bool paid) async {
    final i = bills.indexWhere((e) => e.id == id);
    if (i == -1) return;
    bills[i] = bills[i].copyWith(paidThisMonth: paid);
    notifyListeners();
    await _save('bills', bills[i].toJson());
  }

  Future<void> deleteBill(String id) async {
    bills.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('bills', id);
  }

  // ------------------------------------------------------- subscriptions
  Future<void> addSubscription(Subscription s) async {
    subscriptions.add(s);
    notifyListeners();
    await _save('subscriptions', s.toJson());
  }

  Future<void> deleteSubscription(String id) async {
    subscriptions.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('subscriptions', id);
  }

  // ------------------------------------------------------------ shopping
  Future<void> addShoppingItem(ShoppingItem s) async {
    shoppingItems.add(s);
    notifyListeners();
    await _save('shopping_items', s.toJson());
  }

  Future<void> toggleShoppingItem(String id) async {
    final i = shoppingItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    shoppingItems[i] =
        shoppingItems[i].copyWith(isBought: !shoppingItems[i].isBought);
    notifyListeners();
    await _save('shopping_items', shoppingItems[i].toJson());
  }

  Future<void> deleteShoppingItem(String id) async {
    shoppingItems.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('shopping_items', id);
  }

  // ----------------------------------------------------------- reminders
  Future<void> addReminder(Reminder r) async {
    reminders.add(r);
    notifyListeners();
    await _save('reminders', r.toJson());
  }

  Future<void> toggleReminder(String id) async {
    final i = reminders.indexWhere((e) => e.id == id);
    if (i == -1) return;
    reminders[i] = reminders[i].copyWith(isDone: !reminders[i].isDone);
    notifyListeners();
    await _save('reminders', reminders[i].toJson());
  }

  Future<void> deleteReminder(String id) async {
    reminders.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('reminders', id);
  }

  // ----------------------------------------------------------- documents
  Future<void> addDocument(DocumentItem d) async {
    documents.add(d);
    notifyListeners();
    await _save('documents', d.toJson());
  }

  Future<void> deleteDocument(String id) async {
    documents.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('documents', id);
  }

  // ----------------------------------------------------------------- car
  Future<void> addVehicle(Vehicle v) async {
    vehicles.add(v);
    notifyListeners();
    await _save('vehicles', v.toJson());
  }

  Future<void> updateMileage(String id, double mileage) async {
    final i = vehicles.indexWhere((e) => e.id == id);
    if (i == -1) return;
    vehicles[i] = vehicles[i].copyWith(mileage: mileage);
    notifyListeners();
    await _save('vehicles', vehicles[i].toJson());
  }

  Future<void> addMaintenance(MaintenanceItem m) async {
    maintenanceItems.add(m);
    notifyListeners();
    await _save('maintenance_items', m.toJson());
  }

  Future<void> toggleMaintenance(String id) async {
    final i = maintenanceItems.indexWhere((e) => e.id == id);
    if (i == -1) return;
    maintenanceItems[i] =
        maintenanceItems[i].copyWith(isDone: !maintenanceItems[i].isDone);
    notifyListeners();
    await _save('maintenance_items', maintenanceItems[i].toJson());
  }

  // -------------------------------------------------------------- family
  Future<void> addFamilyMember(FamilyMember f) async {
    familyMembers.add(f);
    notifyListeners();
    await _save('family_members', f.toJson());
  }

  Future<void> deleteFamilyMember(String id) async {
    familyMembers.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('family_members', id);
  }

  // ------------------------------------------------------- delete my data
  Future<void> deleteAllMyData() async {
    const tables = [
      'tasks',
      'expenses',
      'bills',
      'subscriptions',
      'shopping_items',
      'reminders',
      'documents',
      'maintenance_items',
      'vehicles',
      'family_members',
      'message_log',
      'whatsapp_connections',
      'profiles',
    ];
    final uid = _uid;
    if (uid != null) {
      try {
        for (final t in tables) {
          final col = t == 'profiles' ? 'id' : 'user_id';
          await SupabaseService.client.from(t).delete().eq(col, uid);
        }
      } catch (e) {
        error = 'Delete failed: $e';
      }
    }
    clearLocal();
  }

  // -------------------------------------------------------------- getters
  double get spentThisMonth {
    final now = DateTime.now();
    return expenses
        .where((e) =>
            e.spentAt.year == now.year && e.spentAt.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get leftToSpend =>
      (profile?.monthlyBudget ?? 0) - spentThisMonth;

  double get budgetUsedPct {
    final b = profile?.monthlyBudget ?? 0;
    if (b <= 0) return 0;
    return (spentThisMonth / b).clamp(0.0, 1.0);
  }

  List<TaskItem> get openTasks =>
      tasks.where((t) => !t.isDone).toList();

  List<TaskItem> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return tasks
        .where((t) =>
            !t.isDone &&
            t.dueDate != null &&
            DateTime(t.dueDate!.year, t.dueDate!.month,
                    t.dueDate!.day) ==
                today)
        .toList();
  }

  List<TaskItem> get upcomingTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return tasks
        .where((t) =>
            !t.isDone &&
            (t.dueDate == null ||
                DateTime(t.dueDate!.year, t.dueDate!.month,
                        t.dueDate!.day)
                    .isAfter(today)))
        .toList();
  }

  List<TaskItem> get completedTasks =>
      tasks.where((t) => t.isDone).toList();

  List<Bill> get unpaidBills =>
      bills.where((b) => !b.paidThisMonth).toList();

  List<ShoppingItem> get shoppingToBuy =>
      shoppingItems.where((s) => !s.isBought).toList();

  List<Reminder> get activeReminders =>
      reminders.where((r) => !r.isDone).toList();

  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    final now = DateTime.now();
    for (final e in expenses) {
      if (e.spentAt.year == now.year && e.spentAt.month == now.month) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }

  double get subscriptionsMonthlyTotal =>
      subscriptions.fold(0.0, (s, x) => s + x.monthlyCost);

  // ------------------------------------------------- command execution
  /// Executes a parsed command and returns the assistant's reply text.
  Future<String> executeCommand(ParsedCommand cmd) async {
    final uid = _uid ?? 'local';
    final p = cmd.params;
    switch (cmd.intent) {
      case CommandIntent.createTask:
        final due = p['dueAt'] != null
            ? DateTime.tryParse(p['dueAt'] as String)
            : null;
        await addTask(TaskItem(
          id: _uuid.v4(),
          userId: uid,
          title: (p['title'] as String?) ?? 'Untitled task',
          dueDate: due,
          category: (p['category'] as String?) ?? 'general',
          repeat: p['repeat'] as String?,
          source: 'whatsapp',
          createdAt: DateTime.now(),
        ));
        return due == null
            ? 'Task added: ${p['title']}.'
            : 'Task added: ${p['title']} (due ${_fmtDateTime(due)}).';

      case CommandIntent.completeTask:
        final q = (p['query'] as String).toLowerCase();
        final match = _bestTaskMatch(q);
        if (match == null) {
          return 'I could not find an open task matching "$q".';
        }
        await toggleTask(match.id);
        return 'Marked done: ${match.title}. Nice work.';

      case CommandIntent.deleteTask:
        final q = (p['query'] as String).toLowerCase();
        final match = _bestTaskMatch(q, includeDone: true);
        if (match == null) return 'No task found matching "$q".';
        await deleteTask(match.id);
        return 'Deleted task: ${match.title}.';

      case CommandIntent.createReminder:
        final at = p['remindAt'] != null
            ? DateTime.tryParse(p['remindAt'] as String)
            : null;
        await addReminder(Reminder(
          id: _uuid.v4(),
          userId: uid,
          title: (p['title'] as String?) ?? 'Reminder',
          remindAt: at ?? DateTime.now().add(const Duration(hours: 1)),
          repeat: p['repeat'] as String?,
        ));
        return at == null
            ? 'Reminder set: ${p['title']}.'
            : 'Reminder set: ${p['title']} at ${_fmtDateTime(at)}.';

      case CommandIntent.createExpense:
        final amount = (p['amount'] as num).toDouble();
        final category = (p['category'] as String?) ?? 'Other';
        final note = (p['note'] as String?) ?? '';
        await addExpense(Expense(
          id: _uuid.v4(),
          userId: uid,
          amount: amount,
          category: category,
          note: note,
          spentAt: DateTime.now(),
          source: 'whatsapp',
        ));
        return 'Logged \$${amount.toStringAsFixed(2)} for $category'
            '${note.isNotEmpty ? ' ($note)' : ''}. '
            'You have \$${leftToSpend.toStringAsFixed(2)} left this month.';

      case CommandIntent.createBill:
        await addBill(Bill(
          id: _uuid.v4(),
          userId: uid,
          name: (p['name'] as String?) ?? 'Bill',
          amount: (p['amount'] as num).toDouble(),
          dueDay: (p['dueDay'] as int?) ?? 1,
        ));
        return 'Bill added: ${p['name']} — \$${(p['amount'] as num).toStringAsFixed(2)} due on the ${p['dueDay']}.';

      case CommandIntent.markBillPaid:
        final q = (p['query'] as String).toLowerCase();
        Bill? match;
        for (final b in bills) {
          if (b.name.toLowerCase().contains(q) ||
              q.contains(b.name.toLowerCase())) {
            match = b;
            break;
          }
        }
        if (match == null) return 'No bill found matching "$q".';
        await setBillPaid(match.id, true);
        return 'Marked ${match.name} as paid.';

      case CommandIntent.createSubscription:
        await addSubscription(Subscription(
          id: _uuid.v4(),
          userId: uid,
          name: (p['name'] as String?) ?? 'Subscription',
          amount: (p['amount'] as num).toDouble(),
          renewalDay: DateTime.now().day,
        ));
        return 'Subscription added: ${p['name']} at \$${(p['amount'] as num).toStringAsFixed(2)}/month.';

      case CommandIntent.addShoppingItems:
        final items = List<String>.from(p['items'] as List);
        for (final name in items) {
          await addShoppingItem(ShoppingItem(
            id: _uuid.v4(),
            userId: uid,
            name: name,
          ));
        }
        return items.length == 1
            ? 'Added ${items.first} to your shopping list.'
            : 'Added ${items.length} items to your shopping list: ${items.join(', ')}.';

      case CommandIntent.removeShoppingItem:
        final q = (p['query'] as String).toLowerCase();
        ShoppingItem? match;
        for (final s in shoppingItems) {
          if (s.name.toLowerCase().contains(q)) {
            match = s;
            break;
          }
        }
        if (match == null) return 'No shopping item matching "$q".';
        await deleteShoppingItem(match.id);
        return 'Removed ${match.name} from your shopping list.';

      case CommandIntent.setBudget:
        final amount = (p['amount'] as num).toDouble();
        if (profile != null) {
          await saveProfile(profile!.copyWith(monthlyBudget: amount));
        }
        return 'Monthly budget set to \$${amount.toStringAsFixed(2)}.';

      case CommandIntent.setIncome:
        final amount = (p['amount'] as num).toDouble();
        if (profile != null) {
          await saveProfile(profile!.copyWith(monthlyIncome: amount));
        }
        return 'Monthly income set to \$${amount.toStringAsFixed(2)}.';

      case CommandIntent.queryLeft:
        return 'You have \$${leftToSpend.toStringAsFixed(2)} left to spend '
            'this month (\$${spentThisMonth.toStringAsFixed(2)} spent of '
            '\$${(profile?.monthlyBudget ?? 0).toStringAsFixed(2)} budget).';

      case CommandIntent.queryTasks:
        if (openTasks.isEmpty) return 'You have no open tasks. Enjoy the calm.';
        final lines = openTasks
            .take(8)
            .map((t) => '- ${t.title}')
            .join('\n');
        return 'Your open tasks:\n$lines'
            '${openTasks.length > 8 ? '\n…and ${openTasks.length - 8} more.' : ''}';

      case CommandIntent.queryBills:
        if (unpaidBills.isEmpty) return 'All bills are paid. Well done.';
        final lines = unpaidBills
            .map((b) =>
                '- ${b.name}: \$${b.amount.toStringAsFixed(2)} (due ${b.dueDay})')
            .join('\n');
        return 'Unpaid bills:\n$lines';

      case CommandIntent.help:
        return 'Try me: "add task buy milk tomorrow 5pm", "I spent \$45 at '
            'Walmart", "remind me to pay rent on the 1st", "add eggs and '
            'bread to my shopping list", "how much do I have left?", or '
            '"done with grocery run".';

      case CommandIntent.unknown:
        return 'I did not quite get that. Try "help" to see what I understand.';
    }
  }

  TaskItem? _bestTaskMatch(String q, {bool includeDone = false}) {
    final pool =
        includeDone ? tasks : tasks.where((t) => !t.isDone).toList();
    for (final t in pool) {
      if (t.title.toLowerCase().contains(q)) return t;
    }
    for (final t in pool) {
      final words = q.split(' ');
      if (words.any((w) =>
          w.length > 3 && t.title.toLowerCase().contains(w))) {
        return t;
      }
    }
    return null;
  }

  String _fmtDateTime(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final dayStr = diff == 0
        ? 'today'
        : diff == 1
            ? 'tomorrow'
            : '${d.month}/${d.day}';
    var h = d.hour % 12;
    if (h == 0) h = 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dayStr at $h:$mm $ap';
  }
}
