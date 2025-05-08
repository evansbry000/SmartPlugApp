# Smart Plug Mobile App

A Flutter application for monitoring and controlling IoT smart plugs. This app connects to Arduino R4 WiFi-based smart plug devices through Firebase and provides real-time monitoring, control, and automation capabilities.

## Features

- **Real-time Monitoring**: View power consumption, voltage, current, and temperature in real-time
- **Remote Control**: Toggle devices on/off from anywhere with internet connectivity
- **Alerts & Notifications**: Receive alerts for anomalous conditions or critical events
- **Power Usage Analytics**: Track and analyze power consumption over time
- **Multiple Device Management**: Control multiple smart plugs from a single app
- **User Management**: Secure authentication and device sharing capabilities

## Project Structure

```
mobile_app/
├── lib/
│   ├── main.dart             # Application entry point
│   ├── models/               # Data models
│   │   ├── smart_plug_data.dart    # Device data model
│   │   └── smart_plug_event.dart   # Event data model
│   ├── screens/              # UI screens
│   ├── services/             # Service classes for business logic
│   │   ├── auth_service.dart         # Authentication service
│   │   ├── device_data_service.dart  # Device data service
│   │   ├── event_service.dart        # Event handling service
│   │   ├── data_mirroring_service.dart # Data mirroring service
│   │   ├── notification_service.dart # Notification service
│   │   └── smart_plug_service.dart   # Main coordinator service
│   ├── widgets/              # Reusable UI components
│   ├── utils/                # Utility functions and helpers
│   └── firebase_config.dart  # Firebase configuration
├── assets/                   # Static assets (images, fonts, etc.)
└── pubspec.yaml              # Dependencies and app metadata
```

## Architecture

The app follows a modular architecture pattern with dedicated services:

1. **DeviceDataService**: Manages real-time data from smart plug devices
2. **EventService**: Handles device events and notifications
3. **DataMirroringService**: Ensures data consistency between RTDB and Firestore
4. **NotificationService**: Manages user notifications and alerts
5. **AuthService**: Handles user authentication and authorization
6. **SmartPlugService**: Coordinates between other services (facade pattern)

Services are organized around specific responsibilities, following SOLID principles. See the [services README](lib/services/README.md) for detailed information about each service.

## Firebase Integration

The app uses Firebase as its backend with a standardized data structure:

```
/smart_plugs/{device_id}/
  /status/               # Real-time sensor values
  /commands/             # Commands sent to devices
    /relay/              # Relay control commands
  /events/               # Device-generated events
```

See [PROJECT_STRUCTURE.md](../PROJECT_STRUCTURE.md) for the complete data structure specification.

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

## Device Time Conversion

The app handles device time conversion to real time for Arduino devices that don't have real-time clocks:

1. The device reports its uptime as the timestamp (`timestampType: "deviceTime"`)
2. The app records the first time it sees a device message
3. All subsequent device timestamps are converted using:
   ```
   realTime = firstConnectionTime + deviceTimeMs
   ```

This enables accurate relative time tracking without requiring NTP on the device.

## Contributing

Contributions are welcome! Please ensure:

1. Code follows the Flutter style guide
2. All UI components maintain responsiveness
3. Service implementations follow the existing architecture
4. Any changes to the Firebase data structure are documented in PROJECT_STRUCTURE.md

## License

This project is licensed under the MIT License.
