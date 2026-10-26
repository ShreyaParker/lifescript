-- New Supabase projects: apply in order using the SQL editor or migration tooling.
-- Existing projects: reconcile the baseline before applying; no automatic destructive changes.
create extension if not exists vector with schema extensions;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, onboarding_complete boolean not null default false,
  archetype_data jsonb not null default '{}', macro_goals text[] not null default '{}',
  primary_north_star text, created_at timestamptz not null default now()
);
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  content text not null, embedding extensions.vector(768),
  created_at timestamptz not null default now()
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null, description text not null default '',
  xp_value integer not null default 20 check(xp_value between 10 and 50),
  status text not null default 'pending' check(status in ('pending','completed')),
  source text not null default 'manual', created_at timestamptz not null default now()
);
create table if not exists public.user_media (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  media_type text not null, title text not null, current_status text not null default 'completed',
  updated_at timestamptz not null default now()
);
alter table public.users add column if not exists primary_north_star text;
alter table public.users add column if not exists email text;
alter table public.users alter column email drop not null;
alter table public.users add column if not exists onboarding_complete boolean not null default false;
alter table public.users add column if not exists archetype_data jsonb not null default '{}';
alter table public.users add column if not exists macro_goals text[] not null default '{}';
alter table public.journal_entries alter column embedding drop not null;
create index if not exists journal_owner_date on public.journal_entries(user_id,created_at desc);
create index if not exists tasks_owner_date on public.tasks(user_id,created_at desc);
create index if not exists media_owner on public.user_media(user_id);

alter table public.users enable row level security;
alter table public.journal_entries enable row level security;
alter table public.tasks enable row level security;
alter table public.user_media enable row level security;
-- Replace legacy permissive profile policies in this dedicated LifeScript schema.
do $$ declare p record; begin
  for p in select policyname from pg_policies where schemaname='public' and tablename='users' loop
    execute format('drop policy %I on public.users',p.policyname);
  end loop;
end $$;
create policy own_profile_read on public.users for select to authenticated using(id=auth.uid());
-- All domain writes use the authenticated backend. Do not grant client writes.
revoke all on public.users from public,anon,authenticated;
grant select on public.users to authenticated;
revoke all on public.journal_entries,public.tasks,public.user_media from public,anon,authenticated;
grant all on public.users,public.journal_entries,public.tasks,public.user_media to service_role;

create or replace function public.bootstrap_auth_profile()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into users(id,email) values(new.id,new.email) on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists lifescript_auth_profile on auth.users;
create trigger lifescript_auth_profile after insert on auth.users for each row execute function public.bootstrap_auth_profile();
insert into public.users(id,email) select id,email from auth.users on conflict(id) do nothing;
