create table if not exists public.inline_model_usage (
  user_id uuid not null references public.users(id) on delete cascade,
  window_start timestamptz not null,hits integer not null,
  primary key(user_id,window_start)
);
alter table public.inline_model_usage enable row level security;
revoke all on public.inline_model_usage from public,anon,authenticated;
grant all on public.inline_model_usage to service_role;
create or replace function public.reserve_inline_model_call(p_owner uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  insert into users(id) values(p_owner) on conflict(id) do nothing;
  insert into inline_model_usage(user_id,window_start,hits) values(p_owner,date_trunc('hour',now()),1)
    on conflict(user_id,window_start) do update set hits=inline_model_usage.hits+1 returning hits into n;
  if n>10 then raise exception 'quota_exceeded'; end if;
  delete from inline_model_usage where user_id=p_owner and window_start<now()-interval '7 days';
  return true;
end $$;
revoke all on function public.reserve_inline_model_call(uuid) from public,anon,authenticated;
grant execute on function public.reserve_inline_model_call(uuid) to service_role;
