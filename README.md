# Smart Plug System

A complete IoT system for monitoring and controlling electrical devices using smart plugs. This project includes custom firmware for ESP8266/ESP32/Arduino R4 hardware and a Flutter mobile application that communicates through Firebase.

## Project Components

### 📱 Mobile App

A Flutter-based mobile application that allows users to:
- Monitor power consumption and temperature in real-time
- Control connected devices remotely
- Set timers and schedules for automated control
- Receive alerts for critical events
- View historical usage data and analytics

[Learn more about the Mobile App](mobile_app/README.md)

### ⚡ Firmware

Firmware for ESP8266, ESP32, or Arduino R4 WiFi boards that:
- Measures voltage, current, power consumption, and temperature
- Controls connected devices via relay
- Implements safety features (overcurrent protection, temperature monitoring)
- Communicates with Firebase in real-time
- Operates with basic functionality even when offline

[Learn more about the Firmware](firmware/README.md)

### 🔌 Hardware

Circuit designs and schematics for building your own smart plug with:
- Current and voltage sensing
- Temperature monitoring
- Relay control
- WiFi connectivity
- Safety features

See the `firmware/schematic/` directory for hardware design files.

## System Architecture

![Smart Plug System Architecture](docs/images/system_architecture.png)

1. **Smart Plug Hardware**: Physical devices with sensors and relay
2. **Firmware**: Code running on the microcontrollers
3. **Firebase Backend**: Cloud infrastructure for data storage and synchronization
4. **Mobile Application**: User interface for monitoring and control

## Getting Started

### Prerequisites

- Arduino IDE (for firmware development)
- Flutter SDK (for mobile app development)
- Firebase account
- Hardware components (see BOM in the hardware directory)

### Setup Instructions

1. **Clone the repository**
   ```
   git clone https://github.com/your-username/SmartPlugApp.git
   cd SmartPlugApp
   ```

2. **Set up Firebase**
   - Create a new Firebase project
   - Enable Authentication, Realtime Database, and Firestore
   - Configure security rules
   - Add the appropriate config files to the mobile app

3. **Firmware Setup**
   - Choose your hardware platform (ESP8266, ESP32, or Arduino R4)
   - Follow the instructions in the [firmware README](firmware/README.md)
   - Configure WiFi and Firebase credentials
   - Upload the firmware to your device

4. **Mobile App Setup**
   - Follow the instructions in the [mobile app README](mobile_app/README.md)
   - Configure the Firebase connection
   - Build and install the app on your device

5. **Test the System**
   - Verify that the hardware connects to Firebase
   - Confirm that the mobile app can read data and send commands
   - Test safety features and automation capabilities

## Key Features

- **Real-time Monitoring**: View power usage and device status in real-time
- **Remote Control**: Turn devices on/off from anywhere
- **Energy Analytics**: Track usage patterns and identify energy-saving opportunities
- **Scheduling & Automation**: Set timers and recurring schedules
- **Safety Features**: Automatic shutoff for overcurrent or overtemperature conditions
- **Multi-user Access**: Share device control with family members
- **Offline Operation**: Basic functionality continues when internet is unavailable
- **Cross-platform Support**: Works on iOS and Android devices

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Firebase for providing the backend infrastructure
- Flutter team for the excellent cross-platform framework
- Arduino community for hardware and library support
