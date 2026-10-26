create table if not exists public.assets (
  id uuid primary key, user_id uuid not null references public.users(id) on delete cascade,
  filename text not null, mime_type text not null, storage_path text not null unique,
  size_bytes integer not null, status text not null default 'ready' check(status in ('pending','ready')),
  created_at timestamptz not null default now()
);
create table if not exists public.workflow_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  entry_id uuid not null references public.journal_entries(id) on delete cascade,
  request_key text not null, request_digest text not null, timezone text not null default 'Asia/Kolkata',
  asset_ids uuid[] not null default '{}',
  workflow_kind text not null default 'planning',
  status text not null default 'queued' check(status in ('queued','running','awaiting_clarification','awaiting_review','completed','rejected','failed','cancelled')),
  attempts integer not null default 0, lease_token uuid, lease_until timestamptz,
  available_at timestamptz not null default now(),
  proposal jsonb, sources jsonb not null default '[]', questions jsonb,
  resume_data jsonb, version integer not null default 1,
  decision jsonb, result jsonb not null default '[]', error_code text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(user_id,request_key)
);
alter table public.tasks add column if not exists run_id uuid references public.workflow_runs(id) on delete set null;
alter table public.tasks add column if not exists proposal_index integer;
alter table public.tasks add column if not exists evidence text;
alter table public.tasks add column if not exists duration_minutes integer;
create unique index if not exists task_run_item on public.tasks(run_id,proposal_index);
create index if not exists run_queue on public.workflow_runs(status,available_at,lease_until);
create index if not exists run_owner on public.workflow_runs(user_id,created_at desc);

create table if not exists public.memory_chunks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  entry_id uuid not null references public.journal_entries(id) on delete cascade,
  source_id text not null, content text not null, embedding extensions.vector(768),
  embedding_model text, search_text tsvector generated always as(to_tsvector('simple',content)) stored,
  unique(entry_id,source_id)
);
create index if not exists memory_owner on public.memory_chunks(user_id);
create index if not exists memory_text on public.memory_chunks using gin(search_text);

create table if not exists public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null, kind text not null check(kind in ('daily_plan','weekly_review','reminder')),
  instruction text not null, interval_hours integer not null check(interval_hours between 1 and 168),
  enabled boolean not null default true, next_run_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create table if not exists public.automation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  rule_id uuid references public.automation_rules(id) on delete cascade,
  run_id uuid references public.workflow_runs(id) on delete set null,
  message text not null, created_at timestamptz not null default now()
);

-- RPCs are backend-only. Owner IDs originate exclusively in the auth dependency/worker.
create or replace function public.create_entry_run(p_owner uuid,p_content text,p_key text,p_digest text,p_assets uuid[],p_timezone text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare r workflow_runs; e uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_owner::text||p_key,0));
  select * into r from workflow_runs where user_id=p_owner and request_key=p_key;
  if found then
    if r.request_digest<>p_digest then raise exception 'idempotency_conflict'; end if;
    return to_jsonb(r);
  end if;
  if (select count(*) from workflow_runs where user_id=p_owner and created_at>now()-interval '1 hour')>=30 then
    raise exception 'quota_exceeded';
  end if;
  perform id from assets where id=any(p_assets) and user_id=p_owner and status='ready' for share;
  if cardinality(p_assets)<>(select count(*) from assets where id=any(p_assets) and user_id=p_owner and status='ready') then
    raise exception 'asset_not_found';
  end if;
  insert into users(id) values(p_owner) on conflict(id) do nothing;
  insert into journal_entries(user_id,content) values(p_owner,p_content) returning id into e;
  insert into workflow_runs(user_id,entry_id,request_key,request_digest,asset_ids,timezone)
    values(p_owner,e,p_key,p_digest,p_assets,p_timezone) returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.claim_workflow(p_lease_seconds integer,p_max_attempts integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r workflow_runs;
begin
  update workflow_runs set status='failed',error_code='retry_budget_exhausted',lease_token=null,lease_until=null
    where status='running' and lease_until<now() and attempts>=p_max_attempts;
  select * into r from workflow_runs where attempts<p_max_attempts and
    ((status='queued' and available_at<=now()) or (status='running' and lease_until<now()))
    order by available_at limit 1 for update skip locked;
  if not found then return null; end if;
  update workflow_runs set status='running',attempts=attempts+1,lease_token=gen_random_uuid(),
    lease_until=now()+make_interval(secs=>p_lease_seconds),updated_at=now() where id=r.id returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.resume_workflow(p_owner uuid,p_run uuid,p_version integer,p_data jsonb,p_expected text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r workflow_runs;
begin
  select * into r from workflow_runs where id=p_run and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if r.version<>p_version then raise exception 'version_conflict'; end if;
  if r.status in ('completed','rejected') and r.decision=p_data then return to_jsonb(r); end if;
  if r.status='queued' and r.resume_data=p_data then return to_jsonb(r); end if;
  if r.status<>p_expected then raise exception 'state_conflict'; end if;
  update workflow_runs set resume_data=p_data,status='queued',attempts=0,available_at=now(),updated_at=now()
    where id=p_run returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.commit_plan(p_owner uuid,p_run uuid,p_token uuid,p_decision jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r workflow_runs; item jsonb; idx integer; items jsonb;
begin
  select * into r from workflow_runs where id=p_run and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if r.status in ('completed','rejected') and r.decision=p_decision then return r.result; end if;
  if r.status<>'running' or r.lease_token is distinct from p_token or r.lease_until<now() then raise exception 'lease_conflict'; end if;
  if (p_decision->>'version')::integer<>r.version then raise exception 'version_conflict'; end if;
  if p_decision->>'decision'='approve' then
    for idx in select distinct value::integer from jsonb_array_elements_text(p_decision->'selected_indices') loop
      item=r.proposal->'tasks'->idx;
      if idx<0 or item is null then raise exception 'invalid_selection'; end if;
      insert into tasks(user_id,title,description,xp_value,source,run_id,proposal_index,evidence,duration_minutes)
        values(p_owner,item->>'title',item->>'description',(item->>'xp_value')::integer,'approved_plan',p_run,idx,item->>'evidence',(item->>'duration_minutes')::integer)
        on conflict(run_id,proposal_index) do nothing;
    end loop;
  elsif p_decision->>'decision'<>'reject' then raise exception 'invalid_decision'; end if;
  select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into items from tasks t where run_id=p_run and user_id=p_owner;
  update workflow_runs set decision=p_decision,result=items,status=case when p_decision->>'decision'='approve' then 'completed' else 'rejected' end,
    lease_until=null,updated_at=now() where id=p_run;
  return items;
end $$;

create or replace function public.edit_proposal(p_owner uuid,p_run uuid,p_version integer,p_proposal jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r workflow_runs;
begin
  select * into r from workflow_runs where id=p_run and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if r.status<>'awaiting_review' or r.version<>p_version then raise exception 'version_conflict'; end if;
  update workflow_runs set proposal=p_proposal,version=version+1,updated_at=now() where id=p_run returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.search_memory(p_owner uuid,p_query text,p_vector extensions.vector(768),p_model text,p_exclude uuid default null)
returns table(source_id text,entry_id uuid,content text,score double precision)
language sql stable security definer set search_path=public,extensions as $$
  select m.source_id,m.entry_id,m.content,
    (ts_rank_cd(m.search_text,plainto_tsquery('simple',p_query)) +
     case when p_vector is not null and m.embedding_model=p_model and m.embedding is not null then
       greatest(0,1-(m.embedding <=> p_vector)) else 0 end)::double precision as score
  from memory_chunks m where m.user_id=p_owner and (p_exclude is null or m.entry_id<>p_exclude)
    and (m.search_text @@ plainto_tsquery('simple',p_query) or (p_vector is not null and m.embedding_model=p_model))
  order by score desc limit 6;
$$;

create or replace function public.schedule_automations()
returns integer language plpgsql security definer set search_path=public,extensions as $$
declare rule automation_rules; r jsonb; occurrence text; n integer=0;
begin
  for rule in select * from automation_rules where enabled and next_run_at<=now() for update skip locked limit 20 loop
    occurrence='automation:'||rule.id||':'||rule.next_run_at::text;
    if rule.kind='reminder' then
      insert into automation_events(user_id,rule_id,message) values(rule.user_id,rule.id,rule.instruction);
    else
      r=create_entry_run(rule.user_id,'Scheduled '||rule.kind||': '||rule.instruction,occurrence,occurrence,'{}','UTC');
      update workflow_runs set workflow_kind=rule.kind where id=(r->>'id')::uuid;
      insert into automation_events(user_id,rule_id,run_id,message) values(rule.user_id,rule.id,(r->>'id')::uuid,'Draft queued: '||rule.name);
    end if;
    update automation_rules set next_run_at=now()+make_interval(hours=>rule.interval_hours) where id=rule.id;
    n=n+1;
  end loop;
  return n;
end $$;

do $$ declare t text; begin
  foreach t in array array['assets','workflow_runs','memory_chunks','automation_rules','automation_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;
revoke all on function public.create_entry_run(uuid,text,text,text,uuid[],text) from public,anon,authenticated;
revoke all on function public.claim_workflow(integer,integer) from public,anon,authenticated;
revoke all on function public.resume_workflow(uuid,uuid,integer,jsonb,text) from public,anon,authenticated;
revoke all on function public.commit_plan(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.search_memory(uuid,text,extensions.vector,text,uuid) from public,anon,authenticated;
revoke all on function public.schedule_automations() from public,anon,authenticated;
revoke all on function public.edit_proposal(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.create_entry_run(uuid,text,text,text,uuid[],text), public.claim_workflow(integer,integer),
  public.resume_workflow(uuid,uuid,integer,jsonb,text),public.commit_plan(uuid,uuid,uuid,jsonb),
  public.search_memory(uuid,text,extensions.vector,text,uuid),public.schedule_automations(),public.edit_proposal(uuid,uuid,integer,jsonb) to service_role;

insert into storage.buckets(id,name,public,file_size_limit) values('journal-assets','journal-assets',false,10485760)
on conflict(id) do update set public=false;
