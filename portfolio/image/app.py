"""Public portfolio and request-driven Azure AKS metadata status."""

from datetime import datetime, timezone
import logging
import os
from pathlib import Path
from threading import Lock
from time import monotonic
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
import json

from azure.core.exceptions import AzureError
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
assets = Path(__file__).parent / "static"
app.mount("/static", StaticFiles(directory=assets), name="static")

_lock = Lock()
_cached = None
_expires = 0.0
_credential = None


def cluster_state(resource):
    """Power state describes the cluster, never readiness of its applications."""
    properties = resource.get("properties", {})
    power = properties.get("powerState", {}).get("code", "")
    provisioning = properties.get("provisioningState", "")

    if provisioning in {"Failed", "Canceled"}:
        return "degraded"
    if provisioning in {"Creating", "Starting", "Updating", "Stopping", "Deleting"}:
        return "changing"
    if power == "Stopped":
        return "stopped"
    if power == "Running" and provisioning == "Succeeded":
        return "running"
    return "unknown"


def read_status():
    global _credential

    subscription = os.environ.get("AZURE_SUBSCRIPTION_ID")
    group = os.environ.get("AKS_RESOURCE_GROUP")
    name = os.environ.get("AKS_NAME")
    if not all((subscription, group, name)):
        return "unknown"

    if _credential is None:
        options = {"connection_timeout": 3, "read_timeout": 3, "retry_total": 0}
        client_id = os.environ.get("AZURE_CLIENT_ID")
        _credential = (
            ManagedIdentityCredential(client_id=client_id, **options)
            if client_id
            else DefaultAzureCredential(process_timeout=3, **options)
        )

    token = _credential.get_token("https://management.azure.com/.default")
    segments = [quote(value, safe="") for value in (subscription, group, name)]
    url = (
        f"https://management.azure.com/subscriptions/{segments[0]}"
        f"/resourceGroups/{segments[1]}/providers/Microsoft.ContainerService"
        f"/managedClusters/{segments[2]}?api-version=2025-01-01"
    )
    request = Request(url, headers={"Authorization": f"Bearer {token.token}"})
    try:
        with urlopen(request, timeout=5) as response:
            return cluster_state(json.load(response))
    except HTTPError as error:
        if error.code == 404:
            return "absent"
        raise


@app.middleware("http")
async def response_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; script-src 'self'; style-src 'self'; "
        "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; "
        "base-uri 'none'; form-action 'none'"
    )
    return response


@app.get("/")
def index():
    return FileResponse(assets / "index.html")


@app.get("/healthz")
def health():
    # Host readiness is independent of AKS or ARM availability.
    return {"status": "ok"}


@app.get("/api/status")
def status():
    global _cached, _expires

    # Coalesce visitors into at most one ARM request per 30 seconds per process.
    # No scheduled polling, stored Azure credentials or browser-side Azure access.
    with _lock:
        if _cached is None or monotonic() >= _expires:
            try:
                state = read_status()
            except (AzureError, URLError, TimeoutError, ValueError, OSError):
                # Never publish Azure exceptions, resource IDs or tokens.
                logging.getLogger(__name__).warning("Cluster status lookup unavailable")
                state = "unknown"
            _cached = {
                "state": state,
                "checked_at": datetime.now(timezone.utc).isoformat(),
            }
            _expires = monotonic() + 30

        return JSONResponse(_cached, headers={"Cache-Control": "no-store"})
