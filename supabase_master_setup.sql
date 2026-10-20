-- ========================================================================
-- KMB Tuition & Quran Manager - Master Database Migration & Fix
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/gxlwsrrdcbecqcaiwufm/sql/new
-- ========================================================================

-- 1. Fix / Recreate app_downloads for Website Live Counter
drop table if exists public.app_downloads cascade;

create table public.app_downloads (
  id uuid primary key default gen_random_uuid(),
  app_name text not null,
  referrer text,
  user_agent text,
  created_at timestamptz default now()
);

alter table public.app_downloads enable row level security;

drop policy if exists "allow_anon_insert_downloads" on public.app_downloads;
drop policy if exists "allow_anon_select_downloads" on public.app_downloads;
drop policy if exists "Allow public read on app_downloads" on public.app_downloads;
drop policy if exists "Allow public insert/update on app_downloads" on public.app_downloads;

create policy "allow_anon_insert_downloads"
  on public.app_downloads for insert
  to anon, authenticated
  with check (true);

create policy "allow_anon_select_downloads"
  on public.app_downloads for select
  to anon, authenticated
  using (true);

-- 2. Fix snapshots table (Add missing student_id, center, owner columns)
create table if not exists public.snapshots (
  code text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- Ensure all required columns exist
alter table public.snapshots add column if not exists student_id text;
alter table public.snapshots add column if not exists center text;
alter table public.snapshots add column if not exists owner text;

alter table public.snapshots enable row level security;

drop policy if exists "allow_all_snapshots_insert" on public.snapshots;
drop policy if exists "allow_all_snapshots_update" on public.snapshots;
drop policy if exists "allow_all_snapshots_select" on public.snapshots;
drop policy if exists "Allow public read on snapshots" on public.snapshots;
drop policy if exists "Allow public upsert on snapshots" on public.snapshots;

create policy "allow_all_snapshots_insert"
  on public.snapshots for insert
  to anon, authenticated
  with check (true);

create policy "allow_all_snapshots_update"
  on public.snapshots for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "allow_all_snapshots_select"
  on public.snapshots for select
  to anon, authenticated
  using (true);

-- 3. Replace get_snapshot RPC function (Supports case-insensitive & trimmed codes)
create or replace function public.get_snapshot(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'code', code,
    'student_id', coalesce(student_id, ''),
    'center', coalesce(center, 'ٹیوشن اکیڈمی'),
    'data', data,
    'updated_at', updated_at
  )
  from public.snapshots
  where lower(trim(code)) = lower(trim(p_code))
  limit 1;
$$;

grant execute on function public.get_snapshot(text) to anon, authenticated;

-- 4. Backups table (Teacher full cloud backup)
create table if not exists public.backups (
  owner text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.backups enable row level security;
drop policy if exists "allow_backup_all" on public.backups;

create policy "allow_backup_all"
  on public.backups for all
  to anon, authenticated
  using (true)
  with check (true);

-- 5. Questions / Q&A Table & Functions
create table if not exists public.questions (
  id bigserial primary key,
  code text not null,
  q text not null,
  a text,
  created_at timestamptz not null default now(),
  answered_at timestamptz
);

alter table public.questions enable row level security;
drop policy if exists "allow_q_all" on public.questions;

create policy "allow_q_all"
  on public.questions for all
  to anon, authenticated
  using (true)
  with check (true);

create or replace function public.ask_question(p_code text, p_q text)
returns void
language sql
security definer
as $$
  insert into public.questions(code, q) values (lower(trim(p_code)), p_q);
$$;

grant execute on function public.ask_question(text, text) to anon, authenticated;

create or replace function public.get_questions(p_code text)
returns setof public.questions
language sql
security definer
as $$
  select * from public.questions
  where lower(trim(code)) = lower(trim(p_code))
  order by created_at desc
  limit 50;
$$;

grant execute on function public.get_questions(text) to anon, authenticated;
