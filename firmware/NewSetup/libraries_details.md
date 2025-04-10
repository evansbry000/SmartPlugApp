# Arduino R4 Smart Plug - Detailed Library Information

## Required Libraries

### 1. WiFiS3 (v1.0.0+)
- **Author**: Arduino
- **Purpose**: WiFi connectivity for Arduino R4 WiFi
- **Download**: Built into Arduino IDE (if updated to the latest version)
- **Installation**: Comes with Arduino IDE when R4 board support is installed
- **Repository**: https://github.com/arduino/ArduinoCore-renesas

### 2. ArduinoJson (v6.21.0+)
- **Author**: Benoit Blanchon
- **Purpose**: JSON parsing for Firebase communication
- **Download**: Arduino Library Manager or https://arduinojson.org/
- **Installation**: Search "ArduinoJson" in the Library Manager
- **Repository**: https://github.com/bblanchon/ArduinoJson

### 3. ArduinoHttpClient (v0.4.0+)
- **Author**: Arduino
- **Purpose**: HTTP client for Firebase REST API
- **Download**: Arduino Library Manager
- **Installation**: Search "ArduinoHttpClient" in the Library Manager
- **Repository**: https://github.com/arduino-libraries/ArduinoHttpClient

### 4. SSLClient (v1.6.0+)
- **Author**: Open Green Energy
- **Purpose**: SSL/TLS support for secure connections
- **Download**: Arduino Library Manager or GitHub
- **Installation**: Search "SSLClient" in the Library Manager
- **Repository**: https://github.com/OPEnSLab-OSU/SSLClient

### 5. EEPROM
- **Author**: Arduino (built-in)
- **Purpose**: Persistent storage for configuration
- **Download**: Built into Arduino IDE
- **Installation**: No installation needed
- **Documentation**: https://www.arduino.cc/reference/en/libraries/eeprom/

### 6. Timer (v1.3.0+)
- **Author**: Michael Contreras
- **Purpose**: Task scheduling for sensor readings
- **Download**: Arduino Library Manager
- **Installation**: Search "Timer" by Michael Contreras in the Library Manager
- **Repository**: https://github.com/contrem/arduino-timer

## SSL Certificate File

For secure connection to Firebase, you'll need to generate a `trust_anchors.h` file. Here's how to create it:

```cpp
// trust_anchors.h - SSL certificate for Firebase connection

#ifndef _TRUST_ANCHORS_H_
#define _TRUST_ANCHORS_H_

// DigiCert Global Root CA - Used for *.firebaseio.com
static const char digicertGlobalRootCA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97
nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P
T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4
gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO
BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR
TLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw
DQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr
hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg
06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF
PnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE-----
)EOF";

// Add this array to your SSLClient
#define TAs_TOTAL 1
static const char* TAs[TAs_TOTAL] = {digicertGlobalRootCA};

#endif //_TRUST_ANCHORS_H_
```

Save this file as `trust_anchors.h` in the same directory as your main sketch.

## Additional Board Support Information

For the Arduino R4 WiFi, you'll need to install the board package:

1. Open Arduino IDE
2. Go to Tools → Board → Boards Manager
3. Search for "Arduino UNO R4"
4. Install "Arduino UNO R4 Boards"

## Library Installation Paths

If you need to install libraries manually, here are the paths for different operating systems:

- **Windows**: `Documents\Arduino\libraries\`
- **macOS**: `~/Documents/Arduino/libraries/`
- **Linux**: `~/Arduino/libraries/`

## Common Issues and Solutions

### SSL Connection Issues
- Make sure the clock is synchronized by calling `WiFi.getTime()` before establishing SSL connections
- Check that the certificate in `trust_anchors.h` is valid and matches Firebase's certificates
- Increase buffer sizes if you encounter memory issues

### WiFi Connection Problems
- The WiFiS3 library requires different initialization than older WiFi libraries
- Always use `WiFi.begin(ssid, password)` and check `WiFi.status()` before attempting to connect to Firebase
- Implement a retry mechanism for WiFi connections 