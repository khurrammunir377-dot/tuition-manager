-- ہوم ورک تصویر + والدین کے سوالات (پہلے والی SQL فائلوں کے بعد چلائیں)

-- 1) ہوم ورک کی تصاویر کا اسٹوریج (پڑھنا سب کے لیے لنک سے، لکھنا صرف ٹیچر اپنے فولڈر میں)
insert into storage.buckets (id, name, public)
values ('homework', 'homework', true) on conflict (id) do nothing;

create policy "teacher upload homework" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'homework' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "teacher delete homework" on storage.objects
  for delete to authenticated
  using (bucket_id = 'homework' and (storage.foldername(name))[1] = auth.uid()::text);

-- 2) سوالات
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  code text not null references snapshots(code) on delete cascade,
  q text not null check (length(q) between 1 and 500),
  a text,
  created_at timestamptz not null default now(),
  answered_at timestamptz
);
alter table questions enable row level security;

create policy "owner read questions" on questions for select
  using (exists (select 1 from snapshots s where s.code = questions.code and s.owner = auth.uid()));
create policy "owner answer questions" on questions for update
  using (exists (select 1 from snapshots s where s.code = questions.code and s.owner = auth.uid()))
  with check (exists (select 1 from snapshots s where s.code = questions.code and s.owner = auth.uid()));
revoke update on questions from authenticated;
grant update (a, answered_at) on questions to authenticated;

-- والدین (بغیر لاگ اِن) اپنے کوڈ سے سوال بھیجتے اور دیکھتے ہیں
create or replace function ask_question(p_code text, p_q text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from snapshots where code = p_code) then raise exception 'BAD_CODE'; end if;
  if (select count(*) from questions where code = p_code and a is null) >= 5 then raise exception 'TOO_MANY'; end if;
  insert into questions(code, q) values (p_code, left(trim(p_q), 500));
end $$;

create or replace function get_questions(p_code text)
returns jsonb language sql security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('q', q, 'a', a, 'd', created_at) order by created_at desc), '[]'::jsonb)
  from (select * from questions where code = p_code order by created_at desc limit 20) x
$$;

grant execute on function ask_question(text, text) to anon, authenticated;
grant execute on function get_questions(text) to anon, authenticated;

-- 3) ٹیچر کا جواب لکھتے ہی والدین کو نوٹیفکیشن (PROJECT_REF اور CHANGE_ME وہی جو supabase_push.sql میں تھے)
create trigger questions_push after update on questions
  for each row when (old.a is distinct from new.a and new.a is not null)
  execute function supabase_functions.http_request(
    'https://PROJECT_REF.supabase.co/functions/v1/notify',
    'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"CHANGE_ME"}',
    '{}',
    '5000'
  );
