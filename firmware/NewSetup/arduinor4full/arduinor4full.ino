/*
 * Arduino R4 WiFi - Smart Plug Main Application
 * 
 * Complete firmware for Smart Plug system with:
 * - Current monitoring (ACS712 sensor)
 * - Temperature monitoring (LM35 sensor)
 * - Relay control
 * - Firebase Realtime Database integration using WiFiSSLClient
 * - Firestore mirroring
 * - Safety features (auto-shutoff for high temperature)
 * 
 * Required Libraries:
 * - WiFiS3 (Arduino)
 * - ArduinoJson (Benoit Blanchon)
 * - ArduinoHttpClient (Arduino)
 * - Timer (Michael Contreras)
 * - EEPROM (Built-in)
 */

#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <ArduinoHttpClient.h>
#include <arduino-timer.h>
#include <EEPROM.h>

// Device Configuration
#define DEVICE_ID "plug1"              // Unique identifier for this device
#define FIRMWARE_VERSION "1.0.0"       // Firmware version

// Hardware Configuration
#define CURRENT_SENSOR_PIN A0          // ACS712 sensor pin
#define TEMP_SENSOR_PIN A1             // LM35 temperature sensor pin
#define RELAY_PIN 7                    // Relay control pin
#define STATUS_LED_PIN LED_BUILTIN     // Status LED pin

// ACS712 Sensor Configuration
#define ACS712_SENSITIVITY 0.185      // 185 mV per Amp for 5A module (adjust for your module)
#define ACS712_ZERO_POINT 512         // Zero point for ACS712 (may need calibration)
#define VOLTAGE 120.0                 // Line voltage assumption (V)
#define CURRENT_SAMPLES 20            // Number of samples for current measurement

// Safety Settings
#define TEMP_THRESHOLD 70.0           // Temperature threshold for auto-shutoff (°C)
#define MAX_CURRENT 10.0              // Maximum allowable current (A)

// WiFi credentials
const char* WIFI_SSID = "Corner Office";
const char* WIFI_PASSWORD = "WhyweeAlecBev";

// Firebase settings
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_API_KEY = "AIzaSyCDETZaO4KfbuahJuCrvupJgo4nFPvkA8E";  // Web API key

// EEPROM settings
#define EEPROM_SIZE 512
#define EEPROM_INITIALIZED_FLAG 0x42   // Flag to check if EEPROM has been initialized
#define EEPROM_CONFIG_ADDR 0
#define EEPROM_ENERGY_ADDR 100

// Data update intervals
const unsigned long STATUS_UPDATE_INTERVAL = 15000;    // 15 seconds for normal status updates
const unsigned long SENSOR_READ_INTERVAL = 1000;       // 1 second for sensor readings
const unsigned long COMMAND_CHECK_INTERVAL = 5000;     // 5 seconds for command checking
const unsigned long ENERGY_SAVE_INTERVAL = 300000;     // 5 minutes for saving energy data to EEPROM

// Global variables for sensor readings
float current = 0.0;
float power = 0.0;
float energy = 0.0;
float temperature = 0.0;
bool relayState = false;
int deviceState = 0;  // 0=OFF, 1=IDLE, 2=RUNNING
bool emergencyShutdown = false;
unsigned long lastEnergyCalculation = 0;
unsigned long uptime = 0;
unsigned long lastUptimeUpdate = 0;

// Structure for persistent configuration
struct DeviceConfig {
  byte initialized;
  float totalEnergy;      // Lifetime kWh
  float dailyEnergy;      // Daily kWh
  unsigned long lastReset; // Timestamp of last daily reset
};

DeviceConfig config;

// Connection objects
WiFiSSLClient wifiSSLClient;  // Using WiFiSSLClient for secure connections
HttpClient httpClient(wifiSSLClient, FIREBASE_HOST, 443);  // Using port 443 for HTTPS

// Timer for scheduled tasks
Timer<5> timer;

// Function prototypes
bool readSensors(void *);
bool checkCommands(void *);
bool updateStatus(void *);
bool checkSafety(void *);
bool saveEnergyData(void *);
void loadConfigFromEEPROM();
void saveConfigToEEPROM();
void connectToWiFi();
void configTime();
void processRelay(bool state);
void sendEventToFirebase(const char* eventType, const char* message);
void calculateEnergy();
void resetDailyEnergy();

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(1000);
  Serial.println("\nArduino R4 WiFi - Smart Plug Starting...");
  
  // Initialize EEPROM and load saved configuration
  EEPROM.begin(EEPROM_SIZE);
  loadConfigFromEEPROM();
  
  // Initialize hardware pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  // Initialize relay to OFF state
  digitalWrite(RELAY_PIN, LOW);
  relayState = false;
  
  // Connect to WiFi
  connectToWiFi();
  
  // Set longer timeout for HTTPS requests
  httpClient.setTimeout(10000);  // 10 second timeout
  
  // Send startup event
  sendEventToFirebase("system", "STARTUP");
  
  // Setup timers for various tasks
  timer.every(SENSOR_READ_INTERVAL, readSensors);
  timer.every(COMMAND_CHECK_INTERVAL, checkCommands);
  timer.every(STATUS_UPDATE_INTERVAL, updateStatus);
  timer.every(SENSOR_READ_INTERVAL, checkSafety);
  timer.every(ENERGY_SAVE_INTERVAL, saveEnergyData);
  
  // Initial sensor reading
  readSensors(nullptr);
  
  // Update initial status
  updateStatus(nullptr);
  
  Serial.println("Smart Plug initialization complete");
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);
  Serial.print("Firmware Version: ");
  Serial.println(FIRMWARE_VERSION);
}

void loop() {
  // Update timers
  timer.tick();
  
  // Update uptime
  unsigned long currentMillis = millis();
  if (currentMillis - lastUptimeUpdate >= 1000) {
    uptime += (currentMillis - lastUptimeUpdate) / 1000;
    lastUptimeUpdate = currentMillis;
    
    // Check if it's time for daily energy reset (at midnight)
    // This is a simple implementation - a real-world device would use
    // an RTC or NTP time synchronization for accurate timing
    if (uptime % 86400 == 0) {  // 86400 seconds = 24 hours
      resetDailyEnergy();
    }
  }
  
  // Calculate energy consumption
  calculateEnergy();
  
  // Status LED indication:
  // Solid = Normal operation
  // Fast blinking = Emergency shutdown
  // Slow blinking = WiFi disconnected
  if (emergencyShutdown) {
    // Fast blinking for emergency
    digitalWrite(STATUS_LED_PIN, (millis() % 500) < 250);
  } else if (WiFi.status() != WL_CONNECTED) {
    // Slow blinking for WiFi issues
    digitalWrite(STATUS_LED_PIN, (millis() % 2000) < 1000);
  } else {
    // Status indication based on relay state
    digitalWrite(STATUS_LED_PIN, relayState);
  }
  
  // Reconnect WiFi if disconnected
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 30000) {  // Try every 30 seconds
      lastReconnectAttempt = millis();
      Serial.println("WiFi disconnected, attempting to reconnect...");
      connectToWiFi();
    }
  }
  
  // Small delay to prevent CPU hogging
  delay(50);
}

bool readSensors(void *) {
  // Read current sensor (ACS712)
  long currentSum = 0;
  for (int i = 0; i < CURRENT_SAMPLES; i++) {
    int rawValue = analogRead(CURRENT_SENSOR_PIN);
    currentSum += rawValue;
    delayMicroseconds(1000);  // Small delay between readings
  }
  
  int currentAvg = currentSum / CURRENT_SAMPLES;
  
  // Convert to amperes - calibrate these values for your specific setup
  // For ACS712 5A module: 185mV per Amp, VCC=5V
  int zeroPoint = ACS712_ZERO_POINT;  // This should be calibrated for your sensor
  float voltage = (currentAvg - zeroPoint) * (5.0 / 1023.0);
  current = voltage / ACS712_SENSITIVITY;
  
  // Set minimum threshold to filter noise
  if (abs(current) < 0.1) {
    current = 0.0;
  }
  
  // Calculate power (P = I * V)
  power = abs(current) * VOLTAGE;
  
  // Read temperature from LM35 sensor
  int tempRaw = analogRead(TEMP_SENSOR_PIN);
  float tempVoltage = tempRaw * (5.0 / 1023.0);
  temperature = tempVoltage * 100.0;  // LM35 outputs 10mV per degree Celsius
  
  // Update device state based on power usage
  if (!relayState) {
    deviceState = 0;  // OFF
  } else if (power < 5.0) {
    deviceState = 1;  // IDLE
  } else {
    deviceState = 2;  // RUNNING
  }
  
  return true;
}

bool checkCommands(void *) {
  if (WiFi.status() != WL_CONNECTED) {
    return true;  // Skip if no WiFi connection
  }
  
  // Path for relay commands
  String path = "/devices/" + String(DEVICE_ID) + "/commands/relay.json";
  path += "?auth=" + String(FIREBASE_API_KEY);
  
  // Send HTTP GET request
  httpClient.connectionKeepAlive(); // Keep connection open
  
  httpClient.beginRequest();
  httpClient.get(path);
  httpClient.endRequest();
  
  // Get response
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  if (statusCode == 200 && response != "null") {
    // Parse JSON response
    DynamicJsonDocument doc(256);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      // Check if there is a command not yet processed
      if (doc.containsKey("state") && !doc["processed"]) {
        bool newState = doc["state"].as<bool>();
        
        if (newState != relayState) {
          Serial.print("Relay command received: ");
          Serial.println(newState ? "ON" : "OFF");
          
          // Update relay state (unless emergency shutdown is active)
          if (!emergencyShutdown || !newState) {
            processRelay(newState);
          } else {
            Serial.println("Command rejected due to emergency shutdown");
            sendEventToFirebase("command", "REJECTED_EMERGENCY");
          }
          
          // Mark command as processed
          DynamicJsonDocument ackDoc(256);
          ackDoc["state"] = relayState;
          ackDoc["processed"] = true;
          ackDoc["timestamp"] = millis();
          
          String ackJson;
          serializeJson(ackDoc, ackJson);
          
          // Send acknowledgment
          httpClient.beginRequest();
          httpClient.put(path);
          httpClient.sendHeader("Content-Type", "application/json");
          httpClient.sendHeader("Connection", "keep-alive");
          httpClient.sendHeader("Content-Length", ackJson.length());
          httpClient.beginBody();
          httpClient.print(ackJson);
          httpClient.endRequest();
        }
      }
    }
  }
  
  return true;
}

bool updateStatus(void *) {
  if (WiFi.status() != WL_CONNECTED) {
    return true;  // Skip if no WiFi connection
  }
  
  // Create JSON payload
  DynamicJsonDocument jsonBuffer(1024);
  jsonBuffer["current"] = current;
  jsonBuffer["power"] = power;
  jsonBuffer["energy"]["daily"] = config.dailyEnergy;
  jsonBuffer["energy"]["total"] = config.totalEnergy;
  jsonBuffer["temperature"] = temperature;
  jsonBuffer["relayState"] = relayState;
  jsonBuffer["deviceState"] = deviceState;
  jsonBuffer["emergencyShutdown"] = emergencyShutdown;
  jsonBuffer["uptime"] = uptime;
  jsonBuffer["timestamp"] = millis();
  jsonBuffer["ipAddress"] = WiFi.localIP().toString();
  jsonBuffer["rssi"] = WiFi.RSSI();
  jsonBuffer["firmwareVersion"] = FIRMWARE_VERSION;
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Path for status data
  String path = "/devices/" + String(DEVICE_ID) + "/status.json";
  path += "?auth=" + String(FIREBASE_API_KEY);
  
  // Send HTTP PUT request
  httpClient.connectionKeepAlive(); // Keep connection open
  
  httpClient.beginRequest();
  httpClient.put(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Connection", "keep-alive");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    Serial.println("Status update sent successfully");
  } else {
    Serial.print("Status update failed with code: ");
    Serial.println(statusCode);
  }
  
  return true;
}

bool checkSafety(void *) {
  bool previousEmergency = emergencyShutdown;
  
  // Check for over-temperature condition
  if (temperature > TEMP_THRESHOLD) {
    emergencyShutdown = true;
    if (relayState) {
      processRelay(false);  // Turn off relay
      sendEventToFirebase("emergency", "OVER_TEMPERATURE");
    }
  }
  
  // Check for over-current condition
  if (current > MAX_CURRENT) {
    emergencyShutdown = true;
    if (relayState) {
      processRelay(false);  // Turn off relay
      sendEventToFirebase("emergency", "OVER_CURRENT");
    }
  }
  
  // If emergency condition has cleared and was previously active, send recovery event
  if (previousEmergency && !emergencyShutdown) {
    sendEventToFirebase("system", "EMERGENCY_RECOVERED");
  }
  
  return true;
}

bool saveEnergyData(void *) {
  // Save energy data to EEPROM
  saveConfigToEEPROM();
  Serial.println("Energy data saved to EEPROM");
  return true;
}

void loadConfigFromEEPROM() {
  // Read configuration from EEPROM
  EEPROM.get(EEPROM_CONFIG_ADDR, config);
  
  // Check if EEPROM has been initialized
  if (config.initialized != EEPROM_INITIALIZED_FLAG) {
    // Initialize with default values
    config.initialized = EEPROM_INITIALIZED_FLAG;
    config.totalEnergy = 0.0;
    config.dailyEnergy = 0.0;
    config.lastReset = 0;
    
    // Save defaults to EEPROM
    saveConfigToEEPROM();
    
    Serial.println("EEPROM initialized with default values");
  } else {
    Serial.println("Configuration loaded from EEPROM");
    Serial.print("Total Energy: ");
    Serial.print(config.totalEnergy);
    Serial.println(" kWh");
  }
}

void saveConfigToEEPROM() {
  EEPROM.put(EEPROM_CONFIG_ADDR, config);
}

void connectToWiFi() {
  // Disconnect if connected
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }
  
  Serial.print("Connecting to WiFi...");
  
  // Begin WiFi connection - WiFiS3 doesn't use mode()
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait for connection (with timeout)
  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && 
         millis() - startAttemptTime < 20000) {
    Serial.print(".");
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));  // Toggle LED
    delay(500);
  }
  
  // Check connection status
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("Connected! IP address: ");
    Serial.println(WiFi.localIP());
    
    // Synchronize time
    Serial.println("Synchronizing time...");
    configTime();
  } else {
    Serial.println();
    Serial.println("Failed to connect to WiFi. Will retry later.");
  }
}

void configTime() {
  // Get time from NTP server
  WiFi.getTime();
  delay(1000);
}

void processRelay(bool state) {
  // Don't allow turning on if in emergency mode
  if (emergencyShutdown && state) {
    Serial.println("Cannot turn relay ON during emergency shutdown");
    return;
  }
  
  // Set relay state
  digitalWrite(RELAY_PIN, state ? HIGH : LOW);
  relayState = state;
  
  Serial.print("Relay set to: ");
  Serial.println(state ? "ON" : "OFF");
  
  // Send event to Firebase
  sendEventToFirebase("relay", state ? "ON" : "OFF");
}

void sendEventToFirebase(const char* eventType, const char* message) {
  if (WiFi.status() != WL_CONNECTED) {
    return;  // Skip if no WiFi connection
  }
  
  // Create JSON for the event
  DynamicJsonDocument jsonBuffer(512);
  jsonBuffer["type"] = eventType;
  jsonBuffer["message"] = message;
  jsonBuffer["timestamp"] = millis();
  
  // Add additional data based on event type
  if (strcmp(eventType, "emergency") == 0) {
    jsonBuffer["temperature"] = temperature;
    jsonBuffer["current"] = current;
  } else if (strcmp(eventType, "relay") == 0) {
    jsonBuffer["state"] = relayState;
  }
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Path for events
  String path = "/events/" + String(DEVICE_ID) + ".json";
  path += "?auth=" + String(FIREBASE_API_KEY);
  
  // Use HTTP POST for events
  httpClient.connectionKeepAlive(); // Keep connection open
  
  httpClient.beginRequest();
  httpClient.post(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Connection", "keep-alive");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    Serial.print("Event sent: ");
    Serial.print(eventType);
    Serial.print(" - ");
    Serial.println(message);
  }
}

void calculateEnergy() {
  // Calculate energy consumption (kWh)
  unsigned long currentMillis = millis();
  if (lastEnergyCalculation > 0 && currentMillis > lastEnergyCalculation) {
    float hoursSinceLastCalculation = (currentMillis - lastEnergyCalculation) / 3600000.0;
    float energyUsed = power * hoursSinceLastCalculation;  // kW * hours = kWh
    
    // Update energy counters
    config.totalEnergy += energyUsed / 1000.0;  // Convert to kWh
    config.dailyEnergy += energyUsed / 1000.0;
  }
  
  lastEnergyCalculation = currentMillis;
}

void resetDailyEnergy() {
  Serial.println("Resetting daily energy counter");
  config.dailyEnergy = 0.0;
  config.lastReset = millis();
  saveConfigToEEPROM();
  
  // Send event
  sendEventToFirebase("system", "DAILY_RESET");
}
