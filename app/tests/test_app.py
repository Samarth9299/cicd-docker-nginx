import pytest

from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as client:
        yield client


def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_index_renders(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"CI/CD Pipeline" in resp.data


def test_info_has_version_fields(client):
    data = client.get("/api/info").get_json()
    for key in ("version", "commit", "hostname", "started_at"):
        assert key in data


def test_unknown_route_is_404(client):
    assert client.get("/does-not-exist").status_code == 404
