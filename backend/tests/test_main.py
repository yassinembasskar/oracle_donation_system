from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["message"].startswith("Backend Oracle Donation System")


def test_create_and_list_donations():
    # Créer un don
    payload = {
        "donor_name": "Test Donor",
        "amount": 50.0,
        "currency": "EUR",
        "message": "Test donation",
    }
    response = client.post("/donations/", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["donor_name"] == "Test Donor"

    # Liste des dons
    response = client.get("/donations/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 1
