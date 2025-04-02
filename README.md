# Smart Plug App

A Flutter web application for monitoring and controlling smart plugs with real-time data visualization, temperature monitoring, and surge protection for high-powered appliances.

## Features

- User Authentication (Sign up, Login, Sign out)
- Real-time monitoring of:
  - Current consumption
  - Power usage
  - Temperature readings
  - Device state (off/idle/running)
  - Relay status
- Temperature warning system with automatic shutoff
- Integrated surge protection for high-powered appliances
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
├── firmware/                   # Arduino and ESP8266 firmware
│   ├── arduino/               # Arduino code for sensor reading
│   └── esp8266/               # ESP8266 code for WiFi and Firebase
└── firestore.rules            # Firebase security rules
```

## Hardware Requirements

- ESP8266 NodeMCU development board
- ACS712 current sensor (30A)
- LM35 temperature sensor
- MOV surge protection circuit
- Relay module
- Power supply
- USB cable for programming

## Software Requirements

- Flutter SDK
- Firebase CLI
- Arduino IDE
- ESP8266 board support for Arduino IDE

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
   - Upload Arduino code to Arduino board
   - Upload ESP8266 code to ESP8266 board

## Firebase Configuration

The app uses Firebase for:
- User Authentication
- Real-time data storage
- Device state management
- User preferences

## Hardware Configuration

The system includes:
- ESP8266 for WiFi connectivity and Firebase communication
- Arduino for sensor reading and direct device control
- ACS712 for current sensing (up to 30A)
- LM35 for temperature monitoring
- Metal Oxide Varistor (MOV) based surge protection circuit
- Relay for device switching

## Safety Features

The smart plug includes several safety features for high-powered devices:
- Temperature monitoring with automatic shutoff
- Surge protection for voltage spikes
- Current monitoring to detect abnormal operation
- Remote control to turn off devices when not in use

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
