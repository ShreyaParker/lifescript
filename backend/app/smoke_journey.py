"""Opt-in real-service check, excluded from pytest discovery.

python -m app.smoke_journey --allow-development-writes
Creates two temporary, confirmed Auth accounts without sending emails. Only
accounts created by this invocation are removed. Uses synthetic text only.
"""
import argparse
import json
import secrets
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient
from langgraph.checkpoint.sqlite import SqliteSaver
from supabase import create_client
from supabase.lib.client_options import SyncClientOptions
import httpx

from app.core.config import settings
from app.core.db import get_db
from app.core.tls import tls_context
from app.main import app
from app.services.model_provider import ModelProvider, get_model_provider
from app.services.planning_graph import build_graph
from app.services.workflow_repository import WorkflowRepository
from app.worker import process_run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-development-writes', action='store_true')
    parser.add_argument('--fixture-generation', action='store_true', help='Use explicit synthetic generation fixtures to test the real database when model quota is unavailable; not AI verification')
    args = parser.parse_args()
    if not args.allow_development_writes:
        parser.error('Explicit --allow-development-writes is required')
    report = {'steps': [], 'passed': False, 'cleanup': False, 'generation': 'fixture' if args.fixture_generation else 'real_model'}
    created = []
    db = get_db()
    repo = WorkflowRepository(db)
    provider = ModelProvider()
    if args.fixture_generation:
        from app.schemas.workflow import Understanding, Plan, ProposedTask
        from app.services.assistant import Answer, Evidence

        class FixtureProvider(ModelProvider):
            # Only this explicitly invoked manual check substitutes generation.
            # Embeddings, Auth, SQL/RPCs, ownership and checkpoints remain real.
            def structured(self, schema, system, text, **kwargs):
                if schema is Understanding:
                    return Understanding(intent='action', facts=['Synthetic future intention'])
                payload = json.loads(text.split('\n', 1)[0])
                source = payload['sources'][0]
                if schema is Plan:
                    return Plan(tasks=[ProposedTask(title='Review Python notes', source_id=source['source_id'],
                        evidence=source['content'], duration_minutes=20)], coaching_insight='Synthetic test proposal')
                if schema is Answer:
                    return Answer(answer='Synthetic fixture response for database verification.',
                        citations=[Evidence(source_id=source['source_id'], quote=source['content'][:600])])
                raise ValueError('Unexpected fixture schema')

        provider = FixtureProvider()
        app.dependency_overrides[get_model_provider] = lambda: provider
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)

    def checked(response, expected):
        if response.status_code != expected:
            report['http_failure'] = response.status_code
            raise RuntimeError('unexpected_http_status')
        return response.json()

    def account():
        email = f'lifescript-smoke-{uuid4().hex}@example.com'
        password = secrets.token_urlsafe(32)
        user = db.auth.admin.create_user({'email': email, 'password': password, 'email_confirm': True}).user
        created.append(str(user.id))
        # Isolated auth client avoids replacing the backend's service-role session.
        with httpx.Client(verify=tls_context(), timeout=30) as transport:
            auth = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY,
                options=SyncClientOptions(auto_refresh_token=False, persist_session=False, httpx_client=transport))
            session = auth.auth.sign_in_with_password({'email': email, 'password': password}).session
            return str(user.id), {'Authorization': f'Bearer {session.access_token}'}

    try:
        if db.table('app_schema_metadata').select('version').eq('singleton', True).execute().data[0]['version'] != 12:
            raise RuntimeError('schema_not_ready')
        owner, headers = account()
        _, other_headers = account()
        report['steps'].append('two_real_authenticated_temporary_accounts')
        with TestClient(app, raise_server_exceptions=False) as api, tempfile.TemporaryDirectory(prefix='smoke-', dir=settings.DATA_DIR) as temp:
            with SqliteSaver.from_conn_string(str(Path(temp) / 'checkpoints.sqlite')) as saver:
                graph = build_graph(provider, saver)

                def advance(run_id):
                    # Target only this invocation's run, so unrelated queued work is untouched.
                    run = db.table('workflow_runs').update({'status': 'running', 'lease_token': str(uuid4()),
                        'lease_until': (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()})\
                        .eq('id', run_id).eq('user_id', owner).eq('status', 'queued').execute().data
                    if not run:
                        raise RuntimeError('run_not_claimable')
                    process_run(repo, run[0], provider, graph)

                checked(api.post('/onboarding/setup', headers=headers, json={
                    'inner_landscape': 'Synthetic development test', 'subconscious_rhythm': 'Evenings',
                    'intellectual_footprint': 'Python notes', 'core_north_star': 'Learn Python'}), 200)
                goals = checked(api.get('/v1/objectives', headers=headers), 200)
                assert len(goals) == 1 and goals[0]['title'] == 'Learn Python'
                project = checked(api.post('/v1/objectives', headers=headers, json={
                    'id': str(uuid4()), 'title': 'Practice Python', 'kind': 'project', 'parent_id': goals[0]['id']}), 201)
                report['steps'].append('onboarding_goal_trigger_and_project_creation')
                key = str(uuid4())
                payload = {'content': 'I want to review my Python notes for twenty minutes tomorrow.'}
                entry_headers = {**headers, 'Idempotency-Key': key}
                run = checked(api.post('/v1/entries', headers=entry_headers, json=payload), 201)
                replay = checked(api.post('/v1/entries', headers=entry_headers, json=payload), 201)
                assert replay['id'] == run['id']
                assert checked(api.get('/tasks', headers=headers), 200) == []
                report['steps'].append('atomic_journal_save_idempotency_no_unapproved_tasks')
                advance(run['id'])
                review = checked(api.get(f"/v1/runs/{run['id']}", headers=headers), 200)
                if review['status'] == 'awaiting_clarification':
                    checked(api.post(f"/v1/runs/{run['id']}/clarification", headers=headers,
                        json={'answer': 'A short review of my Python notes; no scheduling or external action is needed.'}), 202)
                    advance(run['id'])
                    review = checked(api.get(f"/v1/runs/{run['id']}", headers=headers), 200)
                assert review['status'] == 'awaiting_review' and review['proposal']['tasks']
                report['steps'].append('fixture_extraction_langgraph_review_and_checkpoint' if args.fixture_generation else 'real_gemini_extraction_langgraph_review_and_checkpoint')
                assert checked(api.get('/tasks', headers=headers), 200) == []
                checked(api.post(f"/v1/runs/{run['id']}/decision", headers=headers,
                    json={'decision': 'approve', 'selected_indices': [0], 'version': review['version']}), 202)
                advance(run['id'])
                tasks = checked(api.get('/tasks', headers=headers), 200)
                assert len(tasks) == 1
                task = tasks[0]
                checked(api.patch(f"/tasks/{task['id']}", headers=headers,
                    json={'title': task['title'], 'description': task['description'], 'objective_id': project['id']}), 200)
                checked(api.patch(f"/tasks/{task['id']}/toggle", headers=headers, json={'is_completed': True}), 200)
                assert checked(api.get('/tasks', headers=headers), 200)[0]['status'] == 'completed'
                report['steps'].append('approved_task_commit_project_link_and_completion')
                assert checked(api.get('/tasks', headers=other_headers), 200) == []
                assert checked(api.get('/v1/objectives', headers=other_headers), 200) == []
                assert api.get(f"/v1/runs/{run['id']}", headers=other_headers).status_code == 404
                assert api.patch(f"/tasks/{task['id']}/toggle", headers=other_headers, json={'is_completed': False}).status_code == 404
                assert checked(api.get('/v1/memory?q=Python', headers=other_headers), 200) == []
                report['steps'].append('two_account_task_goal_run_memory_isolation')
                memory = checked(api.get('/v1/memory?q=Python', headers=headers), 200)
                assert any(row['entry_id'] == run['entry_id'] for row in memory)
                report['steps'].append('real_postgres_memory_retrieval')
                answer = checked(api.post('/v1/assistant', headers=headers,
                    json={'question': 'What did I write about reviewing Python notes?'}), 200)
                assert answer['citations']
                report['steps'].append('fixture_assistant_real_retrieval_and_citation_validation' if args.fixture_generation else 'real_grounded_assistant_with_validated_citations')
                report['passed'] = True
    except Exception as exc:
        report['error_type'] = type(exc).__name__
        report['error_code'] = getattr(exc, 'code', None)
    finally:
        app.dependency_overrides.pop(get_model_provider, None)
        cleanup_errors = []
        for user_id in reversed(created):
            try:
                db.auth.admin.delete_user(user_id)
            except Exception as exc:
                cleanup_errors.append(type(exc).__name__)
        report['cleanup'] = not cleanup_errors
        if cleanup_errors:
            report['cleanup_errors'] = cleanup_errors
        (settings.DATA_DIR / 'service-smoke.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print(json.dumps(report))
    if not report['passed'] or not report['cleanup']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
