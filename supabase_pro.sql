-- supabase_setup.sql کے بعد یہ چلائیں: مفت پلان میں 10 طلبہ کی حد

create table if not exists plans (
  owner uuid primary key references auth.users(id) on delete cascade,
  paid_until date not null
);
alter table plans enable row level security;
create policy "own plan read" on plans for select using (owner = auth.uid());
-- لکھنے کی کوئی پالیسی نہیں: صرف آپ ڈیش بورڈ سے پرو فعال کر سکتے ہیں

create or replace function enforce_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int; active boolean;
begin
  -- پہلے سے موجود طالب علم کی اپڈیٹ پر حد نہیں لگتی
  if exists (select 1 from snapshots where code = new.code) then return new; end if;
  select count(*) into n from snapshots where owner = new.owner;
  select paid_until >= current_date into active from plans where owner = new.owner;
  if n >= 10 and not coalesce(active, false) then
    raise exception 'FREE_LIMIT';
  end if;
  return new;
end $$;

create trigger snapshots_limit before insert on snapshots
  for each row execute function enforce_limit();

-- ادائیگی آنے پر ٹیچر کو 30 دن کا پرو دینے کے لیے (ای میل بدلیں):
-- insert into plans(owner, paid_until)
--   select id, current_date + 30 from auth.users where email = 'teacher@example.com'
--   on conflict (owner) do update
--   set paid_until = greatest(plans.paid_until, current_date) + 30;
