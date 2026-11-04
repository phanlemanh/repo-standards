"""HTTP API entry point. Run locally with `make dev`."""

import logging
import os

from fastapi import FastAPI

from .http_actions import build_router

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO").upper(),
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", '
    '"message": "%(message)s"}',
)

app = FastAPI(title=os.environ.get("APP_NAME", "api"))


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe for load balancers and orchestrators."""
    return {"status": "ok"}


# Every ontology action as POST /v1/actions/{name} (see contracts/openapi.json).
app.include_router(build_router())
