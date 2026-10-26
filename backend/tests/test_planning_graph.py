from langgraph.checkpoint.sqlite import SqliteSaver
from langgraph.types import Command
import pytest

from app.schemas.workflow import Plan, Understanding
from app.services.planning_graph import build_graph, validate_plan


TASK = {"title": "Review notes", "description": "Study", "evidence": "I want to review notes",
        "source_id": "entry-1", "duration_minutes": 20, "xp_value": 20}
INITIAL = {"owner": "owner-1", "entry_id": "entry-1", "content": "I want to review notes",
           "sources": [{"source_id": "entry-1", "content": "I want to review notes"}],
           "goals": ["Study"], "existing_tasks": [], "reference_time": "2026-10-22T10:00:00Z",
           "timezone": "Asia/Kolkata", "memory": []}


class FakeProvider:
    def __init__(self, questions=None): self.questions = questions or []; self.calls = 0
    def structured(self, schema, system, text):
        self.calls += 1
        if schema is Understanding:
            return Understanding(facts=["Wants to study"], questions=self.questions)
        return Plan(tasks=[TASK], coaching_insight="Start small.")


def test_review_interrupt_and_restart_resume(tmp_path):
    database = str(tmp_path / "checkpoint.sqlite")
    config = {"configurable": {"thread_id": "owner-1:run-1"}}
    provider = FakeProvider()
    with SqliteSaver.from_conn_string(database) as saver:
        graph = build_graph(provider, saver)
        result = graph.invoke(INITIAL, config)
        assert result["__interrupt__"][0].value["kind"] == "review"
        assert "decision" not in result
    # A new saver and graph emulate process restart. No generation is repeated.
    with SqliteSaver.from_conn_string(database) as saver:
        graph = build_graph(provider, saver)
        result = graph.invoke(Command(resume={"decision": "approve", "version": 1, "selected_indices": [0]}), config)
        assert result["decision"]["selected_indices"] == [0]
        assert "__interrupt__" not in result
    assert provider.calls == 2


def test_clarification_then_rejection(tmp_path):
    with SqliteSaver.from_conn_string(str(tmp_path / "state.sqlite")) as saver:
        graph = build_graph(FakeProvider(["How much time is available?"]), saver)
        config = {"configurable": {"thread_id": "owner:clarify"}}
        first = graph.invoke(INITIAL, config)
        assert first["__interrupt__"][0].value["kind"] == "clarification"
        second = graph.invoke(Command(resume={"answer": "20 minutes"}), config)
        assert second["__interrupt__"][0].value["kind"] == "review"
        assert second["sources"][-1]["content"] == "20 minutes"
        final = graph.invoke(Command(resume={"decision": "reject", "version": 1, "selected_indices": []}), config)
        assert final["decision"]["decision"] == "reject"


def test_evidence_duplicate_and_time_validation():
    for task in [{**TASK, "evidence": "Invented"}, {**TASK, "source_id": "foreign"}]:
        with pytest.raises(ValueError, match="unsupported_task_evidence"):
            validate_plan(Plan(tasks=[task], coaching_insight="Start"), INITIAL["sources"], [])
    with pytest.raises(ValueError, match="duplicate_task"):
        validate_plan(Plan(tasks=[TASK], coaching_insight="Start"), INITIAL["sources"], [{"title": "review NOTES"}])
    with pytest.raises(ValueError, match="plan_time_budget"):
        validate_plan(Plan(tasks=[{**TASK, "duration_minutes": 240}, {**TASK, "title": "Another"}], coaching_insight="Start"), INITIAL["sources"], [])


def test_no_cross_thread_checkpoint(tmp_path):
    with SqliteSaver.from_conn_string(str(tmp_path / "state.sqlite")) as saver:
        graph = build_graph(FakeProvider(), saver)
        graph.invoke(INITIAL, {"configurable": {"thread_id": "owner-a:run"}})
        assert not graph.get_state({"configurable": {"thread_id": "owner-b:run"}}).values


def test_reflection_skips_planning_but_weekly_review_still_generates(tmp_path):
    class ReflectionProvider:
        calls = 0
        def structured(self, schema, system, text):
            self.calls += 1
            if schema is Understanding:
                return Understanding(intent='reflection', facts=['Work completed'], questions=['Unnecessary question'])
            return Plan(tasks=[], coaching_insight='A review based on supplied counts.')

    provider = ReflectionProvider()
    with SqliteSaver.from_conn_string(str(tmp_path / 'reflection.sqlite')) as saver:
        graph = build_graph(provider, saver)
        result = graph.invoke(INITIAL, {'configurable': {'thread_id': 'reflection'}})
        assert result['plan']['tasks'] == []
        assert result['understanding']['questions'] == []
        assert result['__interrupt__'][0].value['kind'] == 'review'
        assert provider.calls == 1
        graph.invoke({**INITIAL, 'workflow_kind': 'weekly_review'}, {'configurable': {'thread_id': 'weekly'}})
        assert provider.calls == 3
