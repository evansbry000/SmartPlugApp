# Smart Plug App

A comprehensive IoT solution for monitoring and controlling smart plugs, with real-time data collection, power monitoring, and temperature safety features.

## Project Components

1. **Hardware**
   - Arduino R4 WiFi board with temperature and current sensors
   - Relay module for power control

2. **Firmware**
   - Arduino R4 firmware for sensor readings, power control and WiFi connectivity
   - Firebase integration for direct cloud communication

3. **Cloud Infrastructure**
   - Firebase Realtime Database for real-time data
   - Firestore for historical data storage
   - Firebase Cloud Functions for data mirroring and processing
   - Firebase Hosting for web application

4. **Mobile App**
   - Flutter web application
   - Real-time monitoring
   - Historical data visualization
   - Device control
   - Notifications

## Data Flow

1. Arduino R4 reads sensor data (current, power, temperature) and controls relay
2. Arduino R4's built-in WiFi connects directly to Firebase Realtime Database
3. Cloud Functions mirror data from RTDB to Firestore (every 2 minutes for historical data)
4. Mobile app reads real-time data from RTDB and historical data from Firestore

## Data Structure

### Realtime Database

```
devices/
  plug1/
    status/
      current: 0.0          # Current in Amperes
      power: 0.0            # Power in Watts
      temperature: 25.0     # Temperature in Celsius
      relayState: false     # Whether the relay is on or off
      deviceState: 0        # 0=OFF, 1=IDLE, 2=RUNNING
      emergencyStatus: false # Whether there's an emergency condition
      uptime: 3600          # Session uptime in seconds
      timestamp: ServerTimestamp
    commands/
      relay: { state: false, processed: true, timestamp: ServerTimestamp }
    events/
      -LxYz.../
        type: "emergency"  # Type can be "emergency", "warning", or "info"
        message: "HIGH_TEMP"
        temperature: 45.0
        timestamp: ServerTimestamp
```

### Firestore Database

```
smart_plugs/
  plug1/
    current: 0.0
    power: 0.0
    temperature: 25.0
    relayState: false
    deviceState: 0
    emergencyStatus: false
    uptime: 3600
    timestamp: Timestamp
    history/
      readings/
        -LxYz.../
          current: 0.0
          power: 0.0
          temperature: 25.0
          relayState: false
          deviceState: 0
          emergencyStatus: false
          uptime: 3600
          timestamp: Timestamp
      events/
        -LxYz.../
          type: "emergency"
          message: "HIGH_TEMP"
          temperature: 45.0
          timestamp: Timestamp
```

## Data Retention Policy

Historical data is managed with the following retention periods:
- Detailed readings: 7 days
- Hourly averages: 30 days
- Daily averages: 1 year

## Firebase Configuration

The project uses the following Firebase configuration files:

- **firebase.json**: Main configuration file for Firebase tools
- **firestore.rules**: Security rules for Firestore
- **firestore.indexes.json**: Indexes for Firestore queries
- **database.rules.json**: Security rules for Realtime Database
- **.firebaserc**: Project configuration

## Setup Instructions

### Hardware Setup

1. Connect current sensor to Arduino R4 analog pin A0
2. Connect temperature sensor to Arduino R4 analog pin A1
3. Connect relay module to Arduino R4 digital pin D7
4. Power up the system

### Firmware Setup

1. Configure your WiFi credentials in the Arduino R4 sketch
2. Upload `arduinor4full.ino` to Arduino R4
3. Monitor serial output for connection status

### Cloud Functions Setup

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Navigate to root directory
4. Deploy Firebase configuration:
   ```bash
   firebase deploy
   ```

### Mobile App Setup

1. Navigate to `mobile_app` directory
2. Install dependencies: `flutter pub get`
3. Build the web app:
   ```bash
   flutter build web
   ```
4. Deploy to Firebase Hosting:
   ```bash
   cd ..
   firebase deploy --only hosting
   ```

## Authentication

### Mobile App
- Uses Email/Password authentication
- Configure this in the Firebase Console > Authentication > Sign-in method
- Add test users as needed

### Arduino R4
- Uses Legacy Database Secret for authentication
- No additional setup required, already configured in the firmware

## Screenshots

*[Insert screenshots of the app here]*

## License

*[Insert license information here]*
