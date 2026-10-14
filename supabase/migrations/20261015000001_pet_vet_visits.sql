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
