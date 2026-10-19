-- Supabase > SQL Editor میں یہ پورا چلائیں
create table if not exists snapshots (
  code text primary key,
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  student_id text not null,
  center text,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table snapshots enable row level security;

-- ٹیچر صرف اپنی قطاریں دیکھ/بدل سکتا ہے
create policy "owner all" on snapshots
  for all using (owner = auth.uid()) with check (owner = auth.uid());

-- والدین صرف اپنے 8 حرفی کوڈ سے ایک بچے کا ریکارڈ پڑھ سکتے ہیں
create or replace function get_snapshot(p_code text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object('center', center, 'data', data, 'updated_at', updated_at)
  from snapshots where code = p_code
$$;

grant execute on function get_snapshot(text) to anon, authenticated;

create or replace function touch_updated() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger snapshots_touch before update on snapshots
  for each row execute function touch_updated();
