import 'package:uuid/uuid.dart';
import '../services/eastern_time.dart';

const _uuid = Uuid();

/// Type of trip — drives budget multipliers and itinerary tone.
enum TripType { solo, friends, family }

/// Day part for itinerary slots.
enum SlotType { morning, afternoon, evening }

/// Packing checklist categories.
enum PackingCategory { clothing, electronics, documents, essentials }

/// Expense breakdown categories.
enum ExpenseCategory { stay, food, sightseeing, transport }

TripType tripTypeFromString(String? s) {
  switch (s) {
    case 'friends':
      return TripType.friends;
    case 'family':
      return TripType.family;
    case 'solo':
    default:
      return TripType.solo;
  }
}

SlotType slotTypeFromString(String? s) {
  switch (s) {
    case 'afternoon':
      return SlotType.afternoon;
    case 'evening':
      return SlotType.evening;
    case 'morning':
    default:
      return SlotType.morning;
  }
}

PackingCategory packingCategoryFromString(String? s) {
  switch (s) {
    case 'electronics':
      return PackingCategory.electronics;
    case 'documents':
      return PackingCategory.documents;
    case 'essentials':
      return PackingCategory.essentials;
    case 'clothing':
    default:
      return PackingCategory.clothing;
  }
}

ExpenseCategory expenseCategoryFromString(String? s) {
  switch (s) {
    case 'food':
      return ExpenseCategory.food;
    case 'sightseeing':
      return ExpenseCategory.sightseeing;
    case 'transport':
      return ExpenseCategory.transport;
    case 'stay':
    default:
      return ExpenseCategory.stay;
  }
}

/// A planned trip (table: trips).
class Trip {
  final String id;
  final String userId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final TripType tripType;
  final double estimatedBudget; // USD
  final String? weatherSummary; // e.g. "72°F, Clear skies"
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.userId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.tripType = TripType.solo,
    this.estimatedBudget = 0,
    this.weatherSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Number of trip days, inclusive of both start and end.
  int get dayCount {
    final d = endDate.difference(startDate).inDays + 1;
    return d < 1 ? 1 : d;
  }

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: (json['id'] as String?) ?? _uuid.v4(),
        userId: (json['user_id'] as String?) ?? '',
        destination: (json['destination'] as String?) ?? '',
        startDate: DateTime.tryParse((json['start_date'] as String?) ?? '') ??
            easternNow(),
        endDate: DateTime.tryParse((json['end_date'] as String?) ?? '') ??
            easternNow(),
        tripType: tripTypeFromString(json['trip_type'] as String?),
        estimatedBudget:
            ((json['estimated_budget'] as num?) ?? 0).toDouble(),
        weatherSummary: json['weather_summary'] as String?,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            easternNow(),
        updatedAt: DateTime.tryParse((json['updated_at'] as String?) ?? '') ??
            easternNow(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'destination': destination,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'trip_type': tripType.name,
        'estimated_budget': estimatedBudget,
        'weather_summary': weatherSummary,
      };
}

/// One day of the itinerary (table: trip_itinerary_days).
class ItineraryDay {
  final String id;
  final String tripId;
  final int dayNumber; // 1..N
  final DateTime date;
  final List<ActivitySlot> slots; // morning / afternoon / evening

  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.slots = const [],
  });

  ActivitySlot slotOf(SlotType type) => slots.firstWhere(
        (s) => s.slot == type,
        orElse: () => ActivitySlot(
          id: _uuid.v4(),
          itineraryDayId: id,
          slot: type,
          title: 'Free time',
          description: 'Explore at your own pace.',
        ),
      );
}

/// A single morning/afternoon/evening activity (table: trip_activities).
class ActivitySlot {
  final String id;
  final String itineraryDayId;
  final SlotType slot;
  final String title;
  final String description;
  final String spot;
  final String travelTip;
  final String? startTime; // "HH:MM" local — used by Sync to Reminders

  const ActivitySlot({
    required this.id,
    required this.itineraryDayId,
    required this.slot,
    required this.title,
    this.description = '',
    this.spot = '',
    this.travelTip = '',
    this.startTime,
  });

  factory ActivitySlot.fromJson(
      Map<String, dynamic> json, String itineraryDayId) {
    return ActivitySlot(
      id: (json['id'] as String?) ?? _uuid.v4(),
      itineraryDayId: itineraryDayId,
      slot: slotTypeFromString(json['slot'] as String?),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      spot: (json['spot'] as String?) ?? '',
      travelTip: (json['travel_tip'] as String?) ??
          (json['travelTip'] as String?) ??
          '',
      startTime: json['start_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'itinerary_day_id': itineraryDayId,
        'slot': slot.name,
        'title': title,
        'description': description,
        'spot': spot,
        'travel_tip': travelTip,
        'start_time': startTime,
      };
}

/// One packing checklist row (table: trip_packing_items).
class PackingItem {
  final String id;
  final String tripId;
  final PackingCategory category;
  final String label;
  final bool isPacked;

  const PackingItem({
    required this.id,
    required this.tripId,
    required this.category,
    required this.label,
    this.isPacked = false,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json, String tripId) {
    return PackingItem(
      id: (json['id'] as String?) ?? _uuid.v4(),
      tripId: tripId,
      category: packingCategoryFromString(json['category'] as String?),
      label: (json['label'] as String?) ?? '',
      isPacked: (json['is_packed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'category': category.name,
        'label': label,
        'is_packed': isPacked,
      };

  PackingItem copyWith({bool? isPacked}) => PackingItem(
        id: id,
        tripId: tripId,
        category: category,
        label: label,
        isPacked: isPacked ?? this.isPacked,
      );
}

/// One expense row (table: trip_expenses).
class ExpenseBreakdown {
  final String id;
  final String tripId;
  final ExpenseCategory category;
  final double amountUsd;
  final String? note;

  const ExpenseBreakdown({
    required this.id,
    required this.tripId,
    required this.category,
    this.amountUsd = 0,
    this.note,
  });

  factory ExpenseBreakdown.fromJson(
      Map<String, dynamic> json, String tripId) {
    return ExpenseBreakdown(
      id: (json['id'] as String?) ?? _uuid.v4(),
      tripId: tripId,
      category: expenseCategoryFromString(json['category'] as String?),
      amountUsd: ((json['amount_usd'] as num?) ??
              (json['amountUsd'] as num?) ??
              0)
          .toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'category': category.name,
        'amount_usd': amountUsd,
        'note': note,
      };
}

/// A fully generated trip plan: the trip + all of its AI output.
class GeneratedTripPlan {
  final Trip trip;
  final List<ItineraryDay> days;
  final List<PackingItem> packing;
  final List<ExpenseBreakdown> expenses;

  const GeneratedTripPlan({
    required this.trip,
    required this.days,
    required this.packing,
    required this.expenses,
  });

  double get totalExpenses =>
      expenses.fold(0.0, (sum, e) => sum + e.amountUsd);
}
