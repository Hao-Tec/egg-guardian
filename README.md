# 🥚 Egg Guardian MVP

**Real-time egg temperature monitoring system** - A mobile + IoT solution for egg incubator monitoring with alerts.

## 🌟 Features

- **Real-time Monitoring**: Live temperature readings from IoT sensors
- **Mobile App**: Flutter web app with live charts
- **Alerts**: Configurable temperature thresholds with notifications
- **Admin Panel**: Device registration and rule management
- **MQTT Telemetry**: Efficient IoT data ingestion
- **REST API**: Full-featured FastAPI backend

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (Windows/Mac) or Docker + Docker Compose (Linux)
- Python 3.11+
- Flutter SDK (for mobile development)

### 1. Start Backend Services

```bash
# Clone and navigate to project
cd egg-guardian

# Copy environment file
copy .env.example .env  # Windows
# cp .env.example .env  # Linux/Mac

# Start all services (Mosquitto, PostgreSQL, API)
docker-compose up --build
```

The API will be available at: http://localhost:8000

- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/healthz

### 2. Run Flutter Web App

```bash
cd mobile/egg_guardian
flutter pub get
flutter run -d chrome
```

### 3. Run Device Simulator

In a separate terminal:

```bash
# Install simulator dependency
pip install paho-mqtt

# Simulate one device sending data every second for 60 seconds
python scripts/simulate_devices.py --count 1 --rate 1 --duration 60
```

### 4. Open Admin Panel

```bash
start admin/index.html  # Windows
# open admin/index.html  # Mac
# xdg-open admin/index.html  # Linux
```

## 📁 Project Structure

```
egg-guardian/
├── services/api/          # FastAPI backend
│   └── app/
│       ├── main.py        # App entry point
│       ├── config.py      # Settings
│       ├── database.py    # SQLAlchemy setup
│       ├── models/        # Database models
│       ├── schemas/       # Pydantic schemas
│       ├── routers/       # API endpoints
│       └── services/      # Business logic
├── mobile/egg_guardian/   # Flutter web app
│   └── lib/
│       ├── main.dart
│       ├── config.dart
│       ├── models.dart
│       ├── screens/       # UI screens
│       └── services/      # API & WebSocket
├── firmware/              # ESP32 firmware (Arduino)
│   └── src/main.cpp
├── admin/                 # Admin web UI
├── scripts/               # Device simulator
├── mosquitto/             # MQTT broker config
├── docs/                  # Documentation
└── docker-compose.yml     # Service orchestration
```

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Health check |
| POST | `/api/v1/auth/register` | Register user |
| POST | `/api/v1/auth/login` | Login, get JWT |
| POST | `/api/v1/auth/refresh` | Refresh token |
| GET | `/api/v1/devices` | List devices |
| POST | `/api/v1/devices` | Register device |
| GET | `/api/v1/devices/{id}` | Get device |
| GET | `/api/v1/devices/{id}/telemetry` | Get history |
| POST | `/api/v1/devices/{id}/rules` | Create alert rule |
| WS | `/api/v1/ws/{device_id}` | Real-time stream |

## 🌡️ MQTT Topics

| Topic | Direction | Payload |
|-------|-----------|---------|
| `egg/{device_id}/telemetry` | Device → Server | `{"device_id": "x", "ts": "ISO8601", "temp_c": 37.5}` |

## ⚙️ Environment Variables

Copy `.env.example` to `.env` and configure:

```env
# Database
POSTGRES_USER=egg_guardian
POSTGRES_PASSWORD=egg_guardian_secret
POSTGRES_DB=egg_guardian

# MQTT (internal port, external is 11883)
MQTT_BROKER=mosquitto
MQTT_PORT=1883

# JWT (change in production!)
JWT_SECRET_KEY=change-me-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

## 🧪 Testing

```bash
# Run API tests
cd services/api
pytest

# Run simulator test
python scripts/simulate_devices.py --count 3 --rate 2 --duration 30
```

## 📱 Mobile App Features

- **Login/Register**: JWT authentication with demo mode
- **Device List**: Auto-refreshes every 5 seconds
- **Device Detail**: 
  - Live temperature display
  - Historical chart (fl_chart)
  - Min/Max/Optimal stats
  - Alert notifications

## 🔔 Alert System

1. Create an alert rule for a device:
   ```
   POST /api/v1/devices/{id}/rules
   {"temp_min": 35.0, "temp_max": 39.0}
   ```

2. When temperature exceeds thresholds:
   - Alert recorded in database
   - Broadcast via WebSocket
   - Displayed in mobile app

## 📄 License

MIT License - See LICENSE file

## 👨‍💻 Author

Egg Guardian MVP - Final Year Project
