-- ٹیچر کے ڈیٹا کا کلاؤڈ بیک اپ (supabase_setup.sql کے بعد چلائیں)
create table if not exists backups (
  owner uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table backups enable row level security;
create policy "own backup" on backups
  for all using (owner = auth.uid()) with check (owner = auth.uid());
