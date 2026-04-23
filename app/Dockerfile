# Multi-stage Dockerfile for the platform API
# Used by all tenants with environment variable for tenant ID

# Build stage
FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:3.12-slim

ARG VERSION=0.1.0

LABEL org.opencontainers.image.title="platform-api" \
      org.opencontainers.image.description="Multi-tenant SaaS Platform API" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/your-org/platform"

WORKDIR /app

COPY --from=builder /root/.local /root/.local
COPY . .

ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

USER 1000

CMD ["gunicorn", "app:create_app()", "--bind", "0.0.0.0:8080", "--workers", "4", "--threads", "2", "--timeout", "120", "--access-logfile", "-"]
