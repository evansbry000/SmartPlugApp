# Arduino R4 Smart Plug Firmware

This directory contains the firmware for the Arduino R4 WiFi implementation of the Smart Plug system. The Arduino R4 WiFi combines all functionality into a single board, eliminating the need for separate Arduino and ESP8266/ESP32 modules.

## Directory Structure

- `arduinor4full/` - Main application firmware for Arduino R4
- `firebasetest/` - Test application for Firebase connectivity
- `libraries.md` - Documentation of required libraries and installation instructions

## Hardware Requirements

- Arduino R4 WiFi board
- ACS712 Current Sensor (connected to A0)
- LM35 Temperature Sensor (connected to A1)
- Relay Module (connected to D7)
- Surge protection components (see schematic directory for details)

## Features

The Arduino R4 implementation includes the following features:

1. **Direct WiFi Connection** - Connects directly to your WiFi network and Firebase
2. **Realtime Monitoring** - Monitors current, power, and temperature in real-time
3. **Remote Control** - Allows remote control of the connected device via Firebase
4. **Safety Features** - Automatic shutoff for high temperature conditions
5. **Data Logging** - Records energy usage and sensor data
6. **Persistent Storage** - Retains energy usage data through power cycles
7. **Secure Communication** - Uses SSL/TLS for secure Firebase communication
8. **Status Indicators** - LED feedback for connection and operation status

## Setup Instructions

### Hardware Setup

1. Connect the ACS712 current sensor to Arduino R4 analog pin A0
2. Connect the LM35 temperature sensor to Arduino R4 analog pin A1
3. Connect the relay module to Arduino R4 digital pin D7
4. Connect the status LED (or use the built-in LED)
5. Power the Arduino R4 via USB-C (for development) or external power supply (for deployment)

### Software Setup

1. Install the required libraries (see `libraries.md`)
2. Configure the WiFi credentials and Firebase settings in the sketch
3. Generate the SSL certificate file (`trust_anchors.h`)
4. Upload the firmware using the Arduino IDE

### Testing

Before deploying the full application, it's recommended to test the Firebase connectivity:

1. Upload the `firebasetest.ino` sketch to your Arduino R4
2. Monitor the serial output at 115200 baud
3. Verify that the board can connect to WiFi and communicate with Firebase
4. Check the Firebase console to ensure data is being received

### Deployment

Once testing is successful, you can upload the full application:

1. Configure any final parameters in `arduinor4full.ino`
2. Upload the sketch to your Arduino R4
3. Monitor the initial startup via serial to ensure everything is working
4. Disconnect from USB and deploy in your final location

## Additional Notes

- The R4 implementation is more power-efficient than the previous dual-board setup
- The WiFi connection is managed automatically with reconnection logic
- All safety features from the previous implementation are retained
- The firmware includes error recovery mechanisms for better reliability 