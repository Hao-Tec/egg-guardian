# Egg Guardian - Local Development Guide

## Quick Setup (All Platforms)

This guide walks through running the full Egg Guardian stack locally for development and demonstration purposes.

---

## Prerequisites

- Docker Desktop installed and running.
- Python 3.11+ installed.
- Flutter SDK installed (for mobile app development).
- `paho-mqtt` Python library for the device simulator.

---

## Step 1: Start the Backend

```bash
# Clone the repository
git clone https://github.com/Hao-Tec/egg-guardian.git
cd egg-guardian

# Copy the environment template
cp .env.example .env

# Start PostgreSQL, Mosquitto, and the FastAPI server
docker-compose up --build
```

Once running:
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/healthz

---

## Step 2: Open the Admin Dashboard

Open `admin/index.html` directly in your browser. The dashboard automatically detects the backend host from your browser's address bar so no hardcoded IP is needed.

**First-time setup:**
1. Register your first user by calling `POST /api/v1/auth/register` (use the Swagger UI at `/docs`).
2. Toggle the user to admin using `PATCH /api/v1/users/{id}/toggle-admin`.
3. Log in to the Admin Dashboard and register a device.
4. Create an alert rule for the device (e.g., min: 35°C, max: 39°C).

---

## Step 3: Run the Device Simulator

Simulate IoT sensors publishing telemetry to the MQTT broker without physical hardware:

```bash
# Install the required dependency
pip install paho-mqtt

# Basic simulation: 1 device publishing every second for 60 seconds
python scripts/simulate_devices.py --count 1 --rate 1 --duration 60

# Stress test: 5 devices publishing every 2 seconds for 5 minutes
python scripts/simulate_devices.py --count 5 --rate 2 --duration 300
```

**Parameter Reference:**
- `--count`: Number of virtual devices to simulate simultaneously.
- `--rate`: Telemetry publishing frequency in seconds (e.g., `2` = one reading every 2 seconds).
- `--duration`: Total simulation run time in seconds.
- `--prefix`: Optional prefix for generated device names (e.g., `--prefix TEST`).

---

## Step 4: Run the Mobile App

```bash
cd mobile/egg_guardian
flutter pub get

# Run on Chrome (no IP needed for local web testing)
flutter run -d chrome

# Run on a physical Android device connected to the same network as your PC
# Replace 192.168.1.x with your PC's actual local IP address
flutter run --dart-define=API_HOST=192.168.1.x
```

---

## Step 5: Trigger an Alert (Demo Flow)

1. Start the simulator with `--count 1 --rate 1 --duration 60`.
2. In the Admin Dashboard, create an alert rule for the simulated device with a threshold it will breach (e.g., set max to 36°C when the device reports 37-38°C).
3. Observe the alert appear in the Admin Dashboard's alert panel.
4. The mobile app will display an alert banner in real-time.
