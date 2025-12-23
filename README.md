# 🥚 Egg Guardian MVP

**Real-time egg temperature monitoring system** - A mobile + IoT solution for egg incubator monitoring with alerts.

## 🌟 Features

### Core Features
- **Real-time Monitoring**: Live temperature readings from IoT sensors via WebSocket
- **Mobile App**: Flutter web app with live charts and device management
- **Smart Alerts**: Configurable temperature thresholds with automatic detection
- **Admin Panel**: Full device, user, and alert management with authentication
- **MQTT Telemetry**: Efficient IoT data ingestion
- **REST API**: Full-featured FastAPI backend with Swagger docs

### Admin Panel Features
- 🔐 **JWT Authentication** - Secure login with role-based access
- 📊 **Device Management** - Register, view, delete devices
- ⚠️ **Alert Rules** - Create min/max temperature thresholds
- 🚨 **Real-time Alerts** - Auto-updating triggered alerts (every 5s)
- 👥 **User Management** - View, delete users, toggle admin status
- 🛡️ **Security** - Last-admin protection, self-delete logout

### Mobile App Features
- 📱 **Login/Register** with JWT authentication + Demo mode
- 📋 **Device List** with auto-refresh (5s)
- 📈 **Live Charts** with historical temperature data
- 🔔 **Alert Banners** when temperature is out of range
- 🔐 **Password Toggle** for visibility

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

- **API Docs**: http://localhost:8000/docs (auto-redirect from root)
- **Health Check**: http://localhost:8000/healthz

### 2. Run Flutter Web App

```bash
cd mobile/egg_guardian
flutter pub get
flutter run -d chrome
```

Default URL: http://localhost:32026

### 3. Run Device Simulator

```bash
# Install simulator dependency
pip install paho-mqtt

# Basic: 1 device, 1 reading/second, 60 seconds
python scripts/simulate_devices.py --count 1 --rate 1 --duration 60

# Custom device name prefix
python scripts/simulate_devices.py --count 1 --rate 1 --duration 120 --prefix TEST
```

### 4. Open Admin Panel

**Option A: Via file browser**
```bash
start admin/index.html  # Windows
open admin/index.html   # Mac
xdg-open admin/index.html  # Linux
```

**Option B: First-time setup**
1. Register a user via API: `POST /api/v1/auth/register`
2. Make them admin: `PATCH /api/v1/users/{id}/toggle-admin`
3. Login at the admin panel

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
│       │   ├── auth.py    # Authentication
│       │   ├── devices.py # Device CRUD
│       │   ├── users.py   # User management
│       │   ├── alerts.py  # Triggered alerts
│       │   └── telemetry.py
│       ├── services/      # Business logic
│       │   └── mqtt.py    # MQTT ingestion + alerts
│       └── static/        # Favicon, assets
├── mobile/egg_guardian/   # Flutter web app
│   └── lib/
│       ├── main.dart
│       ├── config.dart
│       ├── screens/       # Login, Devices, Device Detail
│       └── services/      # API & WebSocket
├── firmware/              # ESP32 firmware (Arduino)
│   └── src/main.cpp
├── admin/                 # Admin web UI (HTML/CSS/JS)
│   ├── index.html
│   ├── styles.css
│   └── app.js
├── scripts/               # Device simulator
│   └── simulate_devices.py
├── mosquitto/             # MQTT broker config
├── docs/                  # Documentation
└── docker-compose.yml     # Service orchestration
```

## 🔌 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login, get JWT token |
| POST | `/api/v1/auth/refresh` | Refresh JWT token |
| GET | `/api/v1/auth/me` | Get current user info |

### Devices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/devices` | List all devices |
| POST | `/api/v1/devices` | Register new device |
| GET | `/api/v1/devices/{id}` | Get device details |
| PATCH | `/api/v1/devices/{id}` | Update device |
| DELETE | `/api/v1/devices/{id}` | Delete device (cascade) |
| GET | `/api/v1/devices/{id}/telemetry` | Get temperature history |
| GET | `/api/v1/devices/{id}/rules` | List alert rules |
| POST | `/api/v1/devices/{id}/rules` | Create alert rule |
| DELETE | `/api/v1/devices/{id}/rules/{rule_id}` | Delete rule |

### Alerts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/alerts` | List triggered alerts |
| GET | `/api/v1/alerts/{id}` | Get specific alert |
| PATCH | `/api/v1/alerts/{id}/acknowledge` | Acknowledge alert |
| PATCH | `/api/v1/alerts/acknowledge-all` | Acknowledge all |
| DELETE | `/api/v1/alerts/clear-acknowledged` | Delete acknowledged |
| GET | `/api/v1/alerts/device/{device_id}` | Device alerts |

### Users (Admin)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users` | List all users |
| GET | `/api/v1/users/{id}` | Get user details |
| DELETE | `/api/v1/users/{id}` | Delete user |
| PATCH | `/api/v1/users/{id}/toggle-admin` | Toggle admin status |

### WebSocket
| Endpoint | Description |
|----------|-------------|
| `/api/v1/ws/{device_id}` | Real-time temperature stream |
| `/api/v1/ws/all` | All devices stream |

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
python scripts/simulate_devices.py --count 3 --rate 2 --duration 30 --prefix TEST
```

## 🔔 Alert System

### Creating Alert Rules
1. Via Admin Panel: Select device, set min/max temp, click "Create Alert Rule"
2. Via API:
   ```
   POST /api/v1/devices/{id}/rules
   {"temp_min": 35.0, "temp_max": 39.0}
   ```

### When temperature exceeds thresholds:
- 🔥 **HIGH** alert if `temp > max`
- ❄️ **LOW** alert if `temp < min`
- Alert recorded in database
- Broadcast via WebSocket
- Displayed in admin panel (auto-refresh every 5s)
- Shown as banner in mobile app

### Managing Alerts
- **Acknowledge**: Mark alerts as seen
- **Acknowledge All**: Mark all as seen
- **Clear Acknowledged**: Delete acknowledged alerts only
- **Delete All**: Permanently delete ALL alerts (with confirmation)

## 🔒 Security Features

- **JWT Authentication** for API and admin panel
- **Role-based access** (superuser check for admin)
- **Last-admin protection**: Cannot delete/demote the only admin
- **Self-delete logout**: Admins are logged out if they delete themselves
- **Password visibility toggle** in login forms

## 📄 License

MIT License - See LICENSE file

## 👨‍💻 Author

**AbdulWaheed Habeeb**

Egg Guardian MVP - Final Year Project
