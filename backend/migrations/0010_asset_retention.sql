create or replace function public.forget_unused_asset(p_owner uuid,p_asset uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare a assets;
begin
  select * into a from assets where id=p_asset and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if exists(select 1 from workflow_runs where user_id=p_owner and p_asset=any(asset_ids)) then raise exception 'asset_in_use'; end if;
  insert into retention_jobs(user_id,thread_prefix,storage_paths) values(p_owner,'',array[a.storage_path]);
  delete from assets where id=p_asset and user_id=p_owner;
  return true;
end $$;

create or replace function public.queue_orphan_assets()
returns integer language plpgsql security definer set search_path=public as $$
declare a assets; n integer=0;
begin
  for a in select * from assets where created_at<now()-interval '7 days' and
    not exists(select 1 from workflow_runs where assets.id=any(asset_ids)) limit 20 for update skip locked loop
    -- Recheck under the held asset lock, with a fresh statement snapshot.
    if not exists(select 1 from workflow_runs where a.id=any(asset_ids)) then
      insert into retention_jobs(user_id,thread_prefix,storage_paths,available_at) values(a.user_id,'',array[a.storage_path],now());
      delete from assets where id=a.id;
      n=n+1;
    end if;
  end loop;
  return n;
end $$;
revoke all on function public.forget_unused_asset(uuid,uuid),public.queue_orphan_assets() from public,anon,authenticated;
grant execute on function public.forget_unused_asset(uuid,uuid),public.queue_orphan_assets() to service_role;

create table if not exists public.app_schema_metadata (
  singleton boolean primary key default true check(singleton),version integer not null
);
insert into public.app_schema_metadata(singleton,version) values(true,10)
on conflict(singleton) do update set version=excluded.version;
alter table public.app_schema_metadata enable row level security;
revoke all on public.app_schema_metadata from public,anon,authenticated;
grant select on public.app_schema_metadata to service_role;
