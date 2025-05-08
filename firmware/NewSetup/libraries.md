# Required Libraries for Arduino R4 Smart Plug

This document lists all the libraries required for the Arduino R4 Smart Plug firmware, along with installation instructions and version requirements.

## Library Requirements

| Library Name | Version | Purpose |
|--------------|---------|---------|
| WiFiS3 | 1.0.0+ | WiFi connectivity for Arduino R4 WiFi (includes WiFiSSLClient) |
| ArduinoJson | 6.21.0+ | JSON parsing and creation for Firebase communication |
| ArduinoHttpClient | 0.4.0+ | HTTP client for Firebase REST API |
| arduino-timer | 1.3.0+ | Task scheduling for sensor readings and Firebase updates |
| EEPROM | Built-in | Persistent storage for configuration and data |

## Installation Instructions

### Using the Arduino Library Manager (Recommended)

1. Open the Arduino IDE
2. Go to **Tools > Manage Libraries...**
3. Search for each library by name
4. Click on the library and select the required version
5. Click "Install"

### Manual Installation

For libraries not available in the Library Manager or if you need a specific version:

1. Download the library from its GitHub repository or website
2. Unzip the downloaded file (if necessary)
3. Move the library folder to your Arduino libraries folder:
   - Windows: `Documents\Arduino\libraries\`
   - macOS: `~/Documents/Arduino/libraries/`
   - Linux: `~/Arduino/libraries/`
4. Restart the Arduino IDE

## WiFi SSL Connection

The Arduino R4 WiFi includes built-in SSL/TLS support through the `WiFiSSLClient` class in the `WiFiS3` library. This allows secure connections to Firebase without requiring additional SSL libraries.

Example usage:
```cpp
#include <WiFiS3.h>

// Create an SSL client
WiFiSSLClient client;

// Connect securely to host
if (client.connect(host, 443)) {
  // SSL connection established
}
```

## Additional Configuration

The Arduino R4 WiFi requires specific board support packages:

1. Go to **File > Preferences**
2. Add the following URL to the "Additional Boards Manager URLs" field:
   ```
   https://downloads.arduino.cc/packages/package_arduino_renesas_index.json
   ```
3. Go to **Tools > Board > Boards Manager**
4. Search for "Arduino UNO R4" and install the package
5. Select the "Arduino UNO R4 WiFi" board from **Tools > Board**

## Troubleshooting Common Issues

### WiFi Connection Problems

If the board cannot connect to WiFi:

1. Double-check WiFi credentials (SSID and password)
2. Ensure the WiFi signal is strong enough where the device is located
3. Try using static IP configuration if DHCP issues are suspected
4. Verify that your WiFi router supports the WiFi security protocols used by the Arduino R4

### JSON Parsing Errors

If you encounter JSON parsing errors:

1. Ensure you're using ArduinoJson version 6.x (not 5.x)
2. Increase the JSON buffer size if handling large responses
3. Check that the Firebase API responses match the expected format

## Compatibility Notes

- The `WiFiS3` library is specifically designed for Arduino R4 WiFi and newer boards with the UNO R4 WiFi's connectivity capabilities.
- The firmware may require small modifications to work with different Arduino boards.
- The firmware requires at least 32KB of RAM to function properly with SSL connections. 