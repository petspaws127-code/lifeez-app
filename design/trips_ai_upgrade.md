# Trips AI Upgrade — Design & Backend Schema (for review, NOT implemented)

> Design-only. No code in `lib/` was written for this. No build started.

## 1. Dart model classes (proposed)

```dart
enum TripType { solo, friends, family }

enum SlotType { morning, afternoon, evening }

enum PackingCategory { clothing, electronics, documents, essentials }

enum ExpenseCategory { stay, food, sightseeing, transport }

class Trip {
  final String id;            // uuid (Supabase)
  final String userId;
  final String destination;
  final DateTime startDate;   // stored UTC, displayed MM/DD/YYYY
  final DateTime endDate;
  final TripType tripType;
  final double estimatedBudget; // USD
  final String? weatherSummary; // e.g. "72°F Sunny" (from OpenWeatherMap)
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ItineraryDay {
  final String id;
  final String tripId;
  final int dayNumber;        // 1..N
  final DateTime date;
  final List<ActivitySlot> slots; // exactly 3: morning/afternoon/evening
}

class ActivitySlot {
  final String id;
  final String itineraryDayId;
  final SlotType slot;        // morning | afternoon | evening
  final String title;         // e.g. "Central Park & The Met"
  final String description;   // what to do
  final String spot;          // popular spot name
  final String travelTip;     // one practical tip
  final String? startTime;    // "09:00" — used by Sync to Reminders
}

class PackingItem {
  final String id;
  final String tripId;
  final PackingCategory category; // clothing | electronics | documents | essentials
  final String label;         // e.g. "Light jacket"
  final bool isPacked;        // user-checkable
}

class ExpenseBreakdown {
  final String id;
  final String tripId;
  final ExpenseCategory category; // stay | food | sightseeing | transport
  final double amountUsd;
  final String? note;         // e.g. "3 nights Midtown hotel"
}
// Total = sum(amountUsd). Compared against Trip.estimatedBudget for the budget bar.
```

## 2. Supabase Postgres schema (SQL, per-user RLS)

Follows the existing `schema.sql` conventions (`user_id uuid references auth.users(id) on delete cascade`,
one `"own rows"` policy per table via the existing DO loop).

```sql
-- ============================================================
-- Trips AI upgrade tables
-- ============================================================
create table if not exists trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  destination text not null,
  start_date date not null,
  end_date date not null,
  trip_type text not null default 'solo'
    check (trip_type in ('solo','friends','family')),
  estimated_budget numeric(10,2) not null default 0,
  weather_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trips_dates_ok check (end_date >= start_date)
);

create table if not exists trip_itinerary_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references trips(id) on delete cascade,
  day_number int not null,
  date date not null,
  unique (trip_id, day_number)
);

create table if not exists trip_activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  itinerary_day_id uuid not null references trip_itinerary_days(id) on delete cascade,
  slot text not null check (slot in ('morning','afternoon','evening')),
  title text not null,
  description text not null default '',
  spot text not null default '',
  travel_tip text not null default '',
  start_time text, -- "HH:MM" local, used by Sync to Reminders
  unique (itinerary_day_id, slot)
);

create table if not exists trip_packing_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references trips(id) on delete cascade,
  category text not null
    check (category in ('clothing','electronics','documents','essentials')),
  label text not null,
  is_packed boolean not null default false
);

create table if not exists trip_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid not null references trips(id) on delete cascade,
  category text not null
    check (category in ('stay','food','sightseeing','transport')),
  amount_usd numeric(10,2) not null default 0,
  note text
);

-- RLS: per-user isolation (same pattern as existing tables)
alter table trips enable row level security;
alter table trip_itinerary_days enable row level security;
alter table trip_activities enable row level security;
alter table trip_packing_items enable row level security;
alter table trip_expenses enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'trips','trip_itinerary_days','trip_activities',
    'trip_packing_items','trip_expenses'
  ] loop
    execute format('drop policy if exists "own rows" on %I', t);
    execute format(
      'create policy "own rows" on %I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t);
  end loop;
end $$;
```

## 3. Data flow

1. **Input form** → user enters Destination, Start/End Date (MM/DD/YYYY pickers),
   Trip Type (Solo/Friends/Family), Estimated Budget (USD). Optional mic button:
   voice command transcribed on-device, parsed into the same fields.
2. **"Generate with AI"** → app calls Gemini cloud (`gemini-3.8-flash`, working API
   key exists) with a strict JSON prompt requesting: `itinerary` (per day →
   morning/afternoon/evening {title, description, spot, travelTip, startTime}),
   `packing` (clothing/electronics/documents/essentials lists), `expenses`
   (stay/food/sightseeing/transport amounts + notes).
3. **Parse & validate** → JSON parsed into the Dart models above; malformed AI
   output falls back to local template generation (offline fallback).
4. **Persist** → Trip + children saved to Supabase tables (RLS guarantees the
   user only ever sees their own trips).
5. **Result UI** → 3 tabs: Itinerary | Packing List | Expenses (budget bar =
   total vs estimated budget).
6. **Sync to Reminders** → for each activity with a `startTime`, inserts rows
   into the existing `tasks` table (`category='trip'`, `due_date` = day+time,
   `source='trips-ai'`) and/or `reminders` table — reusing the current
   Tasks/Calendar module, no new reminder system.
7. **Weather for packing** → OpenWeatherMap free tier by destination + dates;
   stored as `Trip.weatherSummary` and fed into the packing prompt.
   ⚠️ PENDING USER DECISION: needs a free OpenWeatherMap API key.

## 4. NOT included (single-feature discipline)

- No booking or payment integration (no hotels/flights checkout).
- No flight-status or booking APIs.
- No sharing/collaboration on trips (single user only, per standing data-isolation rule).
- No changes to existing Tasks/Calendar UI — Sync only writes rows.
