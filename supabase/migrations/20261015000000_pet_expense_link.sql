-- ============================================================
-- Pet expense link: add pet_id to expenses
-- Apply via Supabase dashboard SQL editor.
-- ============================================================
alter table expenses
  add column if not exists pet_id uuid references pet_profiles(id) on delete set null;

create index if not exists idx_expenses_pet_id on expenses(pet_id);
