-- ========================================================================
-- KMB Tuition & Quran Manager - Complete Master Setup for Supabase
-- Run this ONCE in Supabase > SQL Editor (New Query > Paste > Run)
-- ========================================================================

-- 1. Table for Live Website Download Counters
create table if not exists public.app_downloads (
  id uuid primary key default gen_random_uuid(),
  app_name text not null,
  referrer text,
  user_agent text,
  created_at timestamptz default now()
);

alter table public.app_downloads enable row level security;

-- Drop old policies if any to prevent duplicates
drop policy if exists "allow_anon_insert_downloads" on public.app_downloads;
drop policy if exists "allow_anon_select_downloads" on public.app_downloads;

create policy "allow_anon_insert_downloads"
  on public.app_downloads for insert
  to anon, authenticated
  with check (true);

create policy "allow_anon_select_downloads"
  on public.app_downloads for select
  to anon, authenticated
  using (true);

-- 2. Table for Student & Parent Live Record Snapshots
create table if not exists public.snapshots (
  code text primary key,
  student_id text not null,
  center text,
  data jsonb not null,
  owner text,
  updated_at timestamptz not null default now()
);

alter table public.snapshots enable row level security;

drop policy if exists "allow_all_snapshots_insert" on public.snapshots;
drop policy if exists "allow_all_snapshots_update" on public.snapshots;
drop policy if exists "allow_all_snapshots_select" on public.snapshots;

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

-- 3. Fast RPC function for Students & Parents to read record by Code
create or replace function public.get_snapshot(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'code', code,
    'student_id', student_id,
    'center', center,
    'data', data,
    'updated_at', updated_at
  )
  from public.snapshots
  where lower(trim(code)) = lower(trim(p_code))
  limit 1;
$$;

grant execute on function public.get_snapshot(text) to anon, authenticated;

-- 4. Full Teacher Center Backup Table
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

-- 5. Q&A Table for Parents asking Teacher Questions
create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  question text not null,
  answer text,
  created_at timestamptz default now(),
  answered_at timestamptz
);

alter table public.questions enable row level security;

drop policy if exists "allow_questions_all" on public.questions;

create policy "allow_questions_all"
  on public.questions for all
  to anon, authenticated
  using (true)
  with check (true);

-- Grant schema permissions
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;
