-- Durable deferred cleanup survives API/worker restarts and failed storage calls.
create table if not exists public.retention_jobs (
  id uuid primary key default gen_random_uuid(), user_id uuid not null,
  thread_prefix text not null, storage_paths text[] not null default '{}',
  available_at timestamptz not null default now()+interval '1 hour',
  created_at timestamptz not null default now()
);
alter table public.retention_jobs enable row level security;
revoke all on public.retention_jobs from public,anon,authenticated;
grant all on public.retention_jobs to service_role;

create or replace function public.forget_entry(p_owner uuid,p_entry uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare r workflow_runs; a assets; paths text[]='{}';
begin
  perform 1 from journal_entries where id=p_entry and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  for r in select * from workflow_runs where entry_id=p_entry and user_id=p_owner loop
    for a in select * from assets where id=any(r.asset_ids) and user_id=p_owner for update loop
      if not exists(select 1 from workflow_runs where id<>r.id and a.id=any(asset_ids)) then
        paths=array_append(paths,a.storage_path);
        delete from assets where id=a.id and user_id=p_owner;
      end if;
    end loop;
    insert into retention_jobs(user_id,thread_prefix,storage_paths)
      values(p_owner,p_owner::text||':'||r.id::text,paths);
  end loop;
  delete from journal_entries where id=p_entry and user_id=p_owner;
  return true;
end $$;
revoke all on function public.forget_entry(uuid,uuid) from public,anon,authenticated;
grant execute on function public.forget_entry(uuid,uuid) to service_role;
