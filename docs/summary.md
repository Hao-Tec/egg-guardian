# Egg Guardian - Executive Summary

## Project Overview

Egg Guardian is a production-ready IoT solution for real-time temperature monitoring of commercial egg incubators. The system provides continuous sensor telemetry, an intelligent alerting engine, a cross-platform mobile application, and a dedicated administrative dashboard.

Built as a Final Year Project, it demonstrates a complete end-to-end integration of hardware firmware, a cloud-ready REST API, MQTT-based IoT data ingestion, and professional mobile application development.

---

## Problem Statement

Commercial egg incubation requires precise temperature control within the range of 37-39°C. Deviations sustained for even a few minutes can cause irreversible embryo damage. Traditional monitoring depends on scheduled manual checks, creating large windows of undetected risk. Egg Guardian eliminates this risk through continuous automated monitoring and sub-2-second alert delivery.

---

## Technical Stack

| Component       | Technology                |
|-----------------|---------------------------|
| Firmware        | ESP32 + DS18B20 (C++ / Arduino) |
| Backend         | FastAPI (Python 3.11)     |
| Database        | PostgreSQL 15             |
| Message Broker  | Mosquitto MQTT            |
| Mobile App      | Flutter (Android / Web)   |
| Admin Dashboard | HTML, CSS, Vanilla JS     |
| Email Alerts    | SMTP / Gmail App Password |
| Push Alerts     | Firebase Cloud Messaging  |
| Cloud Hosting   | Render.com                |

---

## System Architecture

```
[ESP32 Sensor] --> [MQTT Broker] --> [FastAPI Backend] --> [PostgreSQL]
                                          |
                                     [Alert Engine]
                                    /              \
                              [SMTP Email]    [FCM Notification]
                                    |
                               [WebSocket]
                                    |
                         [Flutter Mobile App / Admin Dashboard]
```

---

## MVP Scope

1. Multi-device monitoring with per-device alert rule configuration.
2. Dynamic temperature threshold alerts (high/low configurable from the Admin Dashboard).
3. 24-hour telemetry history visualization with live chart updates.
4. Cross-platform mobile application (Android and Web).
5. Full administrative control panel for users, devices, and alerts.

---

## Future Roadmap

- Multi-facility and greenhouse monitoring
- Humidity and CO2 sensor integration
- Predictive analytics and AI-powered anomaly detection
- Native iOS application

---

*Prepared for Final Year Project Examination*
*Developed by [AbdulWaheed Habeeb](https://github.com/Hao-Tec)*
