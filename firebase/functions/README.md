# Smart Plug App - Firebase Functions

This directory contains Cloud Functions that handle the data mirroring between the Realtime Database and Firestore for the Smart Plug App.

## Functions Overview

### Data Mirroring

1. **mirrorCurrentData**: Triggers whenever device status changes in RTDB.
   - Mirrors status data to Firestore
   - Adds emergencyStatus if not present
   - Records emergency events when temperature is too high

2. **recordHistoricalData**: Runs every 2 minutes.
   - Records current device status to Firestore history collection
   - Used for long-term data storage and visualization

3. **mirrorEvents**: Triggers when new events are added to RTDB.
   - Mirrors events (warnings, emergencies) to Firestore
   - Preserves event history for reference

### Data Retention

1. **cleanupHistoricalData**: Runs daily at midnight.
   - Deletes historical data older than 7 days
   - Maintains database efficiency and reduces storage costs

## Data Structure

### Realtime Database

```
devices/
  plug1/
    status/
      current: 0.0
      power: 0.0
      temperature: 25.0
      relayState: false
      deviceState: 0  // 0=OFF, 1=IDLE, 2=RUNNING
      emergencyStatus: false
      uptime: 3600  // in seconds
      timestamp: ServerTimestamp
    commands/
      relay: { state: false, processed: true, timestamp: ServerTimestamp }
    events/
      -LxYz.../
        type: "emergency"
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

## Setup and Deployment

### Prerequisites

- Node.js (v14 or newer)
- Firebase CLI: `npm install -g firebase-tools`
- Firebase project configured with Realtime Database and Firestore

### Installation

1. Install dependencies:
```
cd functions
npm install
```

2. Login to Firebase:
```
firebase login
```

3. Select your project:
```
firebase use your-project-id
```

### Deployment

Deploy all functions:
```
firebase deploy --only functions
```

Deploy a specific function:
```
firebase deploy --only functions:mirrorCurrentData
```

### Local Testing

Run functions locally:
```
firebase emulators:start --only functions
```

## Troubleshooting

Check the Firebase Functions logs:
```
firebase functions:log
```

View detailed logs in the Google Cloud Console:
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to "Logging" > "Logs Explorer"
4. Filter logs by function name 