from copy import deepcopy
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.db import get_db
from app.core.security import get_current_user
from app.main import app

OWNER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"


class Query:
    def __init__(self, db, table):
        self.db, self.table = db, table
        self.filters, self.action, self.value = [], "select", None
        self.bounds = None

    def select(self, *args, **kwargs): return self
    def order(self, *args, **kwargs): return self
    def limit(self, *args): return self
    def range(self, start, end): self.bounds = (start, end); return self
    def eq(self, key, value): self.filters.append((key, "eq", value)); return self
    def gte(self, key, value): self.filters.append((key, "gte", value)); return self
    def lt(self, key, value): self.filters.append((key, "lt", value)); return self
    def update(self, value): self.action, self.value = "update", value; return self
    def insert(self, value): self.action, self.value = "insert", value; return self
    def upsert(self, value, **kwargs): self.action, self.value = "upsert", value; return self
    def delete(self): self.action = "delete"; return self

    def execute(self):
        if self.db.fail:
            raise RuntimeError("PRIVATE_SENTINEL database error")
        self.db.calls.append((self.table, self.action, self.filters, self.value))
        rows = self.db.rows.setdefault(self.table, [])
        if self.action in ("insert", "upsert"):
            values = self.value if isinstance(self.value, list) else [self.value]
            result = []
            for item in values:
                match = next((row for row in rows if row.get("id") == item.get("id") and item.get("id")), None)
                if match and self.action == "upsert": match.update(item); result.append(match)
                else:
                    row = {"id": str(uuid4()), **item}; rows.append(row); result.append(row)
            return SimpleNamespace(data=deepcopy(result))
        selected = [row for row in rows if all(
            row.get(key) == value if op == "eq" else
            row.get(key, "") >= value if op == "gte" else row.get(key, "") < value
            for key, op, value in self.filters)]
        if self.bounds: selected = selected[self.bounds[0]:self.bounds[1]+1]
        if self.action == "update":
            for row in selected: row.update(self.value)
        if self.action == "delete":
            for row in selected: rows.remove(row)
        return SimpleNamespace(data=deepcopy(selected))


class FakeDB:
    def __init__(self):
        self.rows, self.calls, self.rpc_calls = {}, [], []
        self.fail = False
        self.rpc_result = {}
        self.storage=FakeStorage()
    def table(self, name): return Query(self, name)
    def rpc(self, name, payload):
        self.rpc_calls.append((name, payload))
        if name=='register_asset':
            self.rows.setdefault('assets',[]).append({'user_id':payload['p_owner'],**payload['p_asset'],'status':'pending'})
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=self.rpc_result))


class FakeStorage:
    def __init__(self): self.objects={}; self.fail=False
    def from_(self,bucket): return self
    def upload(self,path,data,**kwargs):
        if self.fail: raise RuntimeError('simulated storage interruption')
        self.objects[path]=data
    def download(self,path): return self.objects[path]
    def remove(self,paths):
        for path in paths: self.objects.pop(path,None)


@pytest.fixture
def db(): return FakeDB()


@pytest.fixture
def client(db):
    app.dependency_overrides[get_current_user] = lambda: OWNER
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
    app.dependency_overrides.clear()
