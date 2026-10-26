create or replace function public.register_asset(p_owner uuid,p_asset jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare a assets; files integer; bytes bigint;
begin
  insert into users(id) values(p_owner) on conflict(id) do nothing;
  perform 1 from users where id=p_owner for update;
  select count(*),coalesce(sum(size_bytes),0) into files,bytes from assets where user_id=p_owner;
  if files>=50 or bytes+(p_asset->>'size_bytes')::integer>104857600 then raise exception 'upload_quota_exceeded'; end if;
  insert into assets(id,user_id,filename,mime_type,storage_path,size_bytes,status)
    values((p_asset->>'id')::uuid,p_owner,p_asset->>'filename',p_asset->>'mime_type',p_asset->>'storage_path',(p_asset->>'size_bytes')::integer,'pending')
    returning * into a;
  return to_jsonb(a);
end $$;
revoke all on function public.register_asset(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.register_asset(uuid,jsonb) to service_role;
