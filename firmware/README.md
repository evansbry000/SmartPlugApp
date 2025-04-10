# Smart Plug Firmware

This directory contains the firmware implementations for the Smart Plug hardware. The firmware allows ESP8266/ESP32 and Arduino R4 WiFi boards to monitor power consumption, control connected devices, and communicate with the Firebase backend.

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
- **OTA Updates**: Support for over-the-air firmware updates
- **Scheduled Operations**: Timer and scheduling functionality

## Supported Hardware

### Arduino R4 WiFi (Recommended)
- All-in-one solution with integrated WiFi
- Enhanced processing power and memory
- Built-in security features
- See [NewSetup/README.md](NewSetup/README.md) for details

### ESP32
- More powerful alternative to ESP8266
- Supports Bluetooth in addition to WiFi
- Better performance for complex operations
- Located in `Old Setup/esp32/`

### ESP8266
- Original implementation
- Lower cost option
- Sufficient for basic monitoring and control
- Located in `Old Setup/esp8266/`

## Getting Started

1. Choose the appropriate hardware platform for your needs
2. Install the required libraries (see `libraries.md` in the respective directories)
3. Configure the firmware with your WiFi credentials and Firebase details
4. Upload the firmware using the Arduino IDE or PlatformIO
5. Test the connection using the serial monitor
6. Deploy the hardware in your target environment

## Firebase Integration

The firmware connects to two Firebase services:

1. **Realtime Database**: For real-time data publishing and command reception
2. **Firebase Storage**: For firmware updates and configuration files

The data structure in Firebase Realtime Database follows this pattern:

```
/devices/{device_id}/
  /current_data/         # Real-time sensor values
    current: float
    voltage: float
    power: float
    temperature: float
    relay_state: boolean
    timestamp: number
  /commands/             # Incoming commands from app
    /relay/              # Relay control commands
    /timer/              # Timer settings
    /schedule/           # Scheduling data
  /events/               # Device-generated events
  /connection/           # Connection status info
    last_seen: number
```

## Contributing

Contributions to the firmware are welcome! Please consider the following:

1. Test all changes thoroughly before submitting pull requests
2. Maintain backward compatibility where possible
3. Document any new features or changes to existing functionality
4. Follow the coding style of the existing codebase
5. Consider power consumption and reliability implications

## License

This firmware is licensed under the MIT License - see the LICENSE file for details. 