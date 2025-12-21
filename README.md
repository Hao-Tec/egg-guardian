# Egg Guardian

Real-time egg temperature monitoring system with IoT sensors and mobile app.

## Quick Start

### Prerequisites
- Docker Desktop
- Flutter SDK (web enabled)
- Python 3.11+

### Run Locally

```bash
# Start all services
docker-compose up --build

# Verify health
curl http://localhost:8000/healthz
```

### Services

| Service | Port | Description |
|---------|------|-------------|
| API | 8000 | FastAPI backend |
| Mosquitto | 1883 | MQTT broker |
| PostgreSQL | 5432 | Database |

### Project Structure

```
egg-guardian/
├── docker-compose.yml
├── firmware/          # ESP32 Arduino code
├── services/api/      # FastAPI backend
├── mobile/            # Flutter web app
├── admin/             # Admin dashboard
├── scripts/           # Utility scripts
├── tests/             # Test suites
└── docs/              # Documentation
```

## Development

### Simulate Devices
```bash
python scripts/simulate_devices.py --count 1 --rate 1 --duration 30
```

### Run Tests
```bash
docker-compose exec api pytest -v
```

### API Documentation
Visit http://localhost:8000/docs for Swagger UI

## License

MIT
