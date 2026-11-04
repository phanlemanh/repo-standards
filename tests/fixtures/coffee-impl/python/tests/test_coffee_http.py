from fastapi import FastAPI
from fastapi.testclient import TestClient

from PKG.actions import HANDLERS
from PKG.http_actions import build_router

app = FastAPI()
app.include_router(
    build_router(HANDLERS, {"k-agent": "agent", "k-staff": "staff", "k-manager": "manager"})
)
client = TestClient(app)


def test_permitted_role_runs_action() -> None:
    res = client.post(
        "/v1/actions/placeOrder",
        json={"customerId": "c1", "total": 5, "channel": "app"},
        headers={"Authorization": "Bearer k-staff"},
    )
    assert res.status_code == 200
    assert res.json()["total"] == 5


def test_forbidden_role() -> None:
    res = client.post(
        "/v1/actions/awardPoints",
        json={"customerId": "c1", "points": 5},
        headers={"Authorization": "Bearer k-staff"},
    )
    assert res.status_code == 403


def test_invalid_input() -> None:
    res = client.post(
        "/v1/actions/placeOrder",
        json={"customerId": "c1", "total": "x", "channel": "app"},
        headers={"Authorization": "Bearer k-staff"},
    )
    assert res.status_code == 422


def test_redacts_personal_data_for_agents_only() -> None:
    agent = client.post(
        "/v1/actions/getCustomer", json={"id": "c1"}, headers={"Authorization": "Bearer k-agent"}
    )
    staff = client.post(
        "/v1/actions/getCustomer", json={"id": "c1"}, headers={"Authorization": "Bearer k-staff"}
    )
    assert agent.json()["phone"] == "[redacted]"
    assert staff.json()["phone"] == "0901234567"
