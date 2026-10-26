-- Staging metadata first keeps interrupted object-store writes discoverable.
alter table public.assets add column if not exists status text not null default 'ready' check(status in ('pending','ready'));
update public.app_schema_metadata set version=11 where singleton=true;
