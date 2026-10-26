-- Checkpoints contain journal context; never expose them via the public schema.
create schema if not exists lifescript_private;
revoke all on schema lifescript_private from public,anon,authenticated;
grant usage,create on schema lifescript_private to service_role;

create or replace function public.queue_account_retention()
returns trigger language plpgsql security definer set search_path=public as $$
declare r workflow_runs; a assets; revision integer;
begin
  for r in select * from workflow_runs where user_id=old.id loop
    insert into retention_jobs(user_id,thread_prefix) values(old.id,old.id::text||':'||r.id::text);
    for revision in 2..r.graph_revision loop
      insert into retention_jobs(user_id,thread_prefix) values(old.id,old.id::text||':'||r.id::text||':'||revision);
    end loop;
  end loop;
  for a in select * from assets where user_id=old.id loop
    insert into retention_jobs(user_id,thread_prefix,storage_paths) values(old.id,'',array[a.storage_path]);
  end loop;
  return old;
end $$;
drop trigger if exists lifescript_account_retention on public.users;
create trigger lifescript_account_retention before delete on public.users for each row execute function public.queue_account_retention();
