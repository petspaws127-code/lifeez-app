-- ============================================================
-- Ai Life Assistant — Supabase schema
-- Run this in the Supabase SQL editor (or via the CLI) once.
-- Every table has Row Level Security: users see only their own rows.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------- profiles
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  currency text not null default 'USD',
  time_zone text not null default 'America/New_York',
  monthly_income numeric not null default 0,
  monthly_budget numeric not null default 0,
  plan text not null default 'free',
  login_provider text,
  whatsapp_number text,
  whatsapp_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------- accounts
-- Linked login providers per user (google / apple / facebook / whatsapp).
create table if not exists accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  provider_user_id text,
  created_at timestamptz not null default now(),
  unique (user_id, provider)
);

-- ------------------------------------------------------------- tasks
create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  due_date timestamptz,
  priority text not null default 'normal',
  category text not null default 'general',
  repeat text,
  reminder_at timestamptz,
  is_done boolean not null default false,
  source text not null default 'app',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------- expenses
create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null,
  category text not null default 'Other',
  note text not null default '',
  spent_at timestamptz not null default now(),
  source text not null default 'app',
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------- bills
create table if not exists bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amount numeric not null,
  due_day int not null check (due_day between 1 and 31),
  paid_this_month boolean not null default false,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------- subscriptions
create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amount numeric not null,
  renewal_day int not null check (renewal_day between 1 and 31),
  billing_cycle text not null default 'monthly',
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------- shopping_items
create table if not exists shopping_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  section text not null default 'General',
  is_bought boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------- reminders
create table if not exists reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  remind_at timestamptz not null,
  repeat text,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------- documents
create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  doc_type text not null default 'other',
  expiry_date date,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------- vehicles
create table if not exists vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  mileage numeric not null default 0,
  created_at timestamptz not null default now()
);

-- -------------------------------------------------- maintenance_items
create table if not exists maintenance_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  title text not null,
  due_date date,
  due_mileage numeric,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------- family_members
create table if not exists family_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  relationship text not null default '',
  birthday date,
  created_at timestamptz not null default now()
);

-- -------------------------------------------------------- message_log
-- Every WhatsApp / assistant message: intent, result, dedupe id.
create table if not exists message_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  direction text not null default 'in',
  body text not null default '',
  intent text,
  result text,
  external_message_id text unique,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------ whatsapp_connections
create table if not exists whatsapp_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  phone_number text not null,
  status text not null default 'disconnected',
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table profiles enable row level security;
alter table accounts enable row level security;
alter table tasks enable row level security;
alter table expenses enable row level security;
alter table bills enable row level security;
alter table subscriptions enable row level security;
alter table shopping_items enable row level security;
alter table reminders enable row level security;
alter table documents enable row level security;
alter table vehicles enable row level security;
alter table maintenance_items enable row level security;
alter table family_members enable row level security;
alter table message_log enable row level security;
alter table whatsapp_connections enable row level security;

-- profiles: the row id IS the auth user id
drop policy if exists "own profile" on profiles;
create policy "own profile" on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- every other table: user_id column
do $$
declare t text;
begin
  foreach t in array array[
    'accounts','tasks','expenses','bills','subscriptions',
    'shopping_items','reminders','documents','vehicles',
    'maintenance_items','family_members','message_log',
    'whatsapp_connections'
  ] loop
    execute format('drop policy if exists "own rows" on %I', t);
    execute format(
      'create policy "own rows" on %I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t);
  end loop;
end $$;

-- ============================================================
-- Auto-create an empty profile when a user signs up
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helpful indexes
create index if not exists idx_tasks_user on tasks(user_id);
create index if not exists idx_expenses_user_spent on expenses(user_id, spent_at);
create index if not exists idx_reminders_user_at on reminders(user_id, remind_at);
create index if not exists idx_message_log_ext on message_log(external_message_id);

-- ------------------------------------------------------ whatsapp_otps
-- One-time login codes. Service-role only (Edge Functions); no client policy.
create table if not exists whatsapp_otps (
  phone text primary key,
  code_hash text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table whatsapp_otps enable row level security;

-- ============================================================
-- Migration: tables + columns added after the first release
-- (habits, pets, brain dump, savings, lent/borrowed, PIN, Pro,
--  profile preferences, receipts, pet reminder links)
-- ============================================================

-- New profile columns
alter table profiles add column if not exists email text not null default '';
alter table profiles add column if not exists savings_goal numeric not null default 0;
alter table profiles add column if not exists pin_hash text;
alter table profiles add column if not exists trial_ends_at date;
alter table profiles add column if not exists pro_plan text;
alter table profiles add column if not exists pro_renews_at date;
alter table profiles add column if not exists theme_mode text not null default 'system';
alter table profiles add column if not exists photo_path text;
alter table profiles add column if not exists notifications_enabled boolean not null default true;
alter table profiles add column if not exists daily_briefing_enabled boolean not null default true;
alter table profiles add column if not exists referral_code text not null default '';
alter table profiles add column if not exists referral_count int not null default 0;
alter table profiles add column if not exists pro_days_earned int not null default 0;
alter table profiles add column if not exists go_pro_popup_date date;
alter table profiles add column if not exists go_pro_popup_count int not null default 0;

-- Receipt photo on expenses
alter table expenses add column if not exists receipt_path text;

-- Pets-only reminder link
alter table reminders add column if not exists pet_id uuid;

-- Pet profile photo
alter table pet_profiles add column if not exists photo_path text;

-- ------------------------------------------------------------ habits
create table if not exists habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  checkins text not null default '[]',
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------ pet_profiles
create table if not exists pet_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  species text not null default 'dog',
  breed text,
  birth_date date,
  weight_lbs numeric,
  notes text,
  photo_path text,
  created_at timestamptz not null default now()
);

-- -------------------------------------------------- pet_vaccinations
create table if not exists pet_vaccinations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pet_id uuid not null references pet_profiles(id) on delete cascade,
  vaccine_name text not null,
  given_date date not null,
  next_due_date date,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------ pet_memories
create table if not exists pet_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pet_id uuid not null references pet_profiles(id) on delete cascade,
  caption text not null default '',
  memory_date date not null,
  photo_path text,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------- brain_dumps
create table if not exists brain_dumps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

-- --------------------------------------------------- savings_entries
create table if not exists savings_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null,
  note text not null default '',
  saved_at date not null,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------- lent_borrowed
create table if not exists lent_borrowed (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  person text not null,
  item text not null,
  amount numeric,
  direction text not null default 'lent',
  date date not null,
  due_date date,
  note text,
  settled boolean not null default false,
  created_at timestamptz not null default now()
);

-- RLS for the new tables
alter table habits enable row level security;
alter table pet_profiles enable row level security;
alter table pet_vaccinations enable row level security;
alter table pet_memories enable row level security;
alter table brain_dumps enable row level security;
alter table savings_entries enable row level security;
alter table lent_borrowed enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'habits','pet_profiles','pet_vaccinations','pet_memories',
    'brain_dumps','savings_entries','lent_borrowed'
  ] loop
    execute format('drop policy if exists "own rows" on %I', t);
    execute format(
      'create policy "own rows" on %I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t);
  end loop;
end $$;

create index if not exists idx_habits_user on habits(user_id);
create index if not exists idx_pets_user on pet_profiles(user_id);
create index if not exists idx_brain_dumps_user on brain_dumps(user_id);
create index if not exists idx_savings_user on savings_entries(user_id);
create index if not exists idx_lent_borrowed_user on lent_borrowed(user_id);
