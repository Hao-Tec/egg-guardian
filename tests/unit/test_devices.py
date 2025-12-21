"""Unit tests for device endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_devices_empty(client: AsyncClient):
    """Test listing devices when none exist."""
    response = await client.get("/api/v1/devices")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_create_device(client: AsyncClient):
    """Test creating a device."""
    response = await client.post(
        "/api/v1/devices",
        json={
            "device_id": "test-device-01",
            "name": "Test Incubator",
            "description": "A test device",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["device_id"] == "test-device-01"
    assert data["name"] == "Test Incubator"
    assert data["description"] == "A test device"
    assert data["is_active"] is True


@pytest.mark.asyncio
async def test_create_duplicate_device(client: AsyncClient):
    """Test that duplicate device_id fails."""
    # Create first device
    await client.post(
        "/api/v1/devices",
        json={"device_id": "dupe-device", "name": "First"},
    )

    # Try to create duplicate
    response = await client.post(
        "/api/v1/devices",
        json={"device_id": "dupe-device", "name": "Second"},
    )
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"]


@pytest.mark.asyncio
async def test_get_device(client: AsyncClient):
    """Test getting a specific device."""
    # Create device
    create_response = await client.post(
        "/api/v1/devices",
        json={"device_id": "get-test", "name": "Get Test"},
    )
    device_id = create_response.json()["id"]

    # Get device
    response = await client.get(f"/api/v1/devices/{device_id}")
    assert response.status_code == 200
    assert response.json()["device_id"] == "get-test"


@pytest.mark.asyncio
async def test_get_device_not_found(client: AsyncClient):
    """Test getting a non-existent device."""
    response = await client.get("/api/v1/devices/99999")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_list_devices(client: AsyncClient):
    """Test listing multiple devices."""
    # Create devices
    await client.post("/api/v1/devices", json={"device_id": "dev-1", "name": "Device 1"})
    await client.post("/api/v1/devices", json={"device_id": "dev-2", "name": "Device 2"})

    # List
    response = await client.get("/api/v1/devices")
    assert response.status_code == 200
    devices = response.json()
    assert len(devices) == 2


@pytest.mark.asyncio
async def test_create_alert_rule(client: AsyncClient):
    """Test creating an alert rule for a device."""
    # Create device
    create_response = await client.post(
        "/api/v1/devices",
        json={"device_id": "rule-test", "name": "Rule Test"},
    )
    device_id = create_response.json()["id"]

    # Create rule
    response = await client.post(
        f"/api/v1/devices/{device_id}/rules",
        json={"temp_min": 35.0, "temp_max": 39.0},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["temp_min"] == 35.0
    assert data["temp_max"] == 39.0
    assert data["is_active"] is True


@pytest.mark.asyncio
async def test_create_alert_rule_invalid_range(client: AsyncClient):
    """Test that min >= max is rejected."""
    # Create device
    create_response = await client.post(
        "/api/v1/devices",
        json={"device_id": "invalid-rule", "name": "Invalid Rule"},
    )
    device_id = create_response.json()["id"]

    # Try invalid rule
    response = await client.post(
        f"/api/v1/devices/{device_id}/rules",
        json={"temp_min": 40.0, "temp_max": 35.0},
    )
    assert response.status_code == 400
    assert "less than" in response.json()["detail"]
