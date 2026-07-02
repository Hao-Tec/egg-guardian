# Egg Guardian Project Structure

This document provides a comprehensive overview of the directory structure and file organization for the Egg Guardian project. This structure is designed to support a scalable, production-ready IoT solution.

```text
egg-guardian/
├── services/api/          # FastAPI backend (Core Logic & IoT Ingestion)
│   ├── app/
│   │   ├── main.py        # App entry point & CORS configuration
│   │   ├── config.py      # Environment variables (Pydantic Settings)
│   │   ├── database.py    # SQLAlchemy AsyncPG setup
│   │   ├── models/        # Database models (User, Device, Alert, AlertRule, Telemetry)
│   │   ├── schemas/       # Pydantic schemas for data validation
│   │   ├── routers/       # REST API endpoints
│   │   │   ├── auth.py    # Authentication (Login, Register, Refresh)
│   │   │   ├── devices.py # Device CRUD & dynamic threshold injection
│   │   │   ├── users.py   # Admin user management
│   │   │   ├── alerts.py  # Alert fetching and acknowledgement
│   │   │   └── telemetry.py
│   │   ├── services/      # Business logic
│   │   │   ├── mqtt.py    # MQTT background tasks (Telemetery ingestion & Rule evaluation)
│   │   │   ├── email.py   # SMTP alert dispatching
│   │   │   └── auth.py    # Password hashing and JWT generation
│   │   └── static/        # Favicon, assets
│   ├── requirements.txt
│   └── Dockerfile         # Docker configuration for production builds
│
├── mobile/egg_guardian/   # Flutter Application (Cross-Platform)
│   ├── lib/
│   │   ├── main.dart      # Flutter entry point & routing
│   │   ├── config.dart    # Environment injection via dart-define
│   │   ├── theme.dart     # Centralized color palettes and styling
│   │   ├── models.dart    # Dart data classes for API responses
│   │   ├── screens/       # UI Views
│   │   │   ├── login_screen.dart
│   │   │   ├── device_list_screen.dart
│   │   │   ├── device_detail_screen.dart (FlChart live monitoring)
│   │   │   └── admin_screen.dart
│   │   └── services/      
│   │       ├── api_service.dart      # HTTP wrapper
│   │       ├── session_service.dart  # Secure JWT storage
│   │       └── websocket_service.dart# Real-time WebSocket subscriptions
│   ├── android/           # Android native builds & Firebase config (google-services.json)
│   └── pubspec.yaml       # Flutter dependencies
│
├── firmware/              # ESP32 Firmware (C++ / Arduino)
│   ├── src/
│   │   ├── main.cpp       # Telemetry reading, offline buffering, MQTT publish
│   │   └── config.h       # Wi-Fi & MQTT credentials
│   └── platformio.ini     # Build configuration
│
├── admin/                 # Web Admin Dashboard (Vanilla JS/HTML/CSS)
│   ├── index.html         # Main dashboard layout
│   ├── styles.css         # Styling and glassmorphism effects
│   └── app.js             # Dynamic DOM rendering and WebSocket handling
│
├── scripts/               # Utility Scripts
│   └── simulate_devices.py# Python script to mock IoT sensors publishing to MQTT
│
├── render.yaml            # Blueprint for 1-click cloud deployment on Render.com
├── docker-compose.yml     # Local orchestration (DB, Broker, API, Mailhog)
├── .env.example           # Template for environment variables (SMTP, JWT, DB)
└── README.md              # Project overview and setup instructions
```
