create table if not exists public.calendar_connections (
  user_id uuid primary key references public.users(id) on delete cascade,
  token_ciphertext text not null
);
create table if not exists public.calendar_oauth_states (
  state_hash text primary key,user_id uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz not null
);
create table if not exists public.calendar_actions (
  id uuid primary key default gen_random_uuid(),user_id uuid not null references public.users(id) on delete cascade,
  payload jsonb not null,status text not null default 'draft' check(status in ('draft','approved','running','completed','uncertain','rejected')),
  attempts integer not null default 0,lease_token uuid,lease_until timestamptz,
  available_at timestamptz not null default now(),remote_id text,error_code text,
  created_at timestamptz not null default now()
);
do $$ declare t text; begin
  foreach t in array array['calendar_connections','calendar_oauth_states','calendar_actions'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;

create or replace function public.decide_calendar_action(p_owner uuid,p_action uuid,p_approve boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a calendar_actions; desired text=case when p_approve then 'approved' else 'rejected' end;
begin
  select * into a from calendar_actions where id=p_action and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if a.status=desired or (p_approve and a.status='completed') then return to_jsonb(a); end if;
  if a.status<>'draft' and not (p_approve and a.status='uncertain') then raise exception 'state_conflict'; end if;
  if p_approve and not exists(select 1 from calendar_connections where user_id=p_owner) then raise exception 'calendar_not_connected'; end if;
  update calendar_actions set status=desired,attempts=0,available_at=now() where id=p_action returning * into a;
  return to_jsonb(a);
end $$;

create or replace function public.claim_calendar_action()
returns jsonb language plpgsql security definer set search_path=public as $$
declare a calendar_actions;
begin
  update calendar_actions set status='uncertain',error_code='retry_budget_exhausted'
    where status='running' and lease_until<now() and attempts>=3;
  select * into a from calendar_actions where attempts<3 and
    ((status='approved' and available_at<=now()) or (status='running' and lease_until<now()))
    order by available_at limit 1 for update skip locked;
  if not found then return null; end if;
  update calendar_actions set status='running',attempts=attempts+1,lease_token=gen_random_uuid(),lease_until=now()+interval '3 minutes'
    where id=a.id returning * into a;
  return to_jsonb(a);
end $$;
revoke all on function public.decide_calendar_action(uuid,uuid,boolean),public.claim_calendar_action() from public,anon,authenticated;
grant execute on function public.decide_calendar_action(uuid,uuid,boolean),public.claim_calendar_action() to service_role;
