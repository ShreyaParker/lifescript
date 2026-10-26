from pathlib import Path
from pglast import parse_sql
from pglast.parser import parse_plpgsql_json
import pytest


@pytest.mark.parametrize("migration",sorted((Path(__file__).parents[1]/"migrations").glob("*.sql")),ids=lambda path:path.name)
def test_migration_syntax(migration):
    sql=migration.read_text(encoding="utf-8")
    assert parse_sql(sql)
    # Procedural parser resolves only pg_catalog/public, not extension parameter types.
    # This substitution is for syntax checking only; integration tests use original SQL.
    parse_plpgsql_json(sql.replace("extensions.vector(768)","public.text").replace("extensions.vector","public.text"))
