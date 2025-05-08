# Smart Plug System

A complete IoT system for monitoring and controlling electrical devices using smart plugs. This project includes custom firmware for Arduino R4 WiFi hardware and a Flutter mobile application that communicates through Firebase.

## Project Components

### 📱 Mobile App

A Flutter-based mobile application that allows users to:
- Monitor power consumption and temperature in real-time
- Control connected devices remotely
- Receive alerts for critical events
- View historical usage data and analytics

[Learn more about the Mobile App](mobile_app/README.md)

### ⚡ Firmware

Firmware for Arduino R4 WiFi boards that:
- Measures voltage, current, power consumption, and temperature
- Controls connected devices via relay
- Implements safety features (overcurrent protection, temperature monitoring)
- Communicates with Firebase in real-time
- Operates with basic functionality even when offline

[Learn more about the Firmware](firmware/README.md)

### 🔌 Hardware

Circuit designs and schematics for building your own smart plug with:
- Current and voltage sensing (using ACS712 with peak-to-peak measurement)
- Temperature monitoring (using LM35)
- Relay control (active-LOW relay modules)
- WiFi connectivity (built into Arduino R4 WiFi)
- Safety features

[Learn more about the Hardware](firmware/schematic/README.md)

## System Architecture

1. **Smart Plug Hardware**: Physical device with sensors and relay
2. **Arduino R4 Firmware**: Code running on the Arduino R4 WiFi
3. **Firebase Backend**: Cloud infrastructure for data storage and synchronization
4. **Flutter Mobile App**: User interface for monitoring and control

## Data Structure

This project uses a standardized data structure for communication between devices and the app:

```
/smart_plugs/{device_id}/
  /status/               # Real-time sensor values
  /commands/             # Commands for device control
  /events/               # Device-generated events
```

For detailed information about the data structure, Firebase paths, and communication protocols, see [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md).

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
   - Configure security rules as defined in `database.rules.json`
   - Add the appropriate config files to the mobile app

3. **Firmware Setup**
   - Follow the instructions in the [firmware README](firmware/README.md)
   - Configure WiFi and Firebase credentials in the sketch
   - Upload the firmware to your Arduino R4 WiFi

4. **Mobile App Setup**
   - Follow the instructions in the [mobile app README](mobile_app/README.md)
   - Configure the Firebase connection
   - Build and install the app on your device

## Key Features

- **Real-time Monitoring**: View power usage and device status in real-time
- **Remote Control**: Turn devices on/off from anywhere
- **Energy Analytics**: Track usage patterns and identify energy-saving opportunities
- **Safety Features**: Automatic shutoff for overcurrent or overtemperature conditions
- **Multi-user Access**: Share device control with family members
- **Offline Operation**: Basic functionality continues when internet is unavailable
- **Cross-platform Support**: Works on iOS and Android devices

## Technical Implementation Details

- **Current Sensing**: Uses peak-to-peak voltage measurement for accurate AC current sensing
- **Relay Control**: Active-LOW relay module implementation (LOW=ON, HIGH=OFF)
- **Time Synchronization**: Device uptime-based timestamps with client-side conversion to real time
- **Service Architecture**: Modular services following SOLID principles
- **Data Mirroring**: Realtime Database to Firestore mirroring for analytics and queries

## Contributing

Contributions are welcome! Please see our [contribution guidelines](CONTRIBUTING.md) for more information.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Firebase for providing the backend infrastructure
- Flutter team for the excellent cross-platform framework
- Arduino community for hardware and library support
