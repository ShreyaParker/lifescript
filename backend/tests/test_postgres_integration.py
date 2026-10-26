"""Opt-in against a disposable local *_test database; every test rolls back DDL/data."""
import json
import os
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.types.json import Jsonb
import pytest

URL = os.getenv("LIFESCRIPT_TEST_DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not URL, reason="Disposable local PostgreSQL/pgvector not configured")


@pytest.fixture
def postgres():
    params = conninfo_to_dict(URL)
    if params.get("host") not in ("localhost", "127.0.0.1", "postgres") or not params.get("dbname", "").endswith("_test"):
        pytest.fail("Integration tests only accept a local database with a _test suffix")
    conn = psycopg.connect(URL)
    try:
        conn.execute("create schema if not exists auth; create schema if not exists storage; create schema if not exists extensions")
        conn.execute("""do $$ begin
          if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
          if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
          if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role bypassrls; end if;
        end $$""")
        conn.execute("create table if not exists auth.users(id uuid primary key,email text)")
        conn.execute("create table if not exists storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint)")
        conn.execute("create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$")
        conn.execute("grant usage on schema auth to authenticated")
        for migration in sorted((Path(__file__).parents[1]/"migrations").glob("*.sql")):
            conn.execute(migration.read_text(encoding="utf-8"))
        yield conn
    finally:
        conn.rollback()
        conn.close()


def seed(conn):
    owner, other = uuid4(), uuid4()
    conn.execute("insert into auth.users(id,email) values(%s,'first@example.test'),(%s,'second@example.test')", (owner,other))
    return owner,other


def test_objectives_enforce_owner_foreign_keys_and_client_denial(postgres):
    owner, other = seed(postgres)
    goal, project, task = uuid4(), uuid4(), uuid4()
    postgres.execute("insert into objectives(id,user_id,title,kind) values(%s,%s,'Career','goal')", (goal, owner))
    postgres.execute("insert into objectives(id,user_id,title,kind,parent_id) values(%s,%s,'RAG','project',%s)", (project, owner, goal))
    postgres.execute("insert into tasks(id,user_id,title,objective_id) values(%s,%s,'Chunking',%s)", (task, owner, project))
    with pytest.raises(psycopg.errors.ForeignKeyViolation):
        with postgres.transaction():
            postgres.execute("insert into tasks(user_id,title,objective_id) values(%s,'Foreign',%s)", (other, project))
    with pytest.raises(psycopg.errors.ForeignKeyViolation):
        with postgres.transaction():
            postgres.execute("insert into objectives(id,user_id,title,kind,parent_id) values(%s,%s,'Foreign','project',%s)", (uuid4(), other, goal))
    postgres.execute("set local role authenticated")
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with postgres.transaction():
            postgres.execute("select * from objectives")
    postgres.execute("reset role")


def test_onboarding_goals_sync_without_duplicates_or_reverting_renames(postgres):
    owner, _ = seed(postgres)
    postgres.execute("update users set macro_goals=array['Learn RAG'] where id=%s", (owner,))
    postgres.execute("update users set macro_goals=array['Learn RAG'] where id=%s", (owner,))
    assert postgres.execute("select count(*) from objectives where user_id=%s", (owner,)).fetchone()[0] == 1
    postgres.execute("update objectives set title='Learn retrieval',status='completed' where user_id=%s", (owner,))
    postgres.execute("update users set macro_goals=array['Learn RAG'] where id=%s", (owner,))
    assert postgres.execute("select title,status from objectives where user_id=%s", (owner,)).fetchone() == ('Learn retrieval', 'completed')


def create(conn,owner,key="request-key-001",digest="digest-001"):
    return conn.execute("select public.create_entry_run(%s,%s,%s,%s,'{}','UTC')",
                        (owner,"I want to review notes",key,digest)).fetchone()[0]


def test_transactional_create_and_idempotency(postgres):
    owner,_=seed(postgres)
    first=create(postgres,owner)
    assert create(postgres,owner)["id"]==first["id"]
    with pytest.raises(psycopg.Error,match="idempotency_conflict"):
        with postgres.transaction(): create(postgres,owner,digest="different")
    assert postgres.execute("select count(*) from journal_entries").fetchone()[0]==1


def test_client_cannot_call_privileged_rpc_and_profile_is_owner_scoped(postgres):
    owner,other=seed(postgres)
    postgres.execute("select set_config('request.jwt.claim.sub',%s,true)",(str(owner),))
    postgres.execute("set local role authenticated")
    assert postgres.execute("select id from public.users").fetchall()==[(owner,)]
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with postgres.transaction(): create(postgres,other)
    postgres.execute("reset role")


def test_atomic_approval_and_replay(postgres):
    owner,_=seed(postgres)
    run=create(postgres,owner)
    proposal={"tasks":[{"title":"Review notes","description":"Study","xp_value":20,"duration_minutes":20,"evidence":"review notes"}],"coaching_insight":"Start small"}
    postgres.execute("update workflow_runs set proposal=%s,status='awaiting_review' where id=%s",(Jsonb(proposal),run["id"]))
    decision={"decision":"approve","selected_indices":[0],"version":1}
    postgres.execute("select resume_workflow(%s,%s,1,%s,'awaiting_review')",(owner,run["id"],Jsonb(decision)))
    claimed=postgres.execute("select claim_workflow(900,3)").fetchone()[0]
    params=(owner,run["id"],claimed["lease_token"],Jsonb(decision))
    first=postgres.execute("select commit_plan(%s,%s,%s,%s)",params).fetchone()[0]
    second=postgres.execute("select commit_plan(%s,%s,%s,%s)",params).fetchone()[0]
    assert first==second and len(first)==1
    assert postgres.execute("select count(*) from tasks").fetchone()[0]==1


def test_scheduler_is_once_per_occurrence_and_pause_respected(postgres):
    owner,_=seed(postgres)
    postgres.execute("insert into automation_rules(user_id,name,kind,instruction,interval_hours,enabled) values(%s,'Reminder','reminder','Review',24,false)",(owner,))
    assert postgres.execute("select schedule_automations()").fetchone()[0]==0
    postgres.execute("update automation_rules set enabled=true")
    assert postgres.execute("select schedule_automations()").fetchone()[0]==1
    assert postgres.execute("select schedule_automations()").fetchone()[0]==0
    assert postgres.execute("select count(*) from automation_events").fetchone()[0]==1


def test_forget_cascades_active_memory_and_queues_checkpoint_cleanup(postgres):
    owner,_=seed(postgres)
    run=create(postgres,owner)
    postgres.execute("insert into memory_chunks(user_id,entry_id,source_id,content) values(%s,%s,'source','private synthetic')",(owner,run["entry_id"]))
    assert postgres.execute("select forget_entry(%s,%s)",(owner,run["entry_id"])).fetchone()[0]
    assert postgres.execute("select count(*) from memory_chunks").fetchone()[0]==0
    assert postgres.execute("select count(*) from workflow_runs").fetchone()[0]==0
    assert postgres.execute("select count(*) from retention_jobs").fetchone()[0]==1


def test_inline_provider_quota_is_transactional(postgres):
    owner,_=seed(postgres)
    for _ in range(10):
        assert postgres.execute("select reserve_inline_model_call(%s)",(owner,)).fetchone()[0]
    with pytest.raises(psycopg.Error,match="quota_exceeded"):
        with postgres.transaction():
            postgres.execute("select reserve_inline_model_call(%s)",(owner,))
    assert postgres.execute("select hits from inline_model_usage where user_id=%s",(owner,)).fetchone()[0]==10


def test_pausing_automation_cancels_queued_generation(postgres):
    owner,_=seed(postgres)
    rule={"name":"Daily plan","kind":"daily_plan","instruction":"Review goals","interval_hours":24,"enabled":True}
    row=postgres.execute("select create_automation(%s,%s)",(owner,Jsonb(rule))).fetchone()[0]
    assert postgres.execute("select schedule_automations()").fetchone()[0]==1
    postgres.execute("select set_automation_enabled(%s,%s,false)",(owner,row["id"]))
    assert postgres.execute("select status from workflow_runs").fetchone()[0]=="cancelled"
    assert postgres.execute("select claim_workflow(900,3)").fetchone()[0] is None


def test_pending_upload_cannot_enter_a_workflow(postgres):
    owner,_=seed(postgres)
    asset=uuid4()
    payload={'id':str(asset),'filename':'notes.pdf','mime_type':'application/pdf','storage_path':f'{owner}/{asset}','size_bytes':100}
    row=postgres.execute('select register_asset(%s,%s)',(owner,Jsonb(payload))).fetchone()[0]
    assert row['status']=='pending'
    with pytest.raises(psycopg.Error,match='asset_not_found'):
        with postgres.transaction():
            postgres.execute("select create_entry_run(%s,'Review notes','asset-key','digest',%s,'UTC')",(owner,[asset]))
    assert postgres.execute('select count(*) from journal_entries').fetchone()[0]==0
    postgres.execute("update assets set status='ready' where id=%s",(asset,))
    assert postgres.execute("select create_entry_run(%s,'Review notes','asset-key','digest',%s,'UTC')",(owner,[asset])).fetchone()[0]['asset_ids']==[str(asset)]
