-- Goals and projects share an owner-enforced hierarchy. No existing data is changed.
create table public.objectives (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null check(length(trim(title)) between 1 and 255),
  kind text not null check(kind in ('goal','project')),
  parent_id uuid,
  status text not null default 'active' check(status in ('active','completed')),
  created_at timestamptz not null default now(),
  unique(user_id,id),
  foreign key(user_id,parent_id) references public.objectives(user_id,id),
  check(parent_id is null or (kind='project' and parent_id<>id))
);
create index objectives_owner on public.objectives(user_id,created_at desc);
alter table public.objectives enable row level security;
revoke all on public.objectives from public,anon,authenticated;
grant all on public.objectives to service_role;
-- Carry existing onboarding goals forward without copying demo data. Deterministic
-- UUIDs make repeated profile writes harmless; renamed/closed goals stay independent.
insert into public.objectives(id,user_id,title,kind)
select md5(user_id::text || ':onboarding:' || title)::uuid,user_id,title,'goal'
from (select distinct u.id as user_id,trim(g.title) as title
      from public.users u cross join lateral unnest(u.macro_goals) g(title)
      where length(trim(g.title)) between 1 and 255) goals
on conflict(id) do nothing;
create function public.sync_onboarding_objectives()
returns trigger language plpgsql security definer set search_path=public as $$
declare goal text;
begin
  foreach goal in array new.macro_goals loop
    if length(trim(goal)) between 1 and 255 then
      insert into objectives(id,user_id,title,kind)
      values(md5(new.id::text || ':onboarding:' || trim(goal))::uuid,new.id,trim(goal),'goal')
      on conflict(id) do nothing;
    end if;
  end loop;
  return new;
end $$;
revoke all on function public.sync_onboarding_objectives() from public,anon,authenticated;
create trigger lifescript_onboarding_objectives after insert or update of macro_goals on public.users
for each row execute function public.sync_onboarding_objectives();
alter table public.tasks add column objective_id uuid;
alter table public.tasks add constraint tasks_owned_objective foreign key(user_id,objective_id)
  references public.objectives(user_id,id);
create index tasks_objective on public.tasks(user_id,objective_id);
update public.app_schema_metadata set version=12 where singleton=true;
