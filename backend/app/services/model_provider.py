"""One bounded, schema-validated interface for local and hosted inference."""
import base64
import math
import logging
import time
from typing import TypeVar

import httpx
from pydantic import BaseModel

from app.core.config import settings
from app.core.tls import tls_context

T = TypeVar("T", bound=BaseModel)
log = logging.getLogger("lifescript.model")


class ModelProvider:
    @property
    def embedding_model(self):
        model = settings.OLLAMA_EMBEDDING_MODEL if settings.AI_PROVIDER == "ollama" else settings.EMBEDDING_MODEL
        return f"{settings.AI_PROVIDER}:{model}:768"

    def structured(self, schema: type[T], system: str, text: str, image: bytes | None = None, mime: str = "image/jpeg") -> T:
        # Exactly two attempts for malformed/schema-invalid output. Transport failures
        # are handled by the durable run retry policy, not unbounded inner retries.
        for attempt in range(2):
            started = time.monotonic()
            usage = {}
            correction = "\nReturn only JSON matching the supplied schema." if attempt else ""
            if settings.AI_PROVIDER == "ollama":
                message = {"role": "user", "content": text + correction}
                if image:
                    message["images"] = [base64.b64encode(image).decode()]
                with httpx.Client(verify=tls_context(), timeout=settings.MODEL_TIMEOUT_SECONDS) as client:
                    response = client.post(settings.OLLAMA_URL + "/api/chat", json={
                        "model": settings.OLLAMA_MODEL, "stream": False,
                        "messages": [{"role": "system", "content": system}, message],
                        "format": schema.model_json_schema(), "options": {"temperature": 0.1, "num_predict":4096},
                    })
                    response.raise_for_status()
                    body = response.json()
                    output = body["message"]["content"]
                    usage = {"input_tokens":body.get("prompt_eval_count"),"output_tokens":body.get("eval_count")}
            else:
                if not settings.GEMINI_API_KEY:
                    raise RuntimeError("provider_not_configured")
                from google import genai
                from google.genai import types
                with genai.Client(api_key=settings.GEMINI_API_KEY,
                                  http_options=types.HttpOptions(timeout=settings.MODEL_TIMEOUT_SECONDS * 1000, client_args={"verify": tls_context()}, retry_options=types.HttpRetryOptions(attempts=1))) as client:
                    contents = [text + correction]
                    if image:
                        contents.append(types.Part.from_bytes(data=image, mime_type=mime))
                    response = client.models.generate_content(
                        model=settings.GENERATION_MODEL, contents=contents,
                        config=types.GenerateContentConfig(system_instruction=system,
                            response_mime_type="application/json", response_json_schema=schema.model_json_schema(), temperature=0.1,max_output_tokens=4096),
                    )
                    output = response.text or ""
                    if response.usage_metadata:
                        usage = {"input_tokens":response.usage_metadata.prompt_token_count,
                                 "output_tokens":response.usage_metadata.candidates_token_count}
            log.info("model_completed",extra={"duration_ms":round((time.monotonic()-started)*1000),
                "provider":settings.AI_PROVIDER,"model":settings.OLLAMA_MODEL if settings.AI_PROVIDER=="ollama" else settings.GENERATION_MODEL,**usage})
            try:
                return schema.model_validate_json(output)
            except ValueError:
                if attempt:
                    raise
        raise RuntimeError("invalid_model_output")

    def embed(self, text: str) -> list[float]:
        return self.embed_many([text])[0]

    def embed_many(self, texts: list[str]) -> list[list[float]]:
        if not texts or len(texts)>32 or any(len(text)>3000 for text in texts):
            raise ValueError("embedding_batch_limit")
        if settings.AI_PROVIDER == "ollama":
            with httpx.Client(verify=tls_context(), timeout=settings.MODEL_TIMEOUT_SECONDS) as client:
                response = client.post(settings.OLLAMA_URL + "/api/embed", json={
                    "model": settings.OLLAMA_EMBEDDING_MODEL, "input": texts,
                })
                response.raise_for_status()
                vectors = response.json()["embeddings"]
        else:
            from google import genai
            from google.genai import types
            with genai.Client(api_key=settings.GEMINI_API_KEY,
                              http_options=types.HttpOptions(timeout=settings.MODEL_TIMEOUT_SECONDS * 1000, client_args={"verify": tls_context()}, retry_options=types.HttpRetryOptions(attempts=1))) as client:
                response = client.models.embed_content(model=settings.EMBEDDING_MODEL, contents=texts,
                    config=types.EmbedContentConfig(output_dimensionality=768))
                vectors = [embedding.values for embedding in response.embeddings]
        if len(vectors)!=len(texts) or any(len(vector)!=768 or any(not math.isfinite(v) for v in vector) for vector in vectors):
            raise ValueError("embedding_dimension_or_value_invalid")
        return vectors


def get_model_provider():
    return ModelProvider()
