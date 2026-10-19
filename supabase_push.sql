-- پش نوٹیفکیشن (supabase_setup.sql کے بعد چلائیں)
-- پہلے: Dashboard > Integrations > Database Webhooks > Enable
-- نیچے PROJECT_REF اور CHANGE_ME بدلیں (CHANGE_ME وہی جو WEBHOOK_SECRET میں رکھیں گے)

create table if not exists push_tokens (
  code text not null references snapshots(code) on delete cascade,
  token text not null,
  primary key (code, token)
);
alter table push_tokens enable row level security; -- کوئی پالیسی نہیں: صرف نیچے کے فنکشن لکھ سکتے ہیں

create or replace function register_token(p_code text, p_token text)
returns void language sql security definer set search_path = public as $$
  insert into push_tokens(code, token)
  select p_code, p_token where exists (select 1 from snapshots where code = p_code)
  on conflict do nothing
$$;

create or replace function unregister_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token
$$;

grant execute on function register_token(text, text) to anon, authenticated;
grant execute on function unregister_token(text) to anon, authenticated;

create trigger snapshots_push after update on snapshots
  for each row when (old.data is distinct from new.data)
  execute function supabase_functions.http_request(
    'https://PROJECT_REF.supabase.co/functions/v1/notify',
    'POST',
    '{"Content-Type":"application/json","x-webhook-secret":"CHANGE_ME"}',
    '{}',
    '5000'
  );
