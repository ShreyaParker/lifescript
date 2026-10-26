import json
import httpx
import pytest
from app.core.config import settings
from app.schemas.workflow import Understanding
from app.services.model_provider import ModelProvider


def test_local_structured_output_repair_is_bounded(monkeypatch):
    original=httpx.Client
    monkeypatch.setattr(settings,"AI_PROVIDER","ollama")
    attempts=[]
    def handler(request):
        attempts.append(json.loads(request.content))
        return httpx.Response(200,json={"message":{"content":"not-json"}})
    monkeypatch.setattr(httpx,"Client",lambda **kwargs: original(transport=httpx.MockTransport(handler),**kwargs))
    with pytest.raises(ValueError): ModelProvider().structured(Understanding,"Extract facts","Synthetic entry")
    assert len(attempts)==2


def test_embedding_batch_dimension_validation(monkeypatch):
    original=httpx.Client
    monkeypatch.setattr(settings,"AI_PROVIDER","ollama")
    monkeypatch.setattr(httpx,"Client",lambda **kwargs:original(transport=httpx.MockTransport(
        lambda request:httpx.Response(200,json={"embeddings":[[0.0]*384]})),**kwargs))
    with pytest.raises(ValueError,match="embedding_dimension"): ModelProvider().embed("Synthetic")


def test_gemini_uses_json_schema_with_real_sdk_and_local_validation(monkeypatch):
    from google import genai
    from app.schemas.workflow import Plan
    original = genai.Client
    requests = []
    output = {'tasks': [], 'coaching_insight': 'Completed work needs no new task.'}

    def handler(request):
        requests.append(json.loads(request.content))
        return httpx.Response(200, json={'candidates': [{'content': {'role': 'model', 'parts': [{'text': json.dumps(output)}]}, 'finishReason': 'STOP'}]})

    def client(**kwargs):
        assert kwargs['http_options'].retry_options.attempts == 1
        kwargs['http_options'].httpx_client = httpx.Client(transport=httpx.MockTransport(handler))
        return original(**kwargs)

    monkeypatch.setattr(genai, 'Client', client)
    monkeypatch.setattr(settings, 'AI_PROVIDER', 'gemini')
    monkeypatch.setattr(settings, 'GEMINI_API_KEY', 'synthetic-key')
    assert ModelProvider().structured(Plan, 'Extract', 'Synthetic entry').tasks == []
    config = requests[0]['generationConfig']
    assert 'responseSchema' not in config
    assert config['responseJsonSchema']['$defs']['ProposedTask']['additionalProperties'] is False
