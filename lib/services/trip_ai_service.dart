import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/trip_models.dart';
import 'eastern_time.dart';
import 'gemini_service.dart';
import 'supabase_client.dart';

const _uuid = Uuid();

/// Weather snapshot from OpenWeatherMap, used for weather-aware packing.
class WeatherInfo {
  final String summary; // e.g. "72°F, Clear skies"
  final double avgTempF;
  final String condition;

  const WeatherInfo({
    required this.summary,
    required this.avgTempF,
    required this.condition,
  });

  /// cold < 50°F, mild 50–72°F, warm > 72°F
  String get tempBand =>
      avgTempF < 50 ? 'cold' : (avgTempF <= 72 ? 'mild' : 'warm');
}

/// AI trip planning: [Smart Input] -> [AI Processing] -> [Automated Output].
///
/// - Weather comes from OpenWeatherMap (key injected via
///   --dart-define=OWM_API_KEY, stored as a GitHub Actions secret).
/// - Itinerary / packing / budget come from Gemini (gemini-3.8-flash)
///   with a strict-JSON prompt, parsed defensively.
/// - Any AI or weather failure falls back to a real local template
///   generator — the user never sees an error screen.
class TripAiService {
  static const _owmKey =
      String.fromEnvironment('OWM_API_KEY', defaultValue: '');

  static bool get weatherConfigured => _owmKey.isNotEmpty;

  // ------------------------------------------------------------ weather
  /// Returns current/forecast weather for [destination], or null when the
  /// OWM key is missing or the lookup fails. Never throws.
  static Future<WeatherInfo?> fetchWeather(String destination) async {
    if (!weatherConfigured || destination.trim().isEmpty) return null;
    try {
      final geoUri = Uri.parse(
          'https://api.openweathermap.org/geo/1.0/direct'
          '?q=${Uri.encodeComponent(destination.trim())}&limit=1&appid=$_owmKey');
      final geoRes =
          await http.get(geoUri).timeout(const Duration(seconds: 15));
      if (geoRes.statusCode != 200) return null;
      final geo = jsonDecode(geoRes.body) as List?;
      if (geo == null || geo.isEmpty) return null;
      final lat = (geo[0] as Map)['lat'];
      final lon = (geo[0] as Map)['lon'];
      if (lat == null || lon == null) return null;

      final fcUri = Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast'
          '?lat=$lat&lon=$lon&appid=$_owmKey&units=imperial');
      final fcRes =
          await http.get(fcUri).timeout(const Duration(seconds: 15));
      if (fcRes.statusCode != 200) return null;
      final fc = jsonDecode(fcRes.body) as Map<String, dynamic>;
      final list = fc['list'] as List?;
      if (list == null || list.isEmpty) return null;

      double tempSum = 0;
      int tempCount = 0;
      String condition = '';
      // Average the first 8 forecast entries (~24h) for a stable snapshot.
      for (final e in list.take(8)) {
        final m = e as Map<String, dynamic>;
        final t = (m['main'] as Map?)?['temp'];
        if (t is num) {
          tempSum += t.toDouble();
          tempCount++;
        }
        if (condition.isEmpty) {
          final w = (m['weather'] as List?);
          if (w != null && w.isNotEmpty) {
            condition = ((w[0] as Map)['description'] as String? ?? '')
                .split(' ')
                .map((w2) => w2.isEmpty
                    ? w2
                    : '${w2[0].toUpperCase()}${w2.substring(1)}')
                .join(' ');
          }
        }
      }
      if (tempCount == 0) return null;
      final avg = tempSum / tempCount;
      final cond = condition.isEmpty ? 'Fair' : condition;
      return WeatherInfo(
        summary: '${avg.round()}°F, $cond',
        avgTempF: avg,
        condition: cond,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ generate
  /// Full pipeline: weather -> Gemini JSON -> parse -> local fallback.
  /// Never throws; always returns a usable plan.
  static Future<GeneratedTripPlan> generatePlan({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required TripType tripType,
    required double budget,
    required String userId,
  }) async {
    final dest = destination.trim();
    final now = easternNow();
    final tripId = _uuid.v4();
    final trip = Trip(
      id: tripId,
      userId: userId,
      destination: dest,
      startDate: startDate,
      endDate: endDate,
      tripType: tripType,
      estimatedBudget: budget,
      createdAt: now,
      updatedAt: now,
    );

    WeatherInfo? weather;
    try {
      weather = await fetchWeather(dest);
    } catch (_) {
      weather = null;
    }

    GeneratedTripPlan? aiPlan;
    try {
      final raw = await GeminiService.askJson(
          _buildPrompt(trip, weather),
          systemContext:
              'You are Lifeez AI trip planner. You always reply with valid JSON only — no markdown, no commentary.');
      if (raw != null) aiPlan = _parseAiPlan(raw, trip, weather);
    } catch (_) {
      aiPlan = null;
    }

    final plan = aiPlan ?? _localFallback(trip, weather);

    // Best-effort persistence (tables exist after the migration is applied).
    try {
      await savePlan(plan);
    } catch (_) {}
    return plan;
  }

  static String _buildPrompt(Trip trip, WeatherInfo? weather) {
    final days = trip.dayCount;
    final wLine = weather == null
        ? 'Weather unknown — pack season-agnostic essentials.'
        : 'Current weather in ${trip.destination}: ${weather.summary} (${weather.tempBand}). Tailor packing to it.';
    return '''
Plan a $days-day trip to ${trip.destination} for trip type "${trip.tripType.name}".
Dates: ${_fmt(trip.startDate)} to ${_fmt(trip.endDate)}.
Estimated total budget: \$${trip.estimatedBudget.round()} USD.
$wLine

Reply with ONLY this JSON (no markdown fences, no extra text):
{
  "itinerary": [
    {"day": 1, "date": "YYYY-MM-DD",
     "morning": {"title": "...", "description": "...", "spot": "popular spot name", "travelTip": "one practical tip", "startTime": "09:00"},
     "afternoon": {"title": "...", "description": "...", "spot": "...", "travelTip": "...", "startTime": "13:00"},
     "evening": {"title": "...", "description": "...", "spot": "...", "travelTip": "...", "startTime": "18:00"}}
  ],
  "packing": [
    {"item": "Light jacket", "category": "clothing"},
    {"item": "Phone charger", "category": "electronics"}
  ],
  "expenses": {
    "stay": {"amount": 0, "note": "..."},
    "food": {"amount": 0, "note": "..."},
    "sightseeing": {"amount": 0, "note": "..."},
    "transport": {"amount": 0, "note": "..."}
  }
}
Rules: exactly $days itinerary days; categories must be one of clothing|electronics|documents|essentials; amounts are USD numbers summing near the estimated budget; use real, popular spots in ${trip.destination}; plain US English.
''';
  }

  static String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  /// Defensive JSON parse. Returns null when the AI output is unusable.
  static GeneratedTripPlan? _parseAiPlan(
      String raw, Trip trip, WeatherInfo? weather) {
    try {
      var text = raw.trim();
      // Strip markdown fences if the model added them anyway.
      if (text.startsWith('```')) {
        text = text.replaceAll(RegExp(r'^```[a-zA-Z]*'), '');
        final end = text.lastIndexOf('```');
        if (end > 0) text = text.substring(0, end);
      }
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final data =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;

      final tripWithWeather = Trip(
        id: trip.id,
        userId: trip.userId,
        destination: trip.destination,
        startDate: trip.startDate,
        endDate: trip.endDate,
        tripType: trip.tripType,
        estimatedBudget: trip.estimatedBudget,
        weatherSummary: weather?.summary,
        createdAt: trip.createdAt,
        updatedAt: trip.updatedAt,
      );

      final days = <ItineraryDay>[];
      final itin = data['itinerary'] as List?;
      if (itin == null || itin.isEmpty) return null;
      for (var i = 0; i < trip.dayCount; i++) {
        final rawDay = i < itin.length ? itin[i] as Map<String, dynamic> : {};
        final dayId = _uuid.v4();
        final date = DateTime(
            trip.startDate.year, trip.startDate.month, trip.startDate.day + i);
        final slots = <ActivitySlot>[];
        for (final s in ['morning', 'afternoon', 'evening']) {
          final m = rawDay[s] as Map<String, dynamic>?;
          if (m == null) continue;
          slots.add(ActivitySlot(
            id: _uuid.v4(),
            itineraryDayId: dayId,
            slot: slotTypeFromString(s),
            title: (m['title'] as String? ?? '').trim().isEmpty
                ? _defaultSlotTitle(s)
                : (m['title'] as String? ?? '').trim(),
            description: (m['description'] as String?) ?? '',
            spot: (m['spot'] as String?) ?? '',
            travelTip: (m['travelTip'] as String?) ??
                (m['travel_tip'] as String?) ??
                '',
            startTime: _cleanTime(m['startTime'] as String?),
          ));
        }
        if (slots.isEmpty) return null;
        days.add(ItineraryDay(
            id: dayId, tripId: trip.id, dayNumber: i + 1, date: date, slots: slots));
      }

      final packing = <PackingItem>[];
      final rawPacking = data['packing'] as List?;
      if (rawPacking != null) {
        for (final p in rawPacking) {
          final m = p as Map<String, dynamic>;
          final label = (m['item'] as String? ?? '').trim();
          if (label.isEmpty) continue;
          packing.add(PackingItem(
            id: _uuid.v4(),
            tripId: trip.id,
            category: packingCategoryFromString(m['category'] as String?),
            label: label,
          ));
        }
      }

      final expenses = <ExpenseBreakdown>[];
      final rawExp = data['expenses'] as Map<String, dynamic>?;
      if (rawExp != null) {
        for (final c in ['stay', 'food', 'sightseeing', 'transport']) {
          final m = rawExp[c] as Map<String, dynamic>?;
          if (m == null) continue;
          expenses.add(ExpenseBreakdown(
            id: _uuid.v4(),
            tripId: trip.id,
            category: expenseCategoryFromString(c),
            amountUsd: ((m['amount'] as num?) ?? 0).toDouble(),
            note: (m['note'] as String?)?.trim().isEmpty == true
                ? null
                : m['note'] as String?,
          ));
        }
      }

      return GeneratedTripPlan(
          trip: tripWithWeather,
          days: days,
          packing: packing,
          expenses: expenses);
    } catch (_) {
      return null;
    }
  }

  static String _defaultSlotTitle(String slot) {
    switch (slot) {
      case 'afternoon':
        return 'Afternoon exploration';
      case 'evening':
        return 'Evening unwind';
      case 'morning':
      default:
        return 'Morning start';
    }
  }

  static String? _cleanTime(String? t) {
    if (t == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!).clamp(0, 23);
    return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
  }

  // ------------------------------------------------------------ fallback
  /// Real local template generator — used when Gemini is unavailable.
  /// Produces a sensible, complete plan scaled by trip length.
  static GeneratedTripPlan _localFallback(Trip trip, WeatherInfo? weather) {
    final dest = trip.destination;
    final days = <ItineraryDay>[];
    for (var i = 0; i < trip.dayCount; i++) {
      final dayId = _uuid.v4();
      final date = DateTime(
          trip.startDate.year, trip.startDate.month, trip.startDate.day + i);
      final isFirst = i == 0;
      final isLast = i == trip.dayCount - 1;
      days.add(ItineraryDay(
        id: dayId,
        tripId: trip.id,
        dayNumber: i + 1,
        date: date,
        slots: [
          ActivitySlot(
            id: _uuid.v4(),
            itineraryDayId: dayId,
            slot: SlotType.morning,
            title: isFirst ? 'Arrival & check-in' : 'Explore $dest highlights',
            description: isFirst
                ? 'Arrive, check in, and get oriented with a walk around your stay.'
                : 'Visit the most popular landmarks and neighborhoods.',
            spot: isFirst ? 'Your hotel area' : 'Downtown $dest',
            travelTip: 'Start early to beat the crowds.',
            startTime: '09:00',
          ),
          ActivitySlot(
            id: _uuid.v4(),
            itineraryDayId: dayId,
            slot: SlotType.afternoon,
            title: 'Local food & culture',
            description:
                'Try local restaurants and browse a museum, market, or historic district.',
            spot: 'Local market district',
            travelTip: 'Keep some cash handy for small vendors.',
            startTime: '13:00',
          ),
          ActivitySlot(
            id: _uuid.v4(),
            itineraryDayId: dayId,
            slot: SlotType.evening,
            title: isLast ? 'Pack & departure prep' : 'Sunset & evening stroll',
            description: isLast
                ? 'Pack up, confirm checkout and travel home details.'
                : 'Wind down with a scenic evening walk and dinner.',
            spot: isLast ? 'Your hotel' : 'Waterfront / old town',
            travelTip: isLast
                ? 'Charge all devices overnight.'
                : 'Book dinner spots ahead on weekends.',
            startTime: '18:00',
          ),
        ],
      ));
    }

    final band = weather?.tempBand;
    final packingDefs = <List<String>>[
      // clothing
      [
        'T-shirts and tops',
        'Jeans / comfortable pants',
        'Comfortable walking shoes',
        if (band == 'cold') 'Warm jacket' else 'Light jacket',
        if (band == 'cold') 'Sweater / hoodie',
        if (band == 'warm') 'Shorts & breathable clothes',
        if (band == 'warm') 'Hat / cap',
        'Sleepwear',
      ],
      // electronics
      [
        'Phone charger',
        'Power bank',
        'Travel adapter',
        'Earbuds / headphones',
      ],
      // documents
      [
        "Driver's license / ID",
        'Hotel confirmations',
        'Travel insurance info',
        if (trip.tripType == TripType.family) "Kids' IDs / copies",
      ],
      // essentials
      [
        'Medications',
        'Toiletries',
        'Reusable water bottle',
        'Snacks for the road',
        if (band == 'warm') 'Sunscreen',
        if (band == 'cold') 'Lip balm & moisturizer',
        if (trip.tripType == TripType.friends) 'Portable speaker',
        if (trip.tripType == TripType.family) "Kids' entertainment",
      ],
    ];
    final packing = <PackingItem>[];
    const cats = [
      PackingCategory.clothing,
      PackingCategory.electronics,
      PackingCategory.documents,
      PackingCategory.essentials,
    ];
    for (var c = 0; c < cats.length; c++) {
      for (final label in packingDefs[c]) {
        packing.add(PackingItem(
            id: _uuid.v4(),
            tripId: trip.id,
            category: cats[c],
            label: label));
      }
    }

    // Sensible per-day budget, scaled by trip type.
    final mult = switch (trip.tripType) {
      TripType.solo => 1.0,
      TripType.friends => 1.15,
      TripType.family => 1.6,
    };
    final n = trip.dayCount.toDouble();
    double r(double v) => (v * mult * n).roundToDouble();
    final expenses = [
      ExpenseBreakdown(
          id: _uuid.v4(),
          tripId: trip.id,
          category: ExpenseCategory.stay,
          amountUsd: r(130),
          note: '$n night(s) mid-range stay'),
      ExpenseBreakdown(
          id: _uuid.v4(),
          tripId: trip.id,
          category: ExpenseCategory.food,
          amountUsd: r(65),
          note: 'Meals & coffee'),
      ExpenseBreakdown(
          id: _uuid.v4(),
          tripId: trip.id,
          category: ExpenseCategory.sightseeing,
          amountUsd: r(40),
          note: 'Tickets & tours'),
      ExpenseBreakdown(
          id: _uuid.v4(),
          tripId: trip.id,
          category: ExpenseCategory.transport,
          amountUsd: r(55),
          note: 'Local transport & fuel'),
    ];

    return GeneratedTripPlan(
      trip: Trip(
        id: trip.id,
        userId: trip.userId,
        destination: trip.destination,
        startDate: trip.startDate,
        endDate: trip.endDate,
        tripType: trip.tripType,
        estimatedBudget: trip.estimatedBudget,
        weatherSummary: weather?.summary,
        createdAt: trip.createdAt,
        updatedAt: trip.updatedAt,
      ),
      days: days,
      packing: packing,
      expenses: expenses,
    );
  }

  // ------------------------------------------------------------ persist
  /// Best-effort save to Supabase (tables from the trips_ai migration).
  /// Swallows errors — the plan stays fully usable in memory.
  static Future<void> savePlan(GeneratedTripPlan plan) async {
    try {
      final client = SupabaseService.client;
      final t = plan.trip;
      await client.from('trips').upsert(t.toJson());
      for (final d in plan.days) {
        await client.from('trip_itinerary_days').upsert({
          'id': d.id,
          'user_id': t.userId,
          'trip_id': d.tripId,
          'day_number': d.dayNumber,
          'date': d.date.toIso8601String().substring(0, 10),
        });
        for (final s in d.slots) {
          await client.from('trip_activities').upsert(s.toJson());
        }
      }
      for (final p in plan.packing) {
        await client.from('trip_packing_items').upsert(p.toJson());
      }
      for (final e in plan.expenses) {
        await client.from('trip_expenses').upsert(e.toJson());
      }
    } catch (_) {
      // Tables may not exist yet (migration pending) — ignore.
    }
  }
}
