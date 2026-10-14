-- ============================================================
-- Pet vet visits table
-- Apply via Supabase dashboard SQL editor.
-- ============================================================
create table if not exists pet_vet_visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pet_id uuid not null references pet_profiles(id) on delete cascade,
  visit_date date not null default current_date,
  reason text not null default '',
  vet_name text,
  notes text,
  cost numeric,
  created_at timestamptz not null default now()
);

create index if not exists idx_pet_vet_visits_pet_id on pet_vet_visits(pet_id);
create index if not exists idx_pet_vet_visits_user_id on pet_vet_visits(user_id);

-- Row Level Security: users can only access their own rows.
alter table pet_vet_visits enable row level security;
drop policy if exists "own rows" on pet_vet_visits;
create policy "own rows" on pet_vet_visits for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
