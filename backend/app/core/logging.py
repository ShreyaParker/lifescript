import json
import logging
from datetime import datetime, timezone


class SafeJsonFormatter(logging.Formatter):
    def format(self, record):
        data = {"time": datetime.now(timezone.utc).isoformat(), "level": record.levelname,
                "event": record.getMessage()}
        for key in ("request_id", "run_id", "attempt", "exception_type", "status", "duration_ms", "provider", "model", "input_tokens", "output_tokens"):
            if hasattr(record, key):
                data[key] = getattr(record, key)
        return json.dumps(data)


def configure_logging():
    handler = logging.StreamHandler()
    handler.setFormatter(SafeJsonFormatter())
    logger = logging.getLogger("lifescript")
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)
    logger.propagate = False
