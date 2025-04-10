# ESP8266 Firmware for Smart Plug

This directory contains the firmware for the ESP8266 NodeMCU that handles WiFi connectivity and communication with Firebase.

## Hardware Connections

```
+-------------+       Serial       +------------+       AC       +-----------------+
|             | <----------------> |            | <-----------> | High-Power       |
|   ESP8266   |   (D6:RX, D7:TX)   |  Arduino   |   (via Relay) | Device/Appliance |
|             |                    |            |               +-----------------+
+-------------+                    +------------+
     |                                  |
     |                                  |
     | WiFi                             | Connected to:
     |                                  | - Current Sensor (ACS712)
     |                                  | - Temperature Sensor (LM35)
     |                                  | - Surge Protection Circuit (MOV)
     |                                  | - Relay Module
     v                                  |
+----------------+                      |
| Firebase Cloud |                      |
| (Firestore DB) | <--------------------|
+----------------+
```

## Required Libraries

1. ESP8266WiFi
2. FirebaseESP8266
3. ArduinoJson (v6.x)
4. SoftwareSerial

## Setup Instructions

1. Install the ESP8266 board in Arduino IDE:
   - Go to File -> Preferences
   - Add `http://arduino.esp8266.com/stable/package_esp8266com_index.json` to Additional Board Manager URLs
   - Go to Tools -> Board -> Boards Manager
   - Search for ESP8266 and install

2. Install required libraries using Library Manager:
   - Go to Sketch -> Include Library -> Manage Libraries
   - Search for and install all required libraries

3. Configure WiFi and Firebase settings:
   - Update the following constants in the code:
     - `WIFI_SSID` - Your WiFi network name
     - `WIFI_PASSWORD` - Your WiFi password
     - `FIREBASE_HOST` - Your Firebase project ID
     - `FIREBASE_AUTH` - Your Firebase database secret

4. Connect the ESP8266 to Arduino:
   - ESP8266 D6 (RX) -> Arduino TX
   - ESP8266 D7 (TX) -> Arduino RX
   - Common GND
   - 3.3V power supply for ESP8266

5. Upload the code to the ESP8266

## Firebase Database Structure

```
smart_plugs/
  └── plug1/
      ├── current: float
      ├── power: float
      ├── temperature: float
      ├── relayState: boolean
      ├── deviceState: number (0:OFF, 1:IDLE, 2:RUNNING)
      ├── timestamp: timestamp
      ├── commands/
      │   └── relay/
      │       └── state: boolean
      └── events/ (array)
          ├── type: string (emergency/warning/connection)
          ├── message: string
          ├── temperature: float (optional)
          └── timestamp: timestamp
```

## Safety Features

This firmware works with the Arduino code to provide:
- Temperature monitoring with automatic shutoff at dangerous temperatures
- Power usage tracking
- Surge protection through the MOV hardware circuit
- Remote device control

## Troubleshooting

- Check all serial connections if the ESP8266 is not receiving data from Arduino
- Verify WiFi signal strength if connections to Firebase are unreliable
- Ensure compatible library versions are installed 