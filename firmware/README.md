# Smart Plug Firmware

This directory contains the firmware implementations for the Smart Plug hardware. The firmware allows Arduino R4 WiFi boards to monitor power consumption, control connected devices, and communicate with the Firebase backend.

## Directory Structure

- **NewSetup/** - Current implementation using Arduino R4 WiFi
  - `arduinor4full/` - Production firmware for Arduino R4
  - `firebasetest/` - Testing utilities for Firebase connectivity
  - `libraries.md` - Documentation for required libraries
  - `trust_anchors.h` - SSL certificates for secure communication

- **Old Setup/** - Previous implementation using ESP8266/ESP32
  - `esp8266/` - Legacy firmware for ESP8266 modules
  - `esp32/` - Firmware for ESP32 modules with enhanced capabilities

- **schematic/** - Hardware design files and circuit diagrams

## Features

- **Power Monitoring**: Measures voltage, current, and power consumption
- **Temperature Monitoring**: Tracks device and environmental temperature
- **Remote Control**: Relay control through Firebase commands
- **Data Publishing**: Real-time data upload to Firebase Realtime Database
- **Safety Features**: Automatic shutoff for overcurrent or overtemperature conditions
- **Offline Operation**: Continues to function with basic features when WiFi is unavailable
- **Scheduled Operations**: Timer and scheduling functionality

## Supported Hardware

### Arduino R4 WiFi (Current Implementation)
- All-in-one solution with integrated WiFi
- Enhanced processing power and memory
- Built-in security features
- See [NewSetup/README.md](NewSetup/README.md) for details

### ESP32 & ESP8266 (Legacy Support)
- Original implementations
- Located in `Old Setup/` directory
- Maintained for reference and legacy devices

## Getting Started

1. Use the Arduino R4 WiFi firmware in the NewSetup directory
2. Install the required libraries (see `NewSetup/libraries.md`)
3. Configure the firmware with your WiFi credentials and Firebase details
4. Upload the firmware using the Arduino IDE
5. Test the connection using the serial monitor
6. Deploy the hardware in your target environment

## Hardware Connections

- **A0**: ACS712 Current Sensor
- **A1**: LM35 Temperature Sensor
- **D7**: Relay Control (Active-LOW)
- **LED_BUILTIN**: Status indicator

## Relay Control

The firmware is designed for active-LOW relay modules, which is the most common type:
- To turn the relay ON, the pin is set to LOW
- To turn the relay OFF, the pin is set to HIGH

```cpp
// Example relay control
void processRelay(bool state) {
  // When state is TRUE (ON), we set pin LOW to activate the relay
  // When state is FALSE (OFF), we set pin HIGH to deactivate the relay
  digitalWrite(RELAY_PIN, state ? LOW : HIGH);
}
```

## Firebase Integration

The firmware connects to Firebase Realtime Database. All device data is stored under the standardized path:

```
/smart_plugs/{device_id}/
  /status/               # Real-time sensor values
    current: float
    voltage: float
    power: float
    temperature: float
    relayState: boolean
    timestamp: number
  /commands/             # Incoming commands from app
    /relay/              # Relay control commands
      state: boolean
      processed: boolean
      timestamp: number
  /events/               # Device-generated events
  /connection/           # Connection status info
    last_seen: number
```

See [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md) for the complete data structure specification.

## Time Synchronization

The firmware uses a simplified time approach based on device uptime:

1. The device records its start time at boot
2. All timestamps are based on device uptime (milliseconds since boot)
3. Timestamps are marked with `timestampType: "deviceTime"`
4. The mobile app converts device time to real time using the first connection as reference

This approach eliminates NTP dependency while still allowing for consistent time tracking.

## Current Sensing

The firmware uses a peak-to-peak voltage measurement approach for improved AC current sensing accuracy:

```cpp
float getVPP() {
  int maxValue = 0;
  int minValue = 1024;
  int readValue;
  
  // Sample for 500ms to balance accuracy with responsiveness
  uint32_t start_time = millis();
  while((millis()-start_time) < 500) {
    readValue = analogRead(CURRENT_SENSOR_PIN);
    // Record maximum and minimum values
    if (readValue > maxValue) {
      maxValue = readValue;
    }
    if (readValue < minValue) {
      minValue = readValue;
    }
    delayMicroseconds(200);
  }
   
  // Calculate peak-to-peak voltage
  float result = ((maxValue - minValue) * 5.0)/1024.0;
  return result;
}
```

This method measures the full AC waveform rather than just instantaneous values, providing more accurate readings for AC current.

## Contributing

Contributions to the firmware are welcome! Please consider the following:

1. Use the standardized Firebase paths defined in PROJECT_STRUCTURE.md
2. Test all changes thoroughly before submitting pull requests
3. Maintain backward compatibility where possible
4. Document any new features or changes to existing functionality

## License

This firmware is licensed under the MIT License - see the LICENSE file for details. 