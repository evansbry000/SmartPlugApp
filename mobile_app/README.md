# Smart Plug Mobile App

A Flutter application for monitoring and controlling IoT smart plugs. This app connects to ESP8266/ESP32-based smart plug devices through Firebase and provides real-time monitoring, control, and automation capabilities.

## Features

- **Real-time Monitoring**: View power consumption, voltage, current, and temperature in real-time
- **Remote Control**: Toggle devices on/off from anywhere with internet connectivity
- **Scheduling**: Set up timers and recurring schedules for automatic operation
- **Alerts & Notifications**: Receive alerts for anomalous conditions or critical events
- **Power Usage Analytics**: Track and analyze power consumption over time
- **Multiple Device Management**: Control multiple smart plugs from a single app
- **User Management**: Secure authentication and device sharing capabilities

## Project Structure

```
mobile_app/
├── lib/
│   ├── main.dart             # Application entry point
│   ├── app.dart              # Root application widget
│   ├── models/               # Data models
│   ├── screens/              # UI screens
│   ├── services/             # Service classes for business logic
│   ├── widgets/              # Reusable UI components
│   ├── utils/                # Utility functions and helpers
│   └── config/               # Configuration files
├── assets/                   # Static assets (images, fonts, etc.)
├── test/                     # Unit and widget tests
└── pubspec.yaml              # Dependencies and app metadata
```

## Architecture

The app follows a layered architecture pattern:

1. **Presentation Layer**: UI components (screens, widgets) built with Flutter
2. **Business Logic Layer**: Services that handle data processing and business rules
3. **Data Layer**: Models and repository classes for data access
4. **Infrastructure Layer**: Firebase integration for authentication, database, and messaging

Services are organized around specific responsibilities, following SOLID principles. See the [services README](lib/services/README.md) for detailed information about each service.

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart 2.18+
- Firebase account with Realtime Database and Firestore enabled
- Android Studio / VS Code with Flutter plugins

### Installation

1. Clone this repository
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Create a Firebase project and download the configuration files:
   - `google-services.json` (for Android) to `android/app/`
   - `GoogleService-Info.plist` (for iOS) to `ios/Runner/`

4. Run the app:
   ```
   flutter run
   ```

## Firebase Configuration

The app requires the following Firebase services:

- **Authentication**: For user management
- **Cloud Firestore**: For structured data and queries
- **Realtime Database**: For real-time device communication
- **Cloud Messaging**: For push notifications

Follow the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup) to configure these services for your project.

## Integration with Smart Plug Hardware

This app is designed to work with custom ESP8266/ESP32-based smart plug devices that communicate with Firebase. See the companion `firmware` directory in the root project for the device firmware code.

The communication flow between devices and the app is:

1. Devices publish data to Firebase Realtime Database
2. The app subscribes to these updates for real-time monitoring
3. The app sends commands to devices by writing to designated command nodes
4. Devices listen for these commands and execute them

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.
