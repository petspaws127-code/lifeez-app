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
