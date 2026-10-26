alter table public.workflow_runs add column if not exists source_overrides jsonb;
alter table public.workflow_runs add column if not exists graph_revision integer not null default 1;

create or replace function public.correct_sources(p_owner uuid,p_run uuid,p_version integer,p_sources jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r workflow_runs;
begin
  select * into r from workflow_runs where id=p_run and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  if r.status not in ('awaiting_review','awaiting_clarification') or r.version<>p_version then raise exception 'version_conflict'; end if;
  update workflow_runs set source_overrides=p_sources,sources=p_sources,graph_revision=graph_revision+1,
    version=version+1,status='queued',attempts=0,proposal=null,questions=null,resume_data=null,error_code=null,
    available_at=now(),updated_at=now() where id=p_run returning * into r;
  delete from memory_chunks where entry_id=r.entry_id and user_id=p_owner;
  return to_jsonb(r);
end $$;

create or replace function public.index_memory_chunk(p_owner uuid,p_run uuid,p_revision integer,p_source text,p_content text,p_vector extensions.vector(768),p_model text)
returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare r workflow_runs;
begin
  select * into r from workflow_runs where id=p_run and user_id=p_owner for update;
  if not found or r.graph_revision<>p_revision then raise exception 'version_conflict'; end if;
  insert into memory_chunks(user_id,entry_id,source_id,content,embedding,embedding_model)
    values(p_owner,r.entry_id,p_source,p_content,p_vector,p_model)
    on conflict(entry_id,source_id) do update set content=excluded.content,embedding=excluded.embedding,embedding_model=excluded.embedding_model;
  return true;
end $$;
revoke all on function public.index_memory_chunk(uuid,uuid,integer,text,text,extensions.vector,text) from public,anon,authenticated;
grant execute on function public.index_memory_chunk(uuid,uuid,integer,text,text,extensions.vector,text) to service_role;
revoke all on function public.correct_sources(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.correct_sources(uuid,uuid,integer,jsonb) to service_role;

-- Include every previous checkpoint revision when forgetting corrected input.
create or replace function public.forget_entry(p_owner uuid,p_entry uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare r workflow_runs; a assets; paths text[]='{}'; revision integer;
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
    insert into retention_jobs(user_id,thread_prefix,storage_paths) values(p_owner,p_owner::text||':'||r.id::text,paths);
    for revision in 2..r.graph_revision loop
      insert into retention_jobs(user_id,thread_prefix) values(p_owner,p_owner::text||':'||r.id::text||':'||revision);
    end loop;
  end loop;
  delete from journal_entries where id=p_entry and user_id=p_owner;
  return true;
end $$;
