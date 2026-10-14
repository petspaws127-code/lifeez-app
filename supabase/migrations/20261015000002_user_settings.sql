-- ============================================================
-- User settings table (key-value for budgets, preferences, etc.)
-- Apply via Supabase dashboard SQL editor.
-- ============================================================
create table if not exists user_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique(user_id, key)
);

create index if not exists idx_user_settings_user_id on user_settings(user_id);

alter table user_settings enable row level security;
drop policy if exists "own rows" on user_settings;
create policy "own rows" on user_settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
