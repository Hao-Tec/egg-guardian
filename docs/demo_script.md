# Egg Guardian Demo Script (2-3 minutes)

## Overview
This demo showcases the Egg Guardian egg temperature monitoring system.

---

## Demo Flow

### 1. Introduction (30 seconds)
> "Egg Guardian is a real-time egg incubator monitoring system. It uses IoT sensors to track temperature, sends data via MQTT, and alerts you when temperatures go out of range."

**Show:** Main Flutter app with device list

### 2. Device Registration (30 seconds)
> "Devices can be registered through the admin panel or auto-registered when they first send data."

**Action:** Open admin panel → Add device "incubator-demo"

### 3. Live Monitoring (45 seconds)
> "Watch as our simulated device sends real-time temperature data. The chart updates automatically every 2 seconds."

**Action:**
```bash
python scripts/simulate_devices.py --count 1 --rate 1 --duration 30
```

**Show:** Temperature updating live, chart growing

### 4. Alert System (30 seconds)
> "Alert rules trigger when temperature exceeds thresholds."

**Show:** Configure alert rule (35°C - 39°C) in admin panel

> "When the simulated sensor sends a reading outside this range, an alert is triggered and broadcast to all connected clients."

### 5. API & Architecture (15 seconds)
> "The system includes a FastAPI backend with JWT auth, PostgreSQL database, MQTT broker, and WebSocket for real-time updates."

**Show:** http://localhost:8000/docs (Swagger UI)

### 6. Conclusion (15 seconds)
> "Egg Guardian demonstrates a complete IoT monitoring solution with mobile app, backend API, and real-time alerts. Thank you!"

---

## Commands to Prepare

```bash
# Terminal 1: Start backend
docker-compose up

# Terminal 2: Start Flutter
cd mobile/egg_guardian
flutter run -d chrome

# Terminal 3: Open admin
start admin/index.html

# Terminal 4: Run simulator (during demo)
python scripts/simulate_devices.py --count 1 --rate 1 --duration 60
```
