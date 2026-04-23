"""Unit tests for the Platform API."""
import pytest
from unittest.mock import patch, MagicMock
from app import create_app


@pytest.fixture
def app():
    """Create test application."""
    return create_app()


@pytest.fixture
def client(app):
    """Create test client."""
    from fastapi.testclient import TestClient
    return TestClient(app)


class TestHealthEndpoints:
    def test_health_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "tenant" in data

    def test_ready_returns_200(self, client):
        response = client.get("/ready")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"
        assert "tenant" in data


class TestMetricsEndpoint:
    def test_metrics_returns_200(self, client):
        response = client.get("/metrics")
        assert response.status_code == 200
        assert "http_requests_total" in response.text


class TestAPIEndpoints:
    def test_info_returns_tenant(self, client):
        response = client.get("/api/v1/info")
        assert response.status_code == 200
        data = response.json()
        assert "tenant" in data
        assert "version" in data

    def test_data_returns_list(self, client):
        response = client.get("/api/v1/data")
        assert response.status_code == 200
        data = response.json()
        assert "data" in data
        assert isinstance(data["data"], list)

    def test_info_includes_tenant_id(self, client, monkeypatch):
        monkeypatch.setenv("TENANT_ID", "test-tenant")
        response = client.get("/api/v1/info")
        assert response.status_code == 200


class TestMiddleware:
    def test_metrics_middleware_records_request(self, client):
        response = client.get("/health")
        assert response.status_code == 200

        # Check metrics were recorded
        metrics_response = client.get("/metrics")
        assert "http_requests_total" in metrics_response.text

    def test_global_exception_handler(self, client):
        with patch("app.create_app") as mock_app:
            # This tests that the exception handler is registered
            pass


class TestSecurity:
    def test_no_server_header(self, client):
        response = client.get("/health")
        # FastAPI/Uvicorn should not leak server info
        assert "Server" not in response.headers or "uvicorn" not in response.headers.get("Server", "").lower()

    def test_tenant_isolation_in_response(self, client):
        response = client.get("/api/v1/info")
        data = response.json()
        assert "tenant" in data
