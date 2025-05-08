# Smart Plug Project Structure

This document defines the standardized structure for the Smart Plug project, including Firebase paths, data formats, and communication protocols between the firmware and mobile app.

## Firebase Realtime Database Structure

All device data is stored under the `smart_plugs/` path in the Realtime Database. This is the standardized path used by both the firmware and mobile app.

```
/smart_plugs/{device_id}/
  /status/               # Real-time sensor values
    current: float       # Current in amperes (A)
    voltage: float       # Voltage in volts (V)
    power: float         # Power in watts (W)
    temperature: float   # Temperature in Celsius (°C)
    relayState: boolean  # true = ON, false = OFF
    energyTotal: float   # Total energy consumption in kWh
    energyToday: float   # Today's energy consumption in kWh
    deviceState: int     # 0=OFF, 1=IDLE, 2=RUNNING
    emergencyShutdown: boolean # true if safety threshold exceeded
    timestamp: number    # Timestamp in milliseconds
    timestampType: string # "deviceTime" or "realTime"
    uptime: number       # Device uptime in seconds
    ipAddress: string    # Local IP address of the device
    rssi: number         # WiFi signal strength in dBm
    firmwareVersion: string # Current firmware version

  /commands/             # Commands sent from app to device
    /relay/              # Relay control commands
      state: boolean     # Desired relay state (true=ON, false=OFF)
      processed: boolean # Whether command has been processed
      timestamp: number  # When command was issued
      timestampType: string # "deviceTime" or "realTime"

  /events/               # Device-generated events
    {event_id}/          # Unique ID for each event
      type: string       # Event type (emergency, relay, system)
      message: string    # Human-readable message
      timestamp: number  # When event occurred
      timestampType: string # "deviceTime" or "realTime"
      data: object       # Additional event-specific data
```

## Firestore Structure

Firestore is used for historical data storage and more complex queries. The data mirroring service keeps Firestore in sync with the Realtime Database.

```
/current_data/{device_id}  # Current device status

/devices/{device_id}/
  /historical_data/        # Time-series data for analytics
    /{timestamp}/          # Historical data points
  /metadata/               # Device configuration

/events/{device_id}/
  /device_events/          # Historical events

/users/{user_id}/
  /devices/{device_id}/    # User's devices
  /events/                 # User's device events
  /preferences/            # User preferences
```

## Command Protocol

Commands are sent from the mobile app to the device using the following protocol:

1. **Issuing Commands**:
   - App writes to `/smart_plugs/{device_id}/commands/relay`
   - Sets `state` to desired relay state (true/false)
   - Sets `processed` to false
   - Sets `timestamp` to current time

2. **Command Processing**:
   - Device regularly checks for commands with `processed: false`
   - Device executes the command (turns relay on/off)
   - Device updates the command with `processed: true`
   - Device adds a timestamp when the command was processed

3. **Command Structure**:
```json
{
  "state": true,          // true=ON, false=OFF
  "processed": false,     // false=pending, true=completed
  "timestamp": 1234567890, // When command was issued
  "timestampType": "deviceTime" // "deviceTime" or "realTime"
}
```

## Time Synchronization

The system uses a simplified time approach:

1. Device uses its uptime (milliseconds since boot) for timestamps
2. These timestamps are marked with `timestampType: "deviceTime"`
3. The mobile app converts device time to real time using the first connection time as reference
4. The timestamp conversion formula is:
   ```
   realTime = firstConnectionTime + deviceTimeMs
   ```

## Safety Features

1. **Temperature Protection**:
   - Temperature threshold: 70°C
   - When exceeded, relay is turned OFF
   - Emergency event is sent
   - Manual override is blocked until temperature returns to safe levels

2. **Current Protection**:
   - Current threshold: 3.0A
   - When exceeded, relay is turned OFF
   - Emergency event is sent
   - Manual override is blocked until current returns to safe levels

## Device States

Devices have the following state values:
- 0 = OFF (relay is off)
- 1 = IDLE (relay is on but minimal power usage)
- 2 = RUNNING (relay is on and device is actively using power)

## Event Types

Events have the following types:
- `emergency` - Safety-related events (overtemperature, overcurrent)
- `relay` - Relay state changes
- `system` - System events (startup, reset, etc.)
- `connection` - Connection status changes

## Required Libraries

The Arduino R4 firmware requires these libraries:
- `WiFiS3` (v1.0.0+) - WiFi connectivity
- `ArduinoJson` (v6.21.0+) - JSON parsing and creation
- `arduino-timer` (v1.3.0+) - Task scheduling
- `EEPROM` (Built-in) - Persistent storage 