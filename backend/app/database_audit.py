"""Schema audit, ordered SQL bundle, or target-checked additive migration 0012.

From backend: python -m app.database_audit
Or: python -m app.database_audit --bundle
After reviewing version-11 audit: python -m app.database_audit --apply-objectives
Uses LIFESCRIPT_DATABASE_URL from the ignored .env. Outputs no credentials or row contents.
"""
import argparse
import json
from pathlib import Path
from urllib.parse import urlparse

import psycopg
from psycopg.conninfo import conninfo_to_dict
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class AuditSettings(BaseSettings):
    LIFESCRIPT_DATABASE_URL: str = Field(default="", repr=False)
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


def audit(connection):
    result = {"tables": {}, "schema_version": None, "read_only": True}
    tables = connection.execute("""select table_name from information_schema.tables
        where table_schema='public' and table_type='BASE TABLE' order by table_name""").fetchall()
    for (table,) in tables:
        columns = connection.execute("""select column_name,data_type,is_nullable from information_schema.columns
            where table_schema='public' and table_name=%s order by ordinal_position""", (table,)).fetchall()
        result["tables"][table] = {"columns": [{"name": n, "type": t, "nullable": null == 'YES'} for n, t, null in columns]}
        policies = connection.execute("select policyname,permissive,roles,cmd from pg_policies where schemaname='public' and tablename=%s", (table,)).fetchall()
        result["tables"][table]["policies"] = [{"name": n, "permissive": p, "roles": r, "command": c} for n, p, r, c in policies]
        result["tables"][table]["rls"] = connection.execute("select relrowsecurity from pg_class where oid=to_regclass(%s)", ('public.' + table,)).fetchone()[0]
    if "app_schema_metadata" in result["tables"]:
        row = connection.execute("select version from public.app_schema_metadata where singleton=true").fetchone()
        result["schema_version"] = row[0] if row else None
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", action="store_true")
    parser.add_argument("--apply-objectives", action="store_true", help="Apply only additive migration 0012 to the configured, reconciled Supabase version-11 development project")
    args = parser.parse_args()
    output = Path('.local')
    output.mkdir(exist_ok=True)
    if args.bundle:
        migrations = sorted((Path(__file__).resolve().parents[1] / 'migrations').glob('*.sql'))
        content = '-- REVIEW AND RECONCILE EXISTING DEVELOPMENT SCHEMA BEFORE EXECUTION.\n'
        content += '\n'.join(f'\n-- {p.name}\n{p.read_text(encoding="utf-8")}' for p in migrations)
        (output / 'ordered_migrations.sql').write_text(content, encoding='utf-8')
        print(f'Wrote {len(migrations)} ordered migrations to .local/ordered_migrations.sql; nothing executed.')
        return
    url = AuditSettings().LIFESCRIPT_DATABASE_URL
    if not url:
        print('Configure LIFESCRIPT_DATABASE_URL privately in backend/.env; no database was contacted.')
        raise SystemExit(1)
    try:
        if args.apply_objectives:
            from app.core.config import settings
            project = (urlparse(settings.SUPABASE_URL).hostname or '').split('.')[0]
            params = conninfo_to_dict(url)
            if not project or not (params.get('host') == f'db.{project}.supabase.co' or params.get('user') == f'postgres.{project}'):
                raise ValueError('SQL target does not match configured Supabase project')
            with psycopg.connect(url, connect_timeout=15) as conn:
                version = conn.execute('select version from public.app_schema_metadata where singleton=true for update').fetchone()[0]
                if version == 12:
                    print('Schema is already version 12; nothing applied.')
                    return
                if version != 11 or conn.execute("select to_regclass('public.objectives')").fetchone()[0] is not None:
                    raise ValueError('Expected reconciled version 11 without an objectives table')
                for table in ('users', 'tasks', 'workflow_runs', 'journal_entries', 'memory_chunks'):
                    row = conn.execute('select relrowsecurity from pg_class where oid=to_regclass(%s)', ('public.' + table,)).fetchone()
                    if not row or not row[0]:
                        raise ValueError('Baseline RLS mismatch')
                migration = Path(__file__).resolve().parents[1] / 'migrations' / '0012_objectives.sql'
                conn.execute(migration.read_text(encoding='utf-8'))
                conn.execute("notify pgrst, 'reload schema'")
            print('Applied migration 0012 transactionally to the configured project; schema version 12.')
            return
        with psycopg.connect(url, connect_timeout=15, options='-c default_transaction_read_only=on') as conn:
            report = audit(conn)
        (output / 'schema-audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print('Read-only audit saved to .local/schema-audit.json. Review before applying migrations.')
        print('Schema version:', report['schema_version'])
    except Exception as exc:
        # Database exceptions may contain credentials/SQL data; expose type only.
        print('Read-only audit failed:', type(exc).__name__)
        raise SystemExit(1) from None


if __name__ == '__main__':
    main()
