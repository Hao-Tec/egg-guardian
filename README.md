# Egg Guardian
<p align="center">
  <img src="assets/images/logo.jpg" alt="Egg Guardian Logo" width="150" height="150" style="border-radius: 20px;">
</p>

**Real-time IoT Egg Temperature Monitoring System**

A comprehensive, production-ready IoT solution designed for real-time monitoring of egg incubators. This project leverages a robust architecture featuring a FastAPI backend, a cross-platform Flutter mobile application, an ESP32 hardware firmware component, and a dedicated web-based administrative dashboard. Engineered as a professional solution and Final Year Project, it demonstrates end-to-end integration of MQTT telemetry, secure RESTful APIs, and intelligent alerting mechanisms designed to prevent incubation failure.

---

## Features

### Mobile App (Flutter)
- **Elegant UI**: Professionally designed interface with a clean, intuitive layout focusing on user experience.
- **Live Telemetry**: Real-time temperature charts utilizing `fl_chart` with safe-zone dynamic dashed lines for visual monitoring.
- **Dynamic Thresholds**: Retrieves exact minimum and maximum threshold rules from the backend per device to accurately compute and display statuses such as "Optimal", "Too Hot", and "Too Cold".
- **Push Notifications**: Firebase Cloud Messaging (FCM) integration ensuring background alerts are delivered promptly.
- **Security**: Complete JWT Authentication flow, visible password toggles, and strict role-based routing.

### Admin Dashboard (Web)
- **Modern Interface**: Sidebar-based navigation, glassmorphism design system, and Chart.js integration for real-time visualization.
- **Device Management**: Register devices, assign names, and configure dynamic, device-specific alert rules.
- **Live Monitor**: Stream incoming MQTT temperature data instantly via WebSockets without page reloads.
- **Alert Triage**: View, acknowledge, and clear temperature alerts as they happen in real-time.
- **User Control**: Manage system users, toggle administrative privileges, and utilize built-in protections against self-lockouts.

### Backend API (FastAPI)
- **Robust Architecture**: Built with FastAPI, SQLAlchemy, and AsyncPG for high performance and asynchronous database operations.
- **MQTT Integration**: Direct ingestion of IoT telemetry from Mosquitto MQTT brokers.
- **Smart Alerting Engine**: Automatically triggers alerts and dispatches emails (SMTP) alongside push notifications (FCM) whenever a sensor reading violates its configured rule.
- **Secure Infrastructure**: Password hashing via Bcrypt, secure JWT token validation, and CORS protection.

### Firmware (ESP32)
- **IoT Ready**: C++ Firmware built using the Arduino framework and PlatformIO.
- **Hardware Integration**: Interfaces directly with DS18B20 1-Wire precision temperature sensors.
- **Offline Buffering**: Intelligently buffers telemetry locally when Wi-Fi connectivity is lost, flushing the queue to the server upon reconnection.

---

## Project Structure

We maintain a clean and modular separation of concerns. 
**[View Detailed Project Structure](docs/PROJECT_STRUCTURE.md)**

---

## Quick Start (Local Development)

### Prerequisites
- **Docker Desktop** (Windows/Mac) or Docker + Docker Compose (Linux)
- **Python 3.11+**
- **Flutter SDK**

### 1. Setup Environment
Clone the repository from the original author or your fork:
```bash
git clone https://github.com/Hao-Tec/egg-guardian.git
cd egg-guardian
cp .env.example .env
```
*Note: Edit `.env` to include your Gmail App Passwords if you want to test SMTP locally.*

### 2. Start Backend Services
Start the PostgreSQL database, Mosquitto MQTT broker, and FastAPI server:
```bash
docker-compose up --build
```
- **API Docs (Swagger)**: http://localhost:8000/docs
- **Admin Dashboard**: Open `admin/index.html` in your browser. (Since we use relative paths, it will automatically connect to your local backend).

### 3. Run Mobile App
Run the Flutter app on an emulator or physical device. 

**Important Note on IP Addresses:** 
If you are testing locally on a physical phone connected to your PC's Wi-Fi hotspot, you must pass your PC's Local IP address using the `--dart-define` flag so the phone knows exactly how to route traffic to the local backend.
```bash
cd mobile/egg_guardian
flutter pub get
# Example for local testing (replace with your actual PC IP)
flutter run --dart-define=API_HOST=192.168.1.100
```
*If you deploy the backend to the cloud (e.g., Render) and attach a domain, local IPs are no longer required. You would simply pass `--dart-define=API_HOST=api.egg-guardian.com` and the application will work globally.*

### 4. Run IoT Simulator
If you do not have the ESP32 hardware available, you can simulate IoT devices injecting data into the MQTT broker:
```bash
pip install paho-mqtt
python scripts/simulate_devices.py --count 1 --rate 1 --duration 60
```

**Simulator Parameters Explained:**
- `--count` (Integer): Determines the number of mock devices to simulate concurrently. Setting this to `3` will create three separate virtual ESP32 sensors publishing data.
- `--rate` (Integer): Specifies the frequency of telemetry publishing in seconds. A rate of `1` means each mock device will publish a new temperature reading every 1 second.
- `--duration` (Integer): The total length of the simulation in seconds. A duration of `60` means the script will run and generate data for exactly one minute before automatically terminating.

---

## Production Deployment (Render)

This repository includes a `render.yaml` blueprint for one-click deployment to **Render.com**.

1. Create a [Render](https://render.com) account and connect your GitHub repository.
2. Click **New** > **Blueprint** and select your repository.
3. Render will automatically provision:
   - A Managed PostgreSQL Database.
   - A Python Web Service (FastAPI).
   - A Static Web Site (Admin Dashboard).
4. Fill in the required Environment Variables in the Render Dashboard (e.g., SMTP settings, JWT secrets).

*Note: For the MQTT Broker, it is recommended to create a free cloud instance on HiveMQ or EMQX and place the connection credentials in your Render Environment Variables.*

---

## Email Alerts (SMTP)

Egg Guardian utilizes SMTP protocols to dispatch email alerts when an egg pod temperature breaches safe parameters. To configure this utilizing a Gmail account:
1. Navigate to your Google Account > Security > 2-Step Verification.
2. Scroll to **App Passwords** and generate a new password designated for "Egg Guardian".
3. Insert this 16-character password into your `.env` (or Render Dashboard) under `SMTP_PASSWORD`.
4. Ensure `SMTP_HOST=smtp.gmail.com` and `SMTP_PORT=587`.

---

## Push Notifications (Firebase)

To enable production push notifications for Android devices:
1. Create a project at the [Firebase Console](https://console.firebase.google.com/).
2. Add an Android App (package name: `com.example.egg_guardian`).
3. Download `google-services.json` and place it in the `mobile/egg_guardian/android/app/` directory.
4. Navigate to Project Settings > Service Accounts > Generate New Private Key.
5. Download the JSON file, rename it to exactly `firebase-adminsdk.json`, and place it in the project root.
6. Set `FCM_MOCK_MODE=false` in your `.env`.

---

## License
MIT License - See LICENSE file

---
**Egg Guardian MVP - Final Year Project**
*Developed by [AbdulWaheed Habeeb](https://github.com/Hao-Tec)*
