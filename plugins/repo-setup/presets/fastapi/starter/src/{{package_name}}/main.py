"""HTTP API entry point. Run locally with `make dev`."""

import logging
import os

from fastapi import FastAPI

from .greet import greet

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO").upper(),
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", '
    '"message": "%(message)s"}',
)
logger = logging.getLogger(__name__)

app = FastAPI(title=os.environ.get("APP_NAME", "api"))


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe for load balancers and orchestrators."""
    return {"status": "ok"}


@app.get("/greet/{name}")
def greet_endpoint(name: str) -> dict[str, str]:
    logger.info("greet requested")
    return {"message": greet(name)}
