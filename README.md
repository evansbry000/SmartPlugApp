# SmartPlugApp

A comprehensive smart plug system that monitors and controls high-power appliances using an Elegoo Uno R3 board with an ESP32 module.

## Project Structure

```
SmartPlugApp/
├── mobile_app/           # Flutter mobile application
├── firmware/            # ESP32 and Arduino firmware
│   ├── esp32/          # ESP32 code for WiFi and Firebase communication
│   └── arduino/        # Arduino Uno R3 code for sensor reading and relay control
└── firebase/           # Firebase configuration and rules
```

## Features

- Real-time power monitoring using voltage and current sensors
- Remote control of appliances via mobile app
- Power usage analytics and cost calculation
- Firebase backend integration for data storage and authentication
- Cross-platform mobile app (Android & iOS)

## Hardware Requirements

- Elegoo Uno R3 Board
- ESP32 Module
- Voltage Sensor
- Current Sensor
- Relay/Switch Module

## Software Requirements

- Flutter SDK
- Arduino IDE
- ESP32 Development Environment
- Firebase Account
- Android Studio / VS Code

## Setup Instructions

1. **Mobile App Setup**
   ```bash
   cd mobile_app
   flutter pub get
   ```

2. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication, Firestore, and Realtime Database
   - Add Firebase configuration files to the mobile app

3. **Firmware Setup**
   - Install required libraries in Arduino IDE
   - Configure ESP32 board settings
   - Upload firmware to respective boards

## Development Status

🚧 Project in development

## License

MIT License
