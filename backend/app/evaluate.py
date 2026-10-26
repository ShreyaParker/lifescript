"""Opt-in synthetic evaluation; never reads journals or the live database.

python -m app.evaluate --limit 10 --output .local/evaluation.json
This calls the configured model (two calls/case); hosted-provider costs may apply.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from app.core.config import settings
from app.schemas.workflow import Plan, Understanding
from app.services.model_provider import ModelProvider
from app.services.planning_graph import RULES, UNDERSTANDING_INSTRUCTION, PLAN_INSTRUCTION, validate_plan


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit",type=int,default=10,choices=range(1,51))
    parser.add_argument("--output",type=Path,default=Path(".local/evaluation.json"))
    parser.add_argument("--split",choices=["development","held_out"],default="held_out")
    args=parser.parse_args()
    dataset=Path(__file__).resolve().parents[1]/"evals"/"journal_cases.jsonl"
    cases=[json.loads(line) for line in dataset.read_text(encoding="utf-8").splitlines()]
    cases=[case for case in cases if case["split"]==args.split][:args.limit]
    provider=ModelProvider()
    results=[]
    for case in cases:
        started=datetime.now(timezone.utc)
        result={"id":case["id"],"category":case["category"],"passed":False}
        try:
            sources=[{"source_id":case["id"],"content":case["content"]}]
            context={"content":case["content"],"sources":sources,"goals":["Learn Python"],"existing_tasks":[],"memory":[],"reference_time":"2026-10-22T10:00:00Z","timezone":"Asia/Kolkata"}
            understanding=provider.structured(Understanding,RULES,json.dumps(context)+UNDERSTANDING_INSTRUCTION)
            if understanding.intent == "reflection":
                result.update(outcome="proposal",task_count=0,passed=case["expectation"]=="no_task")
            elif understanding.questions:
                result.update(outcome="clarification",passed=case["expectation"]=="clarify")
            else:
                plan=provider.structured(Plan,RULES,json.dumps({**context,"understanding":understanding.model_dump()})+PLAN_INSTRUCTION)
                validate_plan(plan,sources,[])
                count=len(plan.tasks)
                result.update(outcome="proposal",task_count=count,
                    passed=(count==0 if case["expectation"]=="no_task" else count>0 and case["expectation"]=="task"))
        except Exception as exc:
            result.update(outcome="failure",error_type=type(exc).__name__,error_code=getattr(exc,"code",None))
        result["duration_ms"]=round((datetime.now(timezone.utc)-started).total_seconds()*1000)
        results.append(result)
    report={"created_at":datetime.now(timezone.utc).isoformat(),"provider":settings.AI_PROVIDER,
            "model":settings.OLLAMA_MODEL if settings.AI_PROVIDER=="ollama" else settings.GENERATION_MODEL,
            "cases":len(results),"split":args.split,"passed":sum(row["passed"] for row in results),"results":results,
            "limitations":"Synthetic action/clarification checks only; human usefulness/translation and retrieval quality need separate review."}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(f"Saved {len(results)} synthetic-case outcomes to {args.output}")


if __name__=="__main__":
    main()
