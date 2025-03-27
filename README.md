# Smart Plug App

A Flutter web application for monitoring and controlling smart plugs with real-time data visualization and temperature monitoring.

## Features

- User Authentication (Sign up, Login, Sign out)
- Real-time monitoring of:
  - Current consumption
  - Power usage
  - Temperature readings
  - Device state (off/idle/running)
  - Relay status
- Temperature warning system
- Historical data visualization
- Device control (toggle on/off)
- User settings and preferences
- Notification preferences

## Project Structure

```
SmartPlugApp/
├── mobile_app/                 # Flutter web application
│   ├── lib/
│   │   ├── screens/           # UI screens
│   │   ├── services/          # Business logic and Firebase services
│   │   ├── widgets/           # Reusable UI components
│   │   └── main.dart          # Application entry point
│   ├── web/                   # Web-specific files
│   └── pubspec.yaml           # Flutter dependencies
├── firmware/                   # Arduino and ESP32 firmware
│   ├── arduino/               # Arduino code for sensor reading
│   └── esp32/                 # ESP32 code for WiFi and Firebase
└── firestore.rules            # Firebase security rules
```

## Hardware Requirements

- ESP32 development board
- ACS712 current sensor (30A)
- LM35 temperature sensor
- Relay module
- Power supply
- USB cable for programming

## Software Requirements

- Flutter SDK
- Firebase CLI
- Arduino IDE
- ESP32 board support for Arduino IDE

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/SmartPlugApp.git
   cd SmartPlugApp
   ```

2. Install Flutter dependencies:
   ```bash
   cd mobile_app
   flutter pub get
   ```

3. Configure Firebase:
   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Add web app to Firebase project
   - Copy Firebase configuration to `lib/firebase_config.dart`

4. Run the web app:
   ```bash
   flutter run -d chrome
   ```

5. Upload firmware:
   - Open Arduino IDE
   - Install required libraries
   - Upload code to ESP32

## Firebase Configuration

The app uses Firebase for:
- User Authentication
- Real-time data storage
- Device state management
- User preferences

## Security

- Firebase Authentication for user management
- Firestore security rules for data access control
- HTTPS for secure communication
- User-specific data isolation

## Development

To contribute to the project:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
