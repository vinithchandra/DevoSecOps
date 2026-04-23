"""Integration tests for the Platform API."""
import pytest
import os

# Skip integration tests if no cluster available
pytestmark = pytest.mark.skipif(
    not os.environ.get("RUN_INTEGRATION_TESTS"),
    reason="Integration tests require a running cluster (set RUN_INTEGRATION_TESTS=1)"
)

try:
    import httpx
except ImportError:
    httpx = None

BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8080")
TENANT = os.environ.get("TENANT_ID", "tenant-a")


@pytest.fixture
def client():
    if httpx is None:
        pytest.skip("httpx not installed")
    return httpx.Client(base_url=BASE_URL, timeout=30.0)


class TestAPIIntegration:
    def test_health_endpoint(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

    def test_ready_endpoint(self, client):
        response = client.get("/ready")
        assert response.status_code == 200

    def test_info_returns_tenant(self, client):
        response = client.get("/api/v1/info")
        assert response.status_code == 200
        assert response.json()["tenant"] == TENANT

    def test_data_endpoint(self, client):
        response = client.get("/api/v1/data")
        assert response.status_code == 200

    def test_metrics_endpoint(self, client):
        response = client.get("/metrics")
        assert response.status_code == 200
        assert "http_requests_total" in response.text

    def test_latency_under_500ms(self, client):
        """SLO test: p99 latency should be under 500ms."""
        latencies = []
        for _ in range(50):
            import time
            start = time.time()
            response = client.get("/api/v1/data")
            latencies.append((time.time() - start) * 1000)
            assert response.status_code == 200

        p99 = sorted(latencies)[int(len(latencies) * 0.99)]
        assert p99 < 500, f"p99 latency {p99:.1f}ms exceeds 500ms SLO"

    def test_error_rate_under_slo(self, client):
        """SLO test: error rate should be under 0.1%."""
        errors = 0
        total = 100
        for _ in range(total):
            response = client.get("/api/v1/data")
            if response.status_code >= 500:
                errors += 1

        error_rate = errors / total
        assert error_rate < 0.001, f"Error rate {error_rate:.4f} exceeds 0.1% SLO"
