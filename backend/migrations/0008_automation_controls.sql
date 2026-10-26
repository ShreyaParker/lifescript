create or replace function public.create_automation(p_owner uuid,p_rule jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r automation_rules;
begin
  insert into users(id) values(p_owner) on conflict(id) do nothing;
  perform 1 from users where id=p_owner for update;
  if (select count(*) from automation_rules where user_id=p_owner)>=20 then raise exception 'rule_quota_exceeded'; end if;
  insert into automation_rules(user_id,name,kind,instruction,interval_hours,enabled)
    values(p_owner,p_rule->>'name',p_rule->>'kind',p_rule->>'instruction',(p_rule->>'interval_hours')::integer,(p_rule->>'enabled')::boolean)
    returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.set_automation_enabled(p_owner uuid,p_rule uuid,p_enabled boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r automation_rules;
begin
  select * into r from automation_rules where id=p_rule and user_id=p_owner for update;
  if not found then raise exception 'not_found'; end if;
  update automation_rules set enabled=p_enabled where id=p_rule returning * into r;
  if not p_enabled then
    update workflow_runs set status='cancelled',lease_token=null,lease_until=null,updated_at=now()
    where user_id=p_owner and status in ('queued','running') and id in
      (select run_id from automation_events where rule_id=p_rule and user_id=p_owner);
  end if;
  return to_jsonb(r);
end $$;

create or replace function public.schedule_automations()
returns integer language plpgsql security definer set search_path=public,extensions as $$
declare rule automation_rules; r jsonb; occurrence text; n integer=0;
begin
  for rule in select * from automation_rules where enabled and next_run_at<=now() for update skip locked limit 20 loop
    occurrence='automation:'||rule.id||':'||rule.next_run_at::text;
    begin
      if rule.kind='reminder' then
        insert into automation_events(user_id,rule_id,message) values(rule.user_id,rule.id,rule.instruction);
      else
        r=create_entry_run(rule.user_id,'Scheduled '||rule.kind||': '||rule.instruction,occurrence,occurrence,'{}','UTC');
        update workflow_runs set workflow_kind=rule.kind where id=(r->>'id')::uuid;
        insert into automation_events(user_id,rule_id,run_id,message) values(rule.user_id,rule.id,(r->>'id')::uuid,'Draft queued: '||rule.name);
      end if;
      update automation_rules set next_run_at=now()+make_interval(hours=>rule.interval_hours) where id=rule.id;
      n=n+1;
    exception when raise_exception then
      if sqlerrm='quota_exceeded' then
        update automation_rules set next_run_at=now()+interval '1 hour' where id=rule.id;
        insert into automation_events(user_id,rule_id,message) values(rule.user_id,rule.id,'Draft postponed: hourly processing limit reached.');
      else raise;
      end if;
    end;
  end loop;
  return n;
end $$;
revoke all on function public.create_automation(uuid,jsonb),public.set_automation_enabled(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.create_automation(uuid,jsonb),public.set_automation_enabled(uuid,uuid,boolean) to service_role;
