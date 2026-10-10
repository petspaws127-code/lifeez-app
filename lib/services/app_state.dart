import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_client.dart';
import 'command_parser.dart';
import 'notification_service.dart';
import '../models/profile.dart';
import '../models/task_item.dart';
import '../models/expense.dart';
import '../models/bill.dart';
import '../models/subscription.dart';
import '../models/shopping_item.dart';
import '../models/reminder.dart';
import '../models/alarm.dart';
import '../models/document_item.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';
import '../models/family_member.dart';
import '../models/habit.dart';
import '../models/pet.dart';
import '../models/brain_dump.dart';
import '../models/savings_entry.dart';
import '../models/app_notification.dart';
import '../models/lent_borrowed.dart';
import 'eastern_time.dart';

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
  List<Alarm> alarms = [];
  List<DocumentItem> documents = [];
  List<Vehicle> vehicles = [];
  List<MaintenanceItem> maintenanceItems = [];
  List<FamilyMember> familyMembers = [];
  List<Habit> habits = [];
  List<PetProfile> pets = [];
  List<PetVaccination> vaccinations = [];
  List<PetMemory> petMemories = [];
  List<BrainDump> brainDumps = [];
  List<SavingsEntry> savingsEntries = [];
  List<LentBorrowed> lentBorrowed = [];

  bool loading = false;
  String? error;

  // PIN lock: unlocked for this session once verified.
  bool _pinUnlocked = false;

  // Notification center: generated feed + last-seen marker.
  List<AppNotification> notifications = [];
  DateTime? notificationsSeenAt;

  String? get _uid => SupabaseService.currentUserId;

  // ------------------------------------------------- local persistence
  // Root fix for data loss: every change auto-saves to the phone's
  // local storage (debounced), and loads back on startup. Works fully
  // offline — Supabase sync is best-effort on top of this.
  Timer? _saveTimer;
  /// User-scoped storage key - each user sees only their own data.
  static String get _localKey {
    final uid = SupabaseService.currentUserId;
    return 'lifeez_local_data_v1_${uid ?? "guest"}';
  }

  /// User-scoped pending-sync queue key. Survives restarts so offline
  /// writes are never lost — they flush when connectivity returns.
  static String get _pendingKey {
    final uid = SupabaseService.currentUserId;
    return 'lifeez_pending_sync_v1_${uid ?? "guest"}';
  }

  /// In-memory pending operations: {op: 'upsert'|'delete', table, id, row}
  List<Map<String, dynamic>> _pendingOps = [];
  bool _flushing = false;

  @override
  void notifyListeners() {
    // Debounced auto-save: any state change persists locally within 1s.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () => _saveLocal());
    super.notifyListeners();
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        'profile': profile?.toJson(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'bills': bills.map((e) => e.toJson()).toList(),
        'subscriptions': subscriptions.map((e) => e.toJson()).toList(),
        'shoppingItems': shoppingItems.map((e) => e.toJson()).toList(),
        'reminders': reminders.map((e) => e.toJson()).toList(),
        'alarms': alarms.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'vehicles': vehicles.map((e) => e.toJson()).toList(),
        'maintenanceItems':
            maintenanceItems.map((e) => e.toJson()).toList(),
        'familyMembers': familyMembers.map((e) => e.toJson()).toList(),
        'habits': habits.map((e) => e.toJson()).toList(),
        'pets': pets.map((e) => e.toJson()).toList(),
        'vaccinations': vaccinations.map((e) => e.toJson()).toList(),
        'petMemories': petMemories.map((e) => e.toJson()).toList(),
        'brainDumps': brainDumps.map((e) => e.toJson()).toList(),
        'savingsEntries':
            savingsEntries.map((e) => e.toJson()).toList(),
        'lentBorrowed': lentBorrowed.map((e) => e.toJson()).toList(),
      };
      await prefs.setString(_localKey, jsonEncode(data));
    } catch (_) {
      // Local save must never crash the app.
    }
  }

  /// Loads data from the phone's local storage. Returns true if found.
  Future<bool> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.isEmpty) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      List<Map<String, dynamic>> list(dynamic v) => v == null
          ? []
          : List<Map<String, dynamic>>.from(v as List);

      final p = data['profile'];
      profile = p == null
          ? null
          : Profile.fromJson(Map<String, dynamic>.from(p as Map));
      tasks = list(data['tasks']).map(TaskItem.fromJson).toList();
      expenses = list(data['expenses']).map(Expense.fromJson).toList();
      bills = list(data['bills']).map(Bill.fromJson).toList();
      subscriptions =
          list(data['subscriptions']).map(Subscription.fromJson).toList();
      shoppingItems = list(data['shoppingItems'])
          .map(ShoppingItem.fromJson)
          .toList();
      reminders =
          list(data['reminders']).map(Reminder.fromJson).toList();
      alarms = list(data['alarms']).map(Alarm.fromJson).toList();
      documents =
          list(data['documents']).map(DocumentItem.fromJson).toList();
      vehicles =
          list(data['vehicles']).map(Vehicle.fromJson).toList();
      maintenanceItems = list(data['maintenanceItems'])
          .map(MaintenanceItem.fromJson)
          .toList();
      familyMembers = list(data['familyMembers'])
          .map(FamilyMember.fromJson)
          .toList();
      habits = list(data['habits']).map(Habit.fromJson).toList();
      pets = list(data['pets']).map(PetProfile.fromJson).toList();
      vaccinations = list(data['vaccinations'])
          .map(PetVaccination.fromJson)
          .toList();
      petMemories =
          list(data['petMemories']).map(PetMemory.fromJson).toList();
      brainDumps =
          list(data['brainDumps']).map(BrainDump.fromJson).toList();
      savingsEntries = list(data['savingsEntries'])
          .map(SavingsEntry.fromJson)
          .toList();
      lentBorrowed =
          list(data['lentBorrowed']).map(LentBorrowed.fromJson).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------- loading
  Future<void> loadAll() async {
    loading = true;
    error = null;
    // Load local data first so the UI shows instantly, then refresh
    // from Supabase when available.
    await _loadLocal();
    // Load any pending offline writes from disk.
    await _loadPendingSync();
    notifyListeners();
    try {
      final uid = _uid;
      if (uid == null) {
        loading = false;
        notifyListeners();
        return;
      }
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
        c.from('habits').select().eq('user_id', uid),
        c.from('pet_profiles').select().eq('user_id', uid),
        c.from('pet_vaccinations').select().eq('user_id', uid),
        c.from('pet_memories').select().eq('user_id', uid),
        c.from('brain_dumps').select().eq('user_id', uid).order('created_at'),
        c.from('savings_entries')
            .select()
            .eq('user_id', uid)
            .order('saved_at'),
        c.from('lent_borrowed')
            .select()
            .eq('user_id', uid)
            .order('date', ascending: false),
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
      habits = list(results[11]).map(Habit.fromJson).toList();
      pets = list(results[12]).map(PetProfile.fromJson).toList();
      vaccinations =
          list(results[13]).map(PetVaccination.fromJson).toList();
      petMemories =
          list(results[14]).map(PetMemory.fromJson).toList();
      brainDumps =
          list(results[15]).map(BrainDump.fromJson).toList();
      savingsEntries =
          list(results[16]).map(SavingsEntry.fromJson).toList();
      lentBorrowed =
          list(results[17]).map(LentBorrowed.fromJson).toList();
      _pinUnlocked = false;
      refreshNotifications();
      // We're online (cloud fetch succeeded): flush any pending
      // offline writes now.
      await _flushPendingSync();
    } catch (e) {
      error = 'Could not load your data: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Best-effort flush before sign-out so pending offline writes
  /// reach the cloud before local data is wiped.
  Future<void> flushBeforeSignOut() async {
    await _flushPendingSync();
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
    habits = [];
    pets = [];
    vaccinations = [];
    petMemories = [];
    brainDumps = [];
    savingsEntries = [];
    lentBorrowed = [];
    notifications = [];
    notificationsSeenAt = null;
    _pinUnlocked = false;
    // Also wipe the persisted local copy so a deleted account
    // doesn't reload old data.
    SharedPreferences.getInstance()
        .then((p) => p.remove(_localKey));
    notifyListeners();
  }

  Future<void> _save(String table, Map<String, dynamic> row) async {
    try {
      await SupabaseService.client.from(table).upsert(row);
      // Opportunistic flush: a successful write means we're online,
      // so drain any queued ops too.
      _flushPendingSync();
    } catch (e) {
      // Offline or transient failure: queue for later retry instead
      // of silently dropping the write.
      _queueOp('upsert', table, row['id']?.toString() ?? '', row);
      error = 'Sync queued ($table): will retry when online';
    }
  }

  Future<void> _delete(String table, String id) async {
    try {
      await SupabaseService.client.from(table).delete().eq('id', id);
      _flushPendingSync();
    } catch (e) {
      _queueOp('delete', table, id, null);
      error = 'Sync queued ($table): will retry when online';
    }
  }

  /// Add an operation to the persistent pending-sync queue.
  Future<void> _queueOp(
      String op, String table, String id, Map<String, dynamic>? row) async {
    // Replace any existing pending op for the same table+id (last wins).
    _pendingOps.removeWhere((p) => p['table'] == table && p['id'] == id);
    _pendingOps.add({
      'op': op,
      'table': table,
      'id': id,
      if (row != null) 'row': row,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _pendingOps
          .map((p) => jsonEncode(p))
          .toList();
      await prefs.setStringList(_pendingKey, encoded);
    } catch (_) {}
    notifyListeners();
  }

  /// Load the pending queue from disk (called on startup).
  Future<void> _loadPendingSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_pendingKey) ?? [];
      _pendingOps = encoded
          .map((s) {
            try {
              return Map<String, dynamic>.from(jsonDecode(s));
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((p) => p.isNotEmpty && p['table'] != null)
          .toList();
    } catch (_) {
      _pendingOps = [];
    }
  }

  /// Retry all queued operations. Called on startup, after loadAll,
  /// and opportunistically after any successful cloud write.
  Future<void> _flushPendingSync() async {
    if (_flushing || _pendingOps.isEmpty) return;
    _flushing = true;
    try {
      final remaining = <Map<String, dynamic>>[];
      for (final p in List<Map<String, dynamic>>.from(_pendingOps)) {
        try {
          final table = p['table'] as String;
          if (p['op'] == 'delete') {
            await SupabaseService.client
                .from(table)
                .delete()
                .eq('id', p['id']);
          } else {
            final row = Map<String, dynamic>.from(p['row'] as Map);
            await SupabaseService.client.from(table).upsert(row);
          }
          // Success: don't re-add to remaining.
        } catch (_) {
          remaining.add(p);
        }
      }
      _pendingOps = remaining;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
            _pendingKey, remaining.map((p) => jsonEncode(p)).toList());
      } catch (_) {}
      if (remaining.isEmpty) {
        error = null;
      } else {
        error = '${remaining.length} change(s) waiting to sync';
      }
    } finally {
      _flushing = false;
    }
    notifyListeners();
  }

  /// Number of pending sync operations (for UI badge if needed).
  int get pendingSyncCount => _pendingOps.length;

  // ------------------------------------------------------------- profile
  Future<void> saveProfile(Profile p) async {
    profile = p;
    notifyListeners();
    await _save('profiles', p.toJson());
    notifyListeners();
  }

  /// Resolves the stored theme preference to a [ThemeMode].
  ThemeMode get themeMode => switch (profile?.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(String mode) async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(themeMode: mode));
  }

  Future<void> setNotificationsEnabled(bool v) async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(notificationsEnabled: v));
  }

  Future<void> setDailyBriefingEnabled(bool v) async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(dailyBriefingEnabled: v));
  }

  Future<void> setCurrency(String currency) async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(currency: currency));
  }

  /// Generates a referral code once, the first time it is needed.
  Future<void> ensureReferralCode() async {
    if (profile == null || profile!.referralCode.isNotEmpty) return;
    final rand = math.Random();
    final code = 'LZ${100000 + rand.nextInt(900000)}';
    await saveProfile(profile!.copyWith(referralCode: code));
  }

  /// Mock hook for a successful referral: every 3 real referrals earn
  /// 30 Pro days, credited by extending the trial window.
  Future<void> recordReferral() async {
    if (profile == null) return;
    final count = profile!.referralCount + 1;
    var earned = profile!.proDaysEarned;
    DateTime? trial = profile!.trialEndsAt;
    if (count % 3 == 0) {
      earned += 30;
      final base = (trial != null && trial.isAfter(easternNow()))
          ? trial
          : easternNow();
      trial = base.add(const Duration(days: 30));
    }
    await saveProfile(profile!.copyWith(
      referralCount: count,
      proDaysEarned: earned,
      trialEndsAt: trial,
    ));
  }

  /// Go Pro popup throttle: at most 5 shows per day, and never for
  /// users who already have Pro. Returns true when the popup may show.
  Future<bool> consumeGoProPopupSlot() async {
    if (profile == null || profile!.isPro) return false;
    final today =
        '${easternNow().year}-${easternNow().month.toString().padLeft(2, '0')}-${easternNow().day.toString().padLeft(2, '0')}';
    final sameDay = profile!.goProPopupDate == today;
    final count = sameDay ? profile!.goProPopupCount : 0;
    if (count >= 5) return false;
    await saveProfile(profile!.copyWith(
      goProPopupDate: today,
      goProPopupCount: count + 1,
    ));
    return true;
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
    if (tasks[i].isDone) {
      final title = tasks[i].title.length > 60
          ? '${tasks[i].title.substring(0, 57)}...'
          : tasks[i].title;
      await NotificationService.instance.showNow(
        id: NotificationService.idFor('task_done_$id'),
        title: 'Task completed',
        body: '"$title" is done. Nice work!',
      );
    }
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

  Future<void> updateExpense(Expense e) async {
    final i = expenses.indexWhere((x) => x.id == e.id);
    if (i != -1) expenses[i] = e;
    notifyListeners();
    await _save('expenses', e.toJson());
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
    await _scheduleReminder(r);
  }

  /// Schedules a system notification for [r] when it has a future
  /// remindAt and is not already done.
  Future<void> _scheduleReminder(Reminder r) async {
    if (r.isDone) return;
    if (!r.remindAt.isAfter(DateTime.now())) return;
    await NotificationService.instance.schedule(
      id: NotificationService.idFor('reminder_${r.id}'),
      title: 'Reminder',
      body: r.title,
      when: r.remindAt,
    );
  }

  Future<void> toggleReminder(String id) async {
    final i = reminders.indexWhere((e) => e.id == id);
    if (i == -1) return;
    reminders[i] = reminders[i].copyWith(isDone: !reminders[i].isDone);
    notifyListeners();
    await _save('reminders', reminders[i].toJson());
    if (reminders[i].isDone) {
      await NotificationService.instance.cancel(
        NotificationService.idFor('reminder_$id'),
      );
      await NotificationService.instance.showNow(
        id: NotificationService.idFor('reminder_done_$id'),
        title: 'Reminder completed',
        body: reminders[i].title,
      );
    }
  }

  Future<void> deleteReminder(String id) async {
    reminders.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('reminders', id);
    await NotificationService.instance.cancel(
      NotificationService.idFor('reminder_$id'),
    );
  }

  // --------------------------------------------------------------- alarms
  /// Alarms are device-local (system notifications), stored locally only.
  Future<void> addAlarm(Alarm a) async {
    alarms.add(a);
    notifyListeners();
    await _saveLocal();
    await _scheduleAlarm(a);
  }

  Future<void> _scheduleAlarm(Alarm a) async {
    if (!a.enabled) return;
    await NotificationService.instance.schedule(
      id: NotificationService.idFor('alarm_${a.id}'),
      title: 'Alarm',
      body: a.label,
      when: a.nextFire(),
    );
  }

  Future<void> toggleAlarm(String id) async {
    final i = alarms.indexWhere((e) => e.id == id);
    if (i == -1) return;
    alarms[i] = alarms[i].copyWith(enabled: !alarms[i].enabled);
    notifyListeners();
    await _saveLocal();
    if (alarms[i].enabled) {
      await _scheduleAlarm(alarms[i]);
    } else {
      await NotificationService.instance.cancel(
        NotificationService.idFor('alarm_$id'),
      );
    }
  }

  Future<void> deleteAlarm(String id) async {
    alarms.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveLocal();
    await NotificationService.instance.cancel(
      NotificationService.idFor('alarm_$id'),
    );
  }

  /// Re-schedule all enabled alarms (call on app start).
  Future<void> rescheduleAlarms() async {
    for (final a in alarms) {
      await _scheduleAlarm(a);
    }
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

  // -------------------------------------------------------------- habits
  Future<void> addHabit(Habit h) async {
    habits.add(h);
    notifyListeners();
    await _save('habits', h.toJson());
  }

  Future<void> toggleHabitToday(String id) async {
    final i = habits.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final today = Habit.dayKey(easternNow());
    final checkins = List<String>.from(habits[i].checkins);
    if (checkins.contains(today)) {
      checkins.remove(today);
    } else {
      checkins.add(today);
    }
    habits[i] = habits[i].copyWith(checkins: checkins);
    notifyListeners();
    await _save('habits', habits[i].toJson());
  }

  Future<void> deleteHabit(String id) async {
    habits.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('habits', id);
  }

  int get habitsDoneToday =>
      habits.where((h) => h.isDoneToday).length;

  // ----------------------------------------------------------------- pets
  Future<void> addPet(PetProfile p) async {
    pets.add(p);
    notifyListeners();
    await _save('pet_profiles', p.toJson());
  }

  Future<void> updatePet(PetProfile p) async {
    final i = pets.indexWhere((e) => e.id == p.id);
    if (i != -1) pets[i] = p;
    notifyListeners();
    await _save('pet_profiles', p.toJson());
  }

  Future<void> deletePet(String id) async {
    pets.removeWhere((e) => e.id == id);
    vaccinations.removeWhere((v) => v.petId == id);
    petMemories.removeWhere((m) => m.petId == id);
    // Cancel scheduled notifications for this pet's reminders before removal.
    for (final r in reminders.where((r) => r.petId == id)) {
      await NotificationService.instance
          .cancel(NotificationService.idFor('reminder_${r.id}'));
    }
    reminders.removeWhere((r) => r.petId == id);
    notifyListeners();
    await _delete('pet_profiles', id);
  }

  String petName(String petId) {
    final i = pets.indexWhere((p) => p.id == petId);
    return i == -1 ? 'Pet' : pets[i].name;
  }

  List<Reminder> petRemindersFor(String petId) => reminders
      .where((r) => r.petId == petId && !r.isDone)
      .toList();

  List<Reminder> get allPetReminders =>
      reminders.where((r) => r.petId != null && !r.isDone).toList();

  Future<void> addPetReminder(Reminder r) async {
    reminders.add(r);
    notifyListeners();
    await _save('reminders', r.toJson());
    await _scheduleReminder(r);
    refreshNotifications();
  }

  Future<void> addVaccination(PetVaccination v) async {
    vaccinations.add(v);
    notifyListeners();
    await _save('pet_vaccinations', v.toJson());
    refreshNotifications();
  }

  Future<void> deleteVaccination(String id) async {
    vaccinations.removeWhere((v) => v.id == id);
    notifyListeners();
    await _delete('pet_vaccinations', id);
  }

  List<PetVaccination> vaccinationsFor(String petId) =>
      vaccinations.where((v) => v.petId == petId).toList();

  Future<void> addPetMemory(PetMemory m) async {
    petMemories.add(m);
    notifyListeners();
    await _save('pet_memories', m.toJson());
  }

  Future<void> deletePetMemory(String id) async {
    petMemories.removeWhere((m) => m.id == id);
    notifyListeners();
    await _delete('pet_memories', id);
  }

  List<PetMemory> memoriesFor(String petId) =>
      petMemories.where((m) => m.petId == petId).toList();

  // ----------------------------------------------------------- brain dump
  Future<void> addBrainDump(BrainDump b) async {
    brainDumps.insert(0, b);
    notifyListeners();
    await _save('brain_dumps', b.toJson());
  }

  Future<void> toggleBrainDump(String id) async {
    final i = brainDumps.indexWhere((e) => e.id == id);
    if (i == -1) return;
    brainDumps[i] =
        brainDumps[i].copyWith(isDone: !brainDumps[i].isDone);
    notifyListeners();
    await _save('brain_dumps', brainDumps[i].toJson());
  }

  Future<void> deleteBrainDump(String id) async {
    brainDumps.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('brain_dumps', id);
  }

  List<BrainDump> get openBrainDumps =>
      brainDumps.where((b) => !b.isDone).toList();

  // -------------------------------------------------------------- savings
  Future<void> addSavingsEntry(SavingsEntry s) async {
    savingsEntries.add(s);
    notifyListeners();
    await _save('savings_entries', s.toJson());
  }

  Future<void> deleteSavingsEntry(String id) async {
    savingsEntries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('savings_entries', id);
  }

  Future<void> setSavingsGoal(double goal) async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(savingsGoal: goal));
  }

  // -------------------------------------------------------- lent & borrowed
  Future<void> addLentBorrowed(LentBorrowed e) async {
    lentBorrowed.insert(0, e);
    notifyListeners();
    await _save('lent_borrowed', e.toJson());
    refreshNotifications();
  }

  Future<void> updateLentBorrowed(LentBorrowed e) async {
    final i = lentBorrowed.indexWhere((x) => x.id == e.id);
    if (i != -1) lentBorrowed[i] = e;
    notifyListeners();
    await _save('lent_borrowed', e.toJson());
    refreshNotifications();
  }

  Future<void> deleteLentBorrowed(String id) async {
    lentBorrowed.removeWhere((e) => e.id == id);
    notifyListeners();
    await _delete('lent_borrowed', id);
    refreshNotifications();
  }

  Future<void> toggleLentBorrowedSettled(String id) async {
    final i = lentBorrowed.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final e = lentBorrowed[i];
    await updateLentBorrowed(e.copyWith(settled: !e.settled));
  }

  /// Net balance: positive = others owe me, negative = I owe others.
  double get lentBorrowedNet => lentBorrowed
      .where((e) => !e.settled && e.amount != null)
      .fold(0.0,
          (sum, e) => sum + (e.direction == 'lent' ? e.amount! : -e.amount!));

  double get savedThisMonth {
    final now = easternNow();
    return savingsEntries
        .where((s) =>
            s.savedAt.year == now.year &&
            s.savedAt.month == now.month)
        .fold(0.0, (sum, s) => sum + s.amount);
  }

  double get savingsGoalPct {
    final g = profile?.savingsGoal ?? 0;
    if (g <= 0) return 0;
    return (savedThisMonth / g).clamp(0.0, 1.0);
  }

  // --------------------------------------------------------------- family
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

  // ------------------------------------------------------------ PIN lock
  /// Simple (non-cryptographic) PIN hash for the local lock screen.
  static String hashPin(String pin) {
    var h = 0;
    const salted = 'lifeez::';
    for (final c in (salted + pin).codeUnits) {
      h = ((h * 31) + c) & 0x7fffffff;
    }
    return h.toRadixString(16);
  }

  bool get hasPin =>
      profile?.pinHash != null && profile!.pinHash!.isNotEmpty;

  bool get isLocked => hasPin && !_pinUnlocked;

  bool verifyPin(String pin) {
    final ok = hasPin && hashPin(pin) == profile!.pinHash;
    if (ok) {
      _pinUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  /// Unlock the app without a PIN (e.g. after successful biometric auth).
  void unlock() {
    _pinUnlocked = true;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    if (profile == null) return;
    _pinUnlocked = true;
    await saveProfile(profile!.copyWith(pinHash: hashPin(pin)));
  }

  Future<void> removePin() async {
    if (profile == null) return;
    _pinUnlocked = true;
    await saveProfile(profile!.copyWith(clearPin: true));
  }

  // -------------------------------------------------------- Pro & trial
  /// Starts the 14-day Pro trial (mock — no real charge).
  Future<void> startProTrial() async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(
      trialEndsAt: easternNow().add(const Duration(days: 14)),
      plan: 'pro',
    ));
    refreshNotifications();
  }

  /// Mock purchase: monthly $4.99 or yearly $39 (test mode, no charge).
  Future<void> purchasePro(String plan) async {
    if (profile == null) return;
    final days = plan == 'yearly' ? 360 : 30;
    await saveProfile(profile!.copyWith(
      proPlan: plan,
      proRenewsAt: easternNow().add(Duration(days: days)),
      plan: 'pro',
      trialEndsAt: null,
    ));
    refreshNotifications();
  }

  Future<void> cancelPro() async {
    if (profile == null) return;
    await saveProfile(profile!.copyWith(
      plan: 'free',
      proPlan: 'none',
    ));
  }

  int? get trialDaysLeft {
    final t = profile?.trialEndsAt;
    if (t == null) return null;
    final d = t.difference(easternNow()).inDays;
    return d < 0 ? 0 : d;
  }

  // ---------------------------------------------------- notification feed
  int get unreadCount {
    if (notificationsSeenAt == null) return notifications.length;
    return notifications
        .where((n) => n.createdAt.isAfter(notificationsSeenAt!))
        .length;
  }

  void markNotificationsSeen() {
    notificationsSeenAt = easternNow();
    notifyListeners();
  }

  /// Rebuilds the notification feed from current data.
  void refreshNotifications() {
    final now = easternNow();
    final feed = <AppNotification>[];
    if (!(profile?.notificationsEnabled ?? true)) {
      notifications = feed;
      notifyListeners();
      return;
    }

    for (final b in unpaidBills) {
      feed.add(AppNotification(
        id: 'bill-${b.id}',
        title: 'Bill due soon',
        body:
            '${b.name} — \$${b.amount.toStringAsFixed(2)} due on the ${b.dueDay}.',
        icon: Icons.receipt_long_rounded,
        createdAt: now,
        route: '/bills',
      ));
    }
    for (final t in todayTasks.take(3)) {
      feed.add(AppNotification(
        id: 'task-${t.id}',
        title: 'Due today',
        body: t.title,
        icon: Icons.check_circle_outline_rounded,
        createdAt: now,
        route: '/tasks',
      ));
    }
    // Nagging reminders: overdue tasks keep nagging until done.
    final todayDate =
        DateTime(now.year, now.month, now.day);
    for (final t in tasks.where((t) =>
        !t.isDone &&
        t.dueDate != null &&
        DateTime(t.dueDate!.year, t.dueDate!.month,
                t.dueDate!.day)
            .isBefore(todayDate))) {
      final days = todayDate
          .difference(DateTime(
              t.dueDate!.year, t.dueDate!.month, t.dueDate!.day))
          .inDays;
      feed.add(AppNotification(
        id: 'nag-${t.id}',
        title: days <= 1
            ? 'Still not done?'
            : 'Overdue by $days day${days == 1 ? '' : 's'}',
        body: '“${t.title}” is still waiting. Tap to finish it.',
        icon: Icons.notification_important_rounded,
        createdAt: now,
        route: '/tasks',
      ));
    }
    for (final r in activeReminders.take(3)) {
      final petLabel =
          r.petId != null ? ' for ${petName(r.petId!)}' : '';
      feed.add(AppNotification(
        id: 'rem-${r.id}',
        title: 'Reminder$petLabel',
        body: r.title,
        icon: Icons.alarm_rounded,
        createdAt: now,
        route: '/reminders',
      ));
    }
    // Lent & borrowed: overdue / due soon.
    for (final e in lentBorrowed.where((e) => !e.settled)) {
      if (e.dueDate == null) continue;
      final due = DateTime(
          e.dueDate!.year, e.dueDate!.month, e.dueDate!.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = due.difference(today).inDays;
      if (diff < 0 || diff <= 3) {
        feed.add(AppNotification(
          id: 'lb-${e.id}',
          title: diff < 0
              ? 'Overdue: ${e.direction == 'lent' ? 'collect' : 'return'}'
              : '${e.direction == 'lent' ? 'Collect' : 'Return'} soon',
          body:
              '${e.item} — ${e.person}${diff < 0 ? ' was due ${-diff} day${-diff == 1 ? '' : 's'} ago' : diff == 0 ? ' is due today' : ' is due in $diff days'}.',
          icon: Icons.handshake_outlined,
          createdAt: now,
          route: '/lent-borrowed',
        ));
      }
    }
    for (final v in vaccinations) {
      if (v.isOverdue || v.isDueSoon) {
        feed.add(AppNotification(
          id: 'vax-${v.id}',
          title: v.isOverdue
              ? 'Vaccination overdue'
              : 'Vaccination due soon',
          body:
              '${v.vaccineName} for ${petName(v.petId)}${v.nextDueDate != null ? ' — due ${v.nextDueDate!.month}/${v.nextDueDate!.day}/${v.nextDueDate!.year}' : ''}.',
          icon: Icons.medical_services_outlined,
          createdAt: now,
          route: '/pets',
        ));
      }
    }
    final trialLeft = trialDaysLeft;
    if (trialLeft != null && trialLeft <= 3) {
      feed.add(AppNotification(
        id: 'trial-ending',
        title: 'Pro trial ending',
        body: trialLeft == 0
            ? 'Your Pro trial ends today.'
            : '$trialLeft day${trialLeft == 1 ? '' : 's'} left in your Pro trial.',
        icon: Icons.star_outline_rounded,
        createdAt: now,
        route: '/pro',
      ));
    }
    notifications = feed;
    notifyListeners();
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
      'habits',
      'pet_profiles',
      'pet_vaccinations',
      'pet_memories',
      'brain_dumps',
      'savings_entries',
      'lent_borrowed',
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
    final now = easternNow();
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
    final now = easternNow();
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
    final now = easternNow();
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
    final now = easternNow();
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
        // If the user didn't say a time, show date only ("due tomorrow"),
        // never a made-up default time.
        final hasTime = p['hasTime'] as bool? ?? true;
        unawaited(addTask(TaskItem(
          id: _uuid.v4(),
          userId: uid,
          title: (p['title'] as String?) ?? 'Untitled task',
          dueDate: due,
          category: (p['category'] as String?) ?? 'general',
          repeat: p['repeat'] as String?,
          source: 'whatsapp',
          createdAt: easternNow(),
        )));
        if (due == null) return 'Task added: ${p['title']}.';
        final dueStr = hasTime ? _fmtDateTime(due) : _fmtDate(due);
        return 'Task added: ${p['title']} (due $dueStr).';

      case CommandIntent.completeTask:
        final q = (p['query'] as String).toLowerCase();
        final match = _bestTaskMatch(q);
        if (match == null) {
          return 'I could not find an open task matching "$q".';
        }
        unawaited(toggleTask(match.id));
        return 'Marked done: ${match.title}. Nice work.';

      case CommandIntent.deleteTask:
        final q = (p['query'] as String).toLowerCase();
        final match = _bestTaskMatch(q, includeDone: true);
        if (match == null) return 'No task found matching "$q".';
        unawaited(deleteTask(match.id));
        return 'Deleted task: ${match.title}.';

      case CommandIntent.createReminder:
        final at = p['remindAt'] != null
            ? DateTime.tryParse(p['remindAt'] as String)
            : null;
        unawaited(addReminder(Reminder(
          id: _uuid.v4(),
          userId: uid,
          title: (p['title'] as String?) ?? 'Reminder',
          remindAt: at ?? easternNow().add(const Duration(hours: 1)),
          repeat: p['repeat'] as String?,
        )));
        return at == null
            ? 'Reminder set: ${p['title']}.'
            : 'Reminder set: ${p['title']} — ${_fmtDateTime(at)}.';

      case CommandIntent.createAlarm:
        final alarm = Alarm(
          label: (p['label'] as String?) ?? 'Alarm',
          hour: (p['hour'] as int?) ?? 8,
          minute: (p['minute'] as int?) ?? 0,
          repeatDays: List<int>.from(p['repeatDays'] as List? ?? []),
        );
        unawaited(addAlarm(alarm));
        final repeatStr = alarm.repeatDays.length == 7
            ? 'daily'
            : alarm.repeatLabel;
        return 'Done! Alarm set for ${alarm.timeLabel}'
            '${repeatStr == 'Once' ? '' : ' ($repeatStr)'}.';

      case CommandIntent.createHabit:
        final habitTitle = (p['title'] as String?) ?? 'Habit';
        unawaited(addTask(TaskItem(
          id: _uuid.v4(),
          userId: uid,
          title: 'Habit: $habitTitle',
          category: 'habit',
          repeat: 'daily',
          source: 'ai',
          createdAt: easternNow(),
        )));
        return 'Done! Tracking "$habitTitle" daily.';

      case CommandIntent.createExpense:
        final amount = (p['amount'] as num).toDouble();
        final category = (p['category'] as String?) ?? 'Other';
        final note = (p['note'] as String?) ?? '';
        unawaited(addExpense(Expense(
          id: _uuid.v4(),
          userId: uid,
          amount: amount,
          category: category,
          note: note,
          spentAt: easternNow(),
          source: 'whatsapp',
        )));
        return 'Logged \$${amount.toStringAsFixed(2)} for $category'
            '${note.isNotEmpty ? ' ($note)' : ''}. '
            'You have \$${leftToSpend.toStringAsFixed(2)} left this month.';

      case CommandIntent.createBill:
        unawaited(addBill(Bill(
          id: _uuid.v4(),
          userId: uid,
          name: (p['name'] as String?) ?? 'Bill',
          amount: (p['amount'] as num).toDouble(),
          dueDay: (p['dueDay'] as int?) ?? 1,
        )));
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
        unawaited(setBillPaid(match.id, true));
        return 'Marked ${match.name} as paid.';

      case CommandIntent.createSubscription:
        unawaited(addSubscription(Subscription(
          id: _uuid.v4(),
          userId: uid,
          name: (p['name'] as String?) ?? 'Subscription',
          amount: (p['amount'] as num).toDouble(),
          renewalDay: easternNow().day,
        )));
        return 'Subscription added: ${p['name']} at \$${(p['amount'] as num).toStringAsFixed(2)}/month.';

      case CommandIntent.addShoppingItems:
        final items = List<String>.from(p['items'] as List);
        for (final name in items) {
          unawaited(addShoppingItem(ShoppingItem(
            id: _uuid.v4(),
            userId: uid,
            name: name,
          )));
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
        unawaited(deleteShoppingItem(match.id));
        return 'Removed ${match.name} from your shopping list.';

      case CommandIntent.setBudget:
        final amount = (p['amount'] as num).toDouble();
        if (profile != null) {
          unawaited(saveProfile(profile!.copyWith(monthlyBudget: amount)));
        }
        return 'Monthly budget set to \$${amount.toStringAsFixed(2)}.';

      case CommandIntent.setIncome:
        final amount = (p['amount'] as num).toDouble();
        if (profile != null) {
          unawaited(saveProfile(profile!.copyWith(monthlyIncome: amount)));
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
        // This should rarely trigger now (engine tries Gemini first),
        // but never sound robotic if it does.
        return 'I want to get that right. Tell me a bit more — '
            'for example "remind me to call mom tomorrow 6pm" '
            'or "add task buy milk".';
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

  /// Date only, no time — for tasks where the user didn't specify a time.
  String _fmtDate(DateTime d) {
    final now = easternNow();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return '${d.month}/${d.day}/${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    final now = easternNow();
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
