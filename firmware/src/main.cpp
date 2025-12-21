/**
 * Egg Guardian Firmware
 * 
 * ESP32-based egg temperature monitoring with MQTT publishing.
 * 
 * Hardware:
 * - ESP32 DevKitC
 * - DS18B20 temperature sensor on GPIO4
 * - 4.7kΩ pull-up resistor
 * 
 * Features:
 * - Reads temperature from DS18B20
 * - Publishes to MQTT topic egg/{device_id}/telemetry
 * - Buffers readings when offline (max 20)
 * - Automatic reconnection
 */

#include <Arduino.h>
#include <WiFi.h>
#include <MQTT.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>

// Include config (copy config.h.example to config.h)
#include "config.h"

// Sensor setup
OneWire oneWire(ONE_WIRE_PIN);
DallasTemperature sensors(&oneWire);

// MQTT client
WiFiClient net;
MQTTClient client;

// Telemetry buffer for offline storage
struct TelemetryPoint {
    float temp_c;
    unsigned long timestamp;
};

TelemetryPoint telemetryBuffer[MAX_BUFFER_SIZE];
int bufferIndex = 0;
bool bufferFull = false;

// Timing
unsigned long lastTempRead = 0;
unsigned long lastMqttPublish = 0;

// Function declarations
void connectWiFi();
void connectMQTT();
void readTemperature();
void publishTelemetry(float temp_c);
void publishBuffered();
String formatISO8601(unsigned long timestamp);

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n=== Egg Guardian Firmware ===");
    Serial.printf("Device ID: %s\n", DEVICE_ID);
    
    // Initialize temperature sensor
    sensors.begin();
    int deviceCount = sensors.getDeviceCount();
    Serial.printf("Found %d DS18B20 sensor(s)\n", deviceCount);
    
    if (deviceCount == 0) {
        Serial.println("WARNING: No temperature sensors found!");
    }
    
    // Connect to WiFi and MQTT
    connectWiFi();
    
    // Setup MQTT
    client.begin(MQTT_BROKER, MQTT_PORT, net);
    connectMQTT();
    
    Serial.println("Setup complete. Starting monitoring...\n");
}

void loop() {
    // Maintain MQTT connection
    client.loop();
    
    if (!client.connected()) {
        connectMQTT();
    }
    
    // Read temperature at interval
    if (millis() - lastTempRead >= TEMP_READ_INTERVAL_MS) {
        readTemperature();
        lastTempRead = millis();
    }
    
    // Publish at interval
    if (millis() - lastMqttPublish >= MQTT_PUBLISH_INTERVAL_MS) {
        if (client.connected()) {
            // Publish any buffered readings first
            publishBuffered();
            
            // Read and publish current temperature
            sensors.requestTemperatures();
            float temp = sensors.getTempCByIndex(0);
            if (temp != DEVICE_DISCONNECTED_C) {
                publishTelemetry(temp);
            }
        }
        lastMqttPublish = millis();
    }
    
    delay(100);  // Small delay to prevent watchdog issues
}

void connectWiFi() {
    Serial.printf("Connecting to WiFi: %s", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println(" Connected!");
        Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println(" Failed!");
        Serial.println("Will retry in background...");
    }
}

void connectMQTT() {
    if (WiFi.status() != WL_CONNECTED) {
        connectWiFi();
        return;
    }
    
    Serial.printf("Connecting to MQTT: %s:%d...", MQTT_BROKER, MQTT_PORT);
    
    String clientId = String(DEVICE_ID) + "-" + String(random(1000, 9999));
    
    if (client.connect(clientId.c_str(), MQTT_USER, MQTT_PASSWORD)) {
        Serial.println(" Connected!");
    } else {
        Serial.println(" Failed!");
        delay(5000);
    }
}

void readTemperature() {
    sensors.requestTemperatures();
    float temp = sensors.getTempCByIndex(0);
    
    if (temp == DEVICE_DISCONNECTED_C) {
        Serial.println("Error: Sensor disconnected");
        return;
    }
    
    Serial.printf("Temperature: %.2f°C\n", temp);
    
    // If MQTT disconnected, buffer the reading
    if (!client.connected()) {
        telemetryBuffer[bufferIndex].temp_c = temp;
        telemetryBuffer[bufferIndex].timestamp = millis();
        bufferIndex = (bufferIndex + 1) % MAX_BUFFER_SIZE;
        if (bufferIndex == 0) bufferFull = true;
        Serial.printf("Buffered reading (count: %d)\n", 
                      bufferFull ? MAX_BUFFER_SIZE : bufferIndex);
    }
}

void publishTelemetry(float temp_c) {
    StaticJsonDocument<200> doc;
    doc["device_id"] = DEVICE_ID;
    doc["ts"] = formatISO8601(millis());
    doc["temp_c"] = temp_c;
    
    char payload[200];
    serializeJson(doc, payload);
    
    String topic = String("egg/") + DEVICE_ID + "/telemetry";
    
    if (client.publish(topic.c_str(), payload)) {
        Serial.printf("Published: %s\n", payload);
    } else {
        Serial.println("Publish failed!");
    }
}

void publishBuffered() {
    int count = bufferFull ? MAX_BUFFER_SIZE : bufferIndex;
    if (count == 0) return;
    
    Serial.printf("Publishing %d buffered readings...\n", count);
    
    for (int i = 0; i < count; i++) {
        publishTelemetry(telemetryBuffer[i].temp_c);
        delay(50);  // Small delay between publishes
    }
    
    // Clear buffer
    bufferIndex = 0;
    bufferFull = false;
}

String formatISO8601(unsigned long timestamp) {
    // For demo, use a simple timestamp format
    // In production, use NTP time
    char buffer[30];
    snprintf(buffer, sizeof(buffer), "2025-01-01T00:00:%02lu.000Z", 
             (timestamp / 1000) % 60);
    return String(buffer);
}
