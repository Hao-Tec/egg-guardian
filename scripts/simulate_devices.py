#!/usr/bin/env python3
"""
Egg Guardian Device Simulator

Simulates multiple egg monitoring devices publishing telemetry to MQTT.
Used for testing without hardware.

Usage:
    python simulate_devices.py --count 1 --rate 1 --duration 30

Args:
    --count: Number of simulated devices (default: 1)
    --rate: Readings per second per device (default: 1)
    --duration: Duration in seconds (default: 30)
    --broker: MQTT broker address (default: localhost)
    --port: MQTT broker port (default: 1883)
"""

import argparse
import json
import random
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt


def generate_temperature(base_temp: float = 37.5, variance: float = 2.0) -> float:
    """Generate a realistic egg incubator temperature."""
    return round(base_temp + random.uniform(-variance, variance), 2)


def publish_telemetry(
    client: mqtt.Client,
    device_id: str,
    temp_c: float,
) -> bool:
    """Publish a telemetry message to MQTT."""
    topic = f"egg/{device_id}/telemetry"
    payload = {
        "device_id": device_id,
        "ts": datetime.now(timezone.utc).isoformat(),
        "temp_c": temp_c,
    }
    result = client.publish(topic, json.dumps(payload), qos=1)
    return result.rc == mqtt.MQTT_ERR_SUCCESS


def on_connect(client, userdata, flags, rc, properties=None):
    """MQTT connection callback."""
    if rc == 0:
        print("✅ Connected to MQTT broker")
    else:
        print(f"❌ Connection failed with code {rc}")


def on_publish(client, userdata, mid, properties=None, reason_code=None):
    """MQTT publish callback."""
    userdata["published"] += 1


def main():
    parser = argparse.ArgumentParser(
        description="Simulate egg monitoring devices"
    )
    parser.add_argument(
        "--count", type=int, default=1,
        help="Number of simulated devices"
    )
    parser.add_argument(
        "--rate", type=float, default=1.0,
        help="Readings per second per device"
    )
    parser.add_argument(
        "--duration", type=int, default=30,
        help="Duration in seconds"
    )
    parser.add_argument(
        "--broker", type=str, default="localhost",
        help="MQTT broker address"
    )
    parser.add_argument(
        "--port", type=int, default=11883,
        help="MQTT broker port"
    )
    parser.add_argument(
        "--prefix", type=str, default="eggpod",
        help="Device ID prefix (e.g., 'TEST' creates 'TEST-01')"
    )
    
    args = parser.parse_args()
    
    # Device IDs - use custom prefix if provided
    devices = [f"{args.prefix}-{i+1:02d}" if args.count > 1 else args.prefix 
               for i in range(args.count)]
    
    # MQTT setup
    userdata = {"published": 0}
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=f"simulator-{random.randint(1000, 9999)}",
        userdata=userdata,
    )
    client.on_connect = on_connect
    client.on_publish = on_publish
    
    print(f"🥚 Egg Guardian Device Simulator")
    print(f"   Devices: {args.count}")
    print(f"   Rate: {args.rate}/s per device")
    print(f"   Duration: {args.duration}s")
    print(f"   Broker: {args.broker}:{args.port}")
    print()
    
    try:
        client.connect(args.broker, args.port, 60)
        client.loop_start()
        
        interval = 1.0 / args.rate
        start_time = time.time()
        
        while time.time() - start_time < args.duration:
            for device_id in devices:
                temp = generate_temperature()
                success = publish_telemetry(client, device_id, temp)
                status = "✓" if success else "✗"
                print(f"[{device_id}] {status} temp_c={temp}°C")
            
            time.sleep(interval)
        
        # Wait for publishes to complete
        time.sleep(1)
        client.loop_stop()
        client.disconnect()
        
        print()
        print(f"✅ Simulation complete!")
        print(f"   Total messages published: {userdata['published']}")
        
    except ConnectionRefusedError:
        print(f"❌ Could not connect to MQTT broker at {args.broker}:{args.port}")
        print("   Make sure the broker is running (docker-compose up)")
        return 1
    except KeyboardInterrupt:
        print("\n⏹️ Simulation stopped by user")
        client.loop_stop()
        client.disconnect()
    
    return 0


if __name__ == "__main__":
    exit(main())
