"""Platform API - Multi-tenant SaaS application."""
import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_client import Counter, Histogram, generate_latest
from starlette.responses import PlainTextResponse

logger = logging.getLogger(__name__)

# Metrics
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code", "tenant"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint", "tenant"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

TENANT_ID = os.environ.get("TENANT_ID", "unknown")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - setup telemetry."""
    provider = TracerProvider()
    provider.add_span_processor(
        BatchSpanExporter(OTLPSpanExporter(endpoint="http://otel-collector.monitoring.svc.cluster.local:4317"))
    )
    trace.set_tracer_provider(provider)
    logger.info("Platform API started for tenant=%s", TENANT_ID)
    yield
    logger.info("Platform API shutting down for tenant=%s", TENANT_ID)


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title="Platform API",
        version="0.1.0",
        lifespan=lifespan,
    )

    FastAPIInstrumentor.instrument_app(app)

    @app.middleware("http")
    async def metrics_middleware(request: Request, call_next):
        import time
        start = time.time()
        response = await call_next(request)
        duration = time.time() - start
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status_code=response.status_code,
            tenant=TENANT_ID,
        ).inc()
        REQUEST_LATENCY.labels(
            method=request.method,
            endpoint=request.url.path,
            tenant=TENANT_ID,
        ).observe(duration)
        return response

    @app.get("/health")
    async def health():
        return {"status": "healthy", "tenant": TENANT_ID}

    @app.get("/ready")
    async def ready():
        return {"status": "ready", "tenant": TENANT_ID}

    @app.get("/metrics")
    async def metrics():
        return PlainTextResponse(generate_latest())

    @app.get("/api/v1/info")
    async def info():
        return {"tenant": TENANT_ID, "version": "0.1.0"}

    @app.get("/api/v1/data")
    async def get_data():
        tracer = trace.get_tracer(__name__)
        with tracer.start_as_current_span("get_data") as span:
            span.set_attribute("tenant.id", TENANT_ID)
            return {"data": [], "tenant": TENANT_ID}

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.exception("Unhandled exception")
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    return app


app = create_app()
