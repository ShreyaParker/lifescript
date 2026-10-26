from uuid import uuid4

import pytest

from app.core.security import get_current_user
from app.main import app
from app.services.assistant import Answer, Evidence, ask
from app.services.model_provider import get_model_provider
from conftest import OWNER, OTHER


def test_objective_creation_replay_conflict_and_owner(client, db):
    payload = {"id": str(uuid4()), "title": "Learn RAG", "kind": "goal"}
    first = client.post('/v1/objectives', json=payload)
    assert first.status_code == 201
    assert client.post('/v1/objectives', json=payload).json()['id'] == first.json()['id']
    assert len(db.rows['objectives']) == 1
    assert client.post('/v1/objectives', json={**payload, 'title': 'Different'}).status_code == 409
    db.rows['objectives'].append({'id': str(uuid4()), 'user_id': OTHER, 'kind': 'goal'})
    assert len(client.get('/v1/objectives').json()) == 1


def test_project_parent_and_task_assignment_reject_foreign_owner(client, db):
    foreign = str(uuid4())
    db.rows['objectives'] = [{'id': foreign, 'user_id': OTHER, 'kind': 'goal'}]
    assert client.post('/v1/objectives', json={'id': str(uuid4()), 'title': 'Project', 'kind': 'project', 'parent_id': foreign}).status_code == 404
    assert client.patch(f'/tasks/{uuid4()}', json={'title': 'Study', 'objective_id': foreign}).status_code == 404
    assert client.post('/v1/objectives', json={'id': str(uuid4()), 'title': ' ', 'kind': 'goal'}).status_code == 422


def test_project_hierarchy_and_owned_task_edit(client, db):
    goal, project, task = str(uuid4()), str(uuid4()), str(uuid4())
    assert client.post('/v1/objectives', json={'id': goal, 'title': 'Career', 'kind': 'goal'}).status_code == 201
    assert client.post('/v1/objectives', json={'id': project, 'title': 'RAG', 'kind': 'project', 'parent_id': goal}).status_code == 201
    assert client.post('/v1/objectives', json={'id': str(uuid4()), 'title': 'Nested', 'kind': 'project', 'parent_id': project}).status_code == 422
    db.rows['tasks'] = [{'id': task, 'user_id': OWNER, 'title': 'Old'}, {'id': str(uuid4()), 'user_id': OTHER}]
    assert client.patch(f'/tasks/{task}', json={'title': 'Chunking', 'objective_id': project}).json()['objective_id'] == project
    assert client.patch(f'/tasks/{db.rows["tasks"][1]["id"]}', json={'title': 'Attack'}).status_code == 404
    assert client.patch(f'/v1/objectives/{project}', json={'status': 'completed'}).json()['status'] == 'completed'


class Provider:
    embedding_model = 'test:768'

    def __init__(self, invalid=False):
        self.invalid = invalid
        self.calls = 0

    def embed(self, text):
        raise RuntimeError('embedding unavailable')

    def structured(self, schema, system, text):
        self.calls += 1
        return Answer(answer='You wrote about chunking.', citations=[Evidence(source_id='memory:0', quote='invented' if self.invalid else 'Practice chunking')])


def test_assistant_keyword_fallback_citations_and_no_writes(db):
    db.rpc_result = [{'entry_id': str(uuid4()), 'content': 'Practice chunking'}]
    result = ask(db, Provider(), OWNER, 'What did I plan?')
    assert result['retrieval'] == 'keyword'
    assert result['citations'][0]['quote'] == 'Practice chunking'
    assert db.rpc_calls[0][1]['p_owner'] == OWNER
    assert all(action == 'select' and ('user_id', 'eq', OWNER) in filters for _, action, filters, _ in db.calls)
    with pytest.raises(ValueError, match='unsupported_assistant_evidence'):
        ask(db, Provider(invalid=True), OWNER, 'Question')


def test_assistant_without_context_does_not_call_model(db):
    db.rpc_result = []
    provider = Provider()
    assert ask(db, provider, OWNER, 'Question')['citations'] == []
    assert provider.calls == 0


def test_assistant_api_auth_quota_and_safe_failure(client, db):
    provider = Provider(invalid=True)
    app.dependency_overrides[get_model_provider] = lambda: provider
    db.rpc_result = [{'content': 'Practice chunking'}]
    response = client.post('/v1/assistant', json={'question': 'What next?'})
    assert response.status_code == 503
    assert db.rpc_calls[0] == ('reserve_inline_model_call', {'p_owner': OWNER})
    assert client.post('/v1/assistant', json={'question': ' '}).status_code == 422
    del app.dependency_overrides[get_current_user]
    assert client.post('/v1/assistant', json={'question': 'Question'}).status_code == 401
