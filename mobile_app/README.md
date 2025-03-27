# Smart Plug App - Flutter Web

A Flutter web application for monitoring and controlling smart plugs with real-time data visualization and temperature monitoring.

## Features

- **Authentication**
  - Email/Password sign up and login
  - Secure session management
  - User-specific data access

- **Device Monitoring**
  - Real-time current and power consumption
  - Temperature monitoring with warnings
  - Device state tracking (off/idle/running)
  - Relay status display

- **Device Control**
  - Toggle device on/off
  - Temperature threshold settings
  - Emergency shutoff for high temperatures

- **Data Visualization**
  - Real-time power consumption graphs
  - Temperature history
  - Device state changes
  - Historical data analysis

- **User Settings**
  - Temperature unit selection (Celsius/Fahrenheit)
  - Notification preferences
  - Device-specific settings
  - User profile management

## Project Structure

```
lib/
├── screens/           # UI screens
│   ├── device_list_screen.dart
│   ├── device_detail_screen.dart
│   ├── settings_screen.dart
│   └── login_screen.dart
├── services/          # Business logic and Firebase services
│   ├── auth_service.dart
│   ├── smart_plug_service.dart
│   └── notification_service.dart
├── widgets/           # Reusable UI components
│   ├── device_card.dart
│   ├── power_chart.dart
│   └── temperature_chart.dart
├── models/           # Data models
│   ├── smart_plug_data.dart
│   └── user_settings.dart
└── main.dart         # Application entry point
```

## Dependencies

- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Real-time data storage
- `provider`: State management
- `fl_chart`: Data visualization
- `shared_preferences`: Local settings storage

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Configure Firebase:
   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Add web app to Firebase project
   - Copy Firebase configuration to `lib/firebase_config.dart`

3. Run the app:
   ```bash
   flutter run -d chrome
   ```

## Development

### Code Style

- Follow Flutter's official style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Keep widgets small and focused

### State Management

- Use Provider for global state
- Keep UI state local when possible
- Use ChangeNotifier for reactive updates

### Testing

- Write unit tests for services
- Add widget tests for UI components
- Test Firebase integration

## Deployment

1. Build the web app:
   ```bash
   flutter build web
   ```

2. Deploy to Firebase Hosting:
   ```bash
   firebase deploy --only hosting
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
