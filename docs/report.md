# Egg Guardian - Technical Report

## Table of Contents

1. [Introduction](#introduction)
2. [System Architecture](#system-architecture)
3. [Implementation](#implementation)
4. [Testing](#testing)
5. [Results](#results)
6. [Conclusion](#conclusion)

---

## 1. Introduction

### 1.1 Background

Egg incubation requires precise temperature control within the range of 37-39°C. Traditional monitoring relies on manual checks, risking delayed response to temperature deviations that can harm embryo development.

### 1.2 Objectives

- Develop an IoT-based temperature monitoring system
- Provide real-time alerts for temperature anomalies
- Create a mobile-accessible dashboard for monitoring
- Demonstrate end-to-end system integration

### 1.3 Scope

This MVP focuses on single-device monitoring with essential alerting capabilities, designed for demonstration and small-scale pilot deployment.

---

## 2. System Architecture

### 2.1 Overview

```
┌─────────────────┐     MQTT      ┌─────────────────┐
│   ESP32 + DS18B20│─────────────▶│   Mosquitto     │
│   (Firmware)     │              │   (Broker)      │
└─────────────────┘              └────────┬────────┘
                                          │
                                          ▼
┌─────────────────┐              ┌─────────────────┐
│   PostgreSQL    │◀─────────────│   FastAPI       │
│   (Database)    │              │   (Backend)     │
└─────────────────┘              └────────┬────────┘
                                          │ WebSocket
                                          ▼
                                 ┌─────────────────┐
                                 │   Flutter Web   │
                                 │   (Mobile App)  │
                                 └─────────────────┘
```

### 2.2 Component Details

#### 2.2.1 Firmware (ESP32)
- Reads DS18B20 temperature sensor via OneWire protocol
- Publishes telemetry to MQTT topic `egg/{device_id}/telemetry`
- Implements local buffering (20 readings) for network resilience
- Automatic WiFi and MQTT reconnection

#### 2.2.2 Backend (FastAPI)
- Subscribes to MQTT telemetry topics
- Persists readings to PostgreSQL with timestamp indexing
- Evaluates alert rules on each reading
- Provides REST API and WebSocket endpoints

#### 2.2.3 Mobile App (Flutter)
- JWT-based authentication
- Real-time chart using WebSocket connection
- Push notification integration (FCM)
- Works on web, iOS, and Android

---

## 3. Implementation

### 3.1 Telemetry Flow

1. Sensor reads temperature every 5 seconds
2. Firmware publishes JSON payload every 10 seconds
3. Backend persists to `telemetry` table
4. Alert worker evaluates rules
5. WebSocket broadcasts to connected clients

### 3.2 Data Model

```sql
-- Telemetry table
CREATE TABLE telemetry (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50),
    temp_c DECIMAL(5,2),
    recorded_at TIMESTAMP WITH TIME ZONE
);

-- Alert rules
CREATE TABLE alert_rules (
    id SERIAL PRIMARY KEY,
    device_id INTEGER REFERENCES devices(id),
    temp_min DECIMAL(5,2),
    temp_max DECIMAL(5,2),
    is_active BOOLEAN DEFAULT true
);
```

### 3.3 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Health check |
| POST | `/api/v1/auth/login` | User login |
| GET | `/api/v1/devices` | List devices |
| POST | `/api/v1/devices` | Register device |
| GET | `/api/v1/devices/{id}/telemetry` | Get history |
| WS | `/api/v1/ws/{device_id}` | Real-time stream |

---

## 4. Testing

### 4.1 Unit Tests
- Config loading validation
- Telemetry schema validation
- JWT token generation/verification

### 4.2 Integration Tests
- MQTT message ingestion
- Database persistence
- Alert triggering

### 4.3 Acceptance Tests
- End-to-end telemetry flow
- Alert notification delivery
- WebSocket real-time updates

---

## 5. Results

### 5.1 Performance Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| Telemetry latency | < 3s | ~500ms |
| Alert detection | < 5s | ~1s |
| Message loss | < 1% | 0% (local test) |

### 5.2 Demo Verification

- Successfully demonstrated device simulation
- Alert rules triggered correctly
- Mobile app displayed real-time updates

---

## 6. Conclusion

### 6.1 Achievements
- Complete end-to-end IoT monitoring system
- Real-time data visualization
- Configurable alerting

### 6.2 Future Work
- Multi-device support
- Historical analytics
- Native mobile apps
- TLS encryption

---

## References

1. ESP32 Documentation - Espressif Systems
2. FastAPI Documentation - tiangolo
3. Flutter Documentation - Google
4. MQTT Protocol - OASIS Standard

---

*Final Year Project - December 2025*
