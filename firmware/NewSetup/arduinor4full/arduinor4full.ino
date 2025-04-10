/*
 * Arduino R4 Smart Plug Firmware
 * 
 * This firmware combines sensor reading, power control, and WiFi connectivity
 * in a single Arduino R4 board with built-in WiFi capabilities.
 * 
 * It directly connects to Firebase Realtime Database for data storage and command retrieval.
 */

#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <Timer.h>

// Firebase REST API related
#include <ArduinoHttpClient.h>
#include <SSLClient.h>
#include "trust_anchors.h" // SSL certificates for secure connections

// Pin Definitions
const int CURRENT_SENSOR_PIN = A0;  // ACS712 current sensor
const int TEMP_SENSOR_PIN = A1;     // LM35 temperature sensor
const int RELAY_PIN = 7;            // Relay control pin
const int STATUS_LED_PIN = LED_BUILTIN; // Built-in LED for status indication

// Relay configuration
const bool USE_RELAY = true;        // Set to true if relay hardware is connected

// Sensor Constants
const int MV_PER_AMP = 66;          // 66 for 30A Module
const float TEMP_SENSOR_RATIO = 0.01; // LM35: 10mV per degree Celsius

// Device State Thresholds
const float IDLE_POWER_THRESHOLD = 10.0;  // Watts
const float RUNNING_POWER_THRESHOLD = 10.0; // Watts

// Temperature Thresholds
const float TEMP_WARNING = 35.0;    // Celsius
const float TEMP_SHUTOFF = 45.0;    // Celsius
const float TEMP_MAX = 65.0;        // Celsius
const float TEMP_MIN = 0.0;         // Celsius

// WiFi credentials
const char* WIFI_SSID = "FatLARDbev";
const char* WIFI_PASSWORD = "fatlardr6";

// Firebase configuration
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG"; // Legacy database secret
const char* FIREBASE_HOST_WITHOUT_HTTPS = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const int FIREBASE_PORT = 443;

// Device Information
String deviceID = "plug1";  // Unique device identifier
String deviceName = "Smart Plug"; // Human-readable name
String firmwareVersion = "2.0.0"; // Updated for R4

// Variables for sensor data
float current = 0.0;
float power = 0.0;
float energy = 0.0;       // Accumulated energy in watt-hours
float temperature = 0.0;
bool relayState = false;
int deviceState = 0;      // 0: OFF, 1: IDLE, 2: RUNNING
bool emergencyStatus = false;
unsigned long powerOnTime = 0;
unsigned long totalOnTime = 0;
unsigned long sessionUptime = 0;
unsigned long uptimeLastCheck = 0;

// Connection handling
unsigned long lastFirebaseUpdate = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastHeartbeat = 0;
const unsigned long FIREBASE_UPDATE_INTERVAL = 30000; // 30 seconds
const unsigned long WIFI_CHECK_INTERVAL = 60000; // 60 seconds
const unsigned long HEARTBEAT_INTERVAL = 60000; // 60 seconds
int wifiStatus = WL_IDLE_STATUS;
bool firebaseConnected = false;
int reconnectAttempts = 0;

// EEPROM configuration
const int EEPROM_SIZE = 512;
const int ENERGY_ADDR = 0;
const int ON_TIME_ADDR = 4;

// Create a WiFi client and HTTP client for Firebase communication
WiFiClient wifiClient;
SSLClient sslClient(wifiClient, TAs, (size_t)TAs_NUM, A7); // Using A7 as entropy source
HttpClient httpClient(sslClient, FIREBASE_HOST_WITHOUT_HTTPS, FIREBASE_PORT);

// Timer for various tasks
Timer tasksTimer;

void setup() {
  // Initialize serial for debugging
  Serial.begin(115200);
  delay(2000);  // Give time for serial monitor to open
  Serial.println("\n\n--- Smart Plug Arduino R4 Starting ---");
  Serial.println("Firmware version: " + firmwareVersion);
  
  // Initialize pins
  pinMode(STATUS_LED_PIN, OUTPUT);
  if (USE_RELAY) {
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, LOW); // Initialize relay as OFF
  }
  pinMode(CURRENT_SENSOR_PIN, INPUT);
  pinMode(TEMP_SENSOR_PIN, INPUT);
  
  // Signal start with LED blinks
  blinkLED(2, 500);
  
  // Initialize EEPROM
  EEPROM.begin(EEPROM_SIZE);
  loadPersistentData();
  
  // Connect to WiFi
  setupWiFi();
  
  // Setup timer callbacks for various tasks
  tasksTimer.every(5000, readSensors);
  tasksTimer.every(5000, updateDeviceState);
  tasksTimer.every(10000, checkTemperature);
  tasksTimer.every(FIREBASE_UPDATE_INTERVAL, updateFirebase);
  tasksTimer.every(WIFI_CHECK_INTERVAL, checkWiFiConnection);
  tasksTimer.every(HEARTBEAT_INTERVAL, sendHeartbeat);
  tasksTimer.every(1000, updateUptime);
  
  // Initialize timers for uptime tracking
  sessionUptime = 0;
  uptimeLastCheck = millis();
  
  // Setup complete
  blinkLED(3, 200);
  Serial.println("Setup completed");
}

void loop() {
  // Update the timer to trigger callbacks
  tasksTimer.update();
  
  // Check for Firebase commands
  if (millis() - lastFirebaseUpdate > 5000) { // Check every 5 seconds
    checkFirebaseCommands();
  }
  
  // Small delay to prevent CPU hogging
  delay(50);
}

// Set up and connect to WiFi
void setupWiFi() {
  Serial.println("Connecting to WiFi network: " + String(WIFI_SSID));
  
  // Check WiFi module
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    while (true); // Don't continue
  }
  
  // Check firmware version
  String fv = WiFi.firmwareVersion();
  Serial.print("WiFi firmware version: ");
  Serial.println(fv);
  
  // Attempt to connect to WiFi network
  wifiStatus = WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait for connection with timeout (30 seconds)
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN)); // Toggle LED
    
    if (millis() - startTime > 30000) {
      Serial.println("Failed to connect to WiFi. Restarting...");
      ESP.restart();
    }
  }
  
  digitalWrite(STATUS_LED_PIN, HIGH); // LED on when connected
  Serial.println("");
  Serial.println("WiFi connected successfully!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Display signal strength
  int rssi = WiFi.RSSI();
  Serial.print("Signal strength (RSSI): ");
  Serial.print(rssi);
  Serial.println(" dBm");
  
  // Signal quality assessment
  if (rssi > -50) {
    Serial.println("Signal: Excellent");
  } else if (rssi > -60) {
    Serial.println("Signal: Good");
  } else if (rssi > -70) {
    Serial.println("Signal: Fair");
  } else {
    Serial.println("Signal: Poor - consider repositioning");
  }
}

// Read data from sensors
bool readSensors() {
  // Read current sensor
  float voltage = getVPP();
  float vRMS = (voltage/2.0) * 0.707;  // root 2 is 0.707
  current = (vRMS * 1000)/MV_PER_AMP;
  
  // Calculate power (using 120V AC)
  power = current * 120.0 / 1.3;  // 1.3 is empirical calibration factor
  
  // Update energy consumption (in watt-hours)
  if (relayState) {
    // Calculate time in hours since last reading
    float timeDiff = 5.0 / 3600.0; // 5 seconds in hours
    energy += power * timeDiff;
  }
  
  // Read temperature sensor
  int tempRaw = analogRead(TEMP_SENSOR_PIN);
  // Convert analog reading to temperature (0-1023 maps to 0-5V)
  float tempVoltage = tempRaw * (5.0 / 1023.0);
  temperature = tempVoltage / TEMP_SENSOR_RATIO;
  
  // Validate temperature readings
  if (temperature < TEMP_MIN || temperature > TEMP_MAX) {
    Serial.println("WARNING: Temperature reading out of valid range. Using last valid reading.");
    return false;
  }
  
  // Debug output
  Serial.print("Current: ");
  Serial.print(current, 2);
  Serial.print("A, Power: ");
  Serial.print(power, 2);
  Serial.print("W, Energy: ");
  Serial.print(energy, 2);
  Serial.print("Wh, Temp: ");
  Serial.print(temperature, 2);
  Serial.println("°C");
  
  return true;
}

// Helper function to get peak-to-peak voltage
float getVPP() {
  float result;
  int readValue;
  int maxValue = 0;
  int minValue = 1024;
  
  uint32_t start_time = millis();
  while((millis()-start_time) < 1000) // Sample for 1 Sec
  {
    readValue = analogRead(CURRENT_SENSOR_PIN);
    if (readValue > maxValue) {
      maxValue = readValue;
    }
    if (readValue < minValue) {
      minValue = readValue;
    }
  }
  
  result = ((maxValue - minValue) * 5.0)/1024.0;
  return result;
}

// Update device state based on power usage
bool updateDeviceState() {
  int newState;
  
  if (!relayState || power < IDLE_POWER_THRESHOLD) {
    newState = 0; // OFF
  } else if (power < RUNNING_POWER_THRESHOLD) {
    newState = 1; // IDLE
  } else {
    newState = 2; // RUNNING
  }
  
  // Only report state change
  if (newState != deviceState) {
    deviceState = newState;
    
    // Create state change event
    String stateNames[] = {"OFF", "IDLE", "RUNNING"};
    sendEventToFirebase("state_change", stateNames[deviceState]);
    
    Serial.print("Device state changed to: ");
    Serial.println(stateNames[deviceState]);
    return true;
  }
  
  return false;
}

// Monitor temperature and implement safety features
bool checkTemperature() {
  if (temperature >= TEMP_SHUTOFF) {
    // Emergency shutoff
    setRelay(false);
    
    // Set emergency flag if not already set
    if (!emergencyStatus) {
      emergencyStatus = true;
      
      // Send emergency event to Firebase
      sendEventToFirebase("emergency", "TEMP_SHUTOFF");
      
      Serial.println("EMERGENCY: Temperature shutoff threshold reached!");
      return true;
    }
  } else if (temperature >= TEMP_WARNING) {
    // Send warning event if not in emergency state
    if (!emergencyStatus) {
      sendEventToFirebase("warning", "HIGH_TEMP");
      Serial.println("WARNING: High temperature detected!");
    }
  } else if (emergencyStatus && temperature < (TEMP_WARNING - 5.0)) {
    // Reset emergency status if temperature drops below warning level minus 5°C (hysteresis)
    emergencyStatus = false;
    
    // Send recovery event
    sendEventToFirebase("info", "TEMP_NORMAL");
    
    Serial.println("INFO: Temperature returned to normal range");
    return true;
  }
  
  return false;
}

// Control the relay
void setRelay(bool state) {
  relayState = state;
  
  if (USE_RELAY) {
    digitalWrite(RELAY_PIN, state ? HIGH : LOW);
  }
  
  // If turning on, record the start time
  if (state && powerOnTime == 0) {
    powerOnTime = millis();
  }
  // If turning off, update total on time
  else if (!state && powerOnTime > 0) {
    totalOnTime += (millis() - powerOnTime);
    powerOnTime = 0;
    savePersistentData(); // Save data when turning off
  }
  
  Serial.print("Relay set to: ");
  Serial.println(state ? "ON" : "OFF");
}

// Update data to Firebase
bool updateFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Skipping Firebase update.");
    return false;
  }
  
  // Calculate uptime for this session
  unsigned long currentMillis = millis();
  
  // Create JSON document
  DynamicJsonDocument jsonBuffer(1024);
  jsonBuffer["current"] = current;
  jsonBuffer["power"] = power;
  jsonBuffer["energy"] = energy;
  jsonBuffer["temperature"] = temperature;
  jsonBuffer["relayState"] = relayState;
  jsonBuffer["deviceState"] = deviceState;
  jsonBuffer["emergencyStatus"] = emergencyStatus;
  jsonBuffer["uptime"] = sessionUptime;
  jsonBuffer["ipAddress"] = WiFi.localIP().toString();
  jsonBuffer["rssi"] = WiFi.RSSI();
  
  // Serialize JSON to string
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Create the Firebase Real-time Database path
  String path = "/devices/" + deviceID + "/status.json";
  
  // Add the auth parameter for authentication
  path += "?auth=" + String(FIREBASE_AUTH);
  
  Serial.print("Sending data to Firebase: ");
  Serial.println(jsonStr);
  
  // Make the HTTP PUT request
  httpClient.beginRequest();
  httpClient.put(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  // Check the HTTP status code
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  Serial.print("HTTP Status: ");
  Serial.println(statusCode);
  
  if (statusCode == 200) {
    Serial.println("Data sent to Firebase successfully!");
    firebaseConnected = true;
    return true;
  } else {
    Serial.print("Error sending data to Firebase. Response: ");
    Serial.println(response);
    firebaseConnected = false;
    return false;
  }
}

// Check for commands from Firebase
void checkFirebaseCommands() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  
  // Create the path to check for relay commands
  String path = "/devices/" + deviceID + "/commands/relay.json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  httpClient.beginRequest();
  httpClient.get(path);
  httpClient.endRequest();
  
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    String response = httpClient.responseBody();
    
    // Parse the response
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      // Check if there is a relay command
      if (doc.containsKey("state") && !doc["processed"]) {
        bool newState = doc["state"];
        
        if (newState != relayState) {
          Serial.print("Relay command received from Firebase: ");
          Serial.println(newState ? "ON" : "OFF");
          
          // Update the relay state
          setRelay(newState);
          
          // Mark the command as processed
          acknowledgeCommand();
        }
      }
    } else {
      Serial.print("Error parsing Firebase response: ");
      Serial.println(error.c_str());
    }
  }
}

// Mark a command as processed
void acknowledgeCommand() {
  // Create JSON to mark command as processed
  DynamicJsonDocument jsonBuffer(256);
  jsonBuffer["state"] = relayState;
  jsonBuffer["processed"] = true;
  
  // Serialize JSON to string
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Create the path for the command
  String path = "/devices/" + deviceID + "/commands/relay.json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  // Send the update
  httpClient.beginRequest();
  httpClient.put(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    Serial.println("Command acknowledged successfully");
  } else {
    Serial.print("Error acknowledging command. Status code: ");
    Serial.println(statusCode);
  }
}

// Check and maintain WiFi connection
bool checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connection lost. Attempting to reconnect...");
    
    // Attempt to reconnect
    WiFi.disconnect();
    delay(1000);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    // Wait for connection with timeout (10 seconds)
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startTime < 10000) {
      delay(500);
      Serial.print(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi reconnected!");
      Serial.print("IP address: ");
      Serial.println(WiFi.localIP());
      return true;
    } else {
      Serial.println("\nFailed to reconnect to WiFi");
      reconnectAttempts++;
      
      if (reconnectAttempts >= 5) {
        Serial.println("Multiple reconnection failures. Restarting device...");
        delay(1000);
        // Reset the device
        NVIC_SystemReset();
      }
      return false;
    }
  } else {
    reconnectAttempts = 0;
    return true;
  }
}

// Send a heartbeat to indicate the device is online
void sendHeartbeat() {
  if (WiFi.status() == WL_CONNECTED) {
    String path = "/devices/" + deviceID + "/heartbeat.json";
    path += "?auth=" + String(FIREBASE_AUTH);
    
    DynamicJsonDocument jsonBuffer(256);
    jsonBuffer["timestamp"] = millis();
    jsonBuffer["uptime"] = sessionUptime;
    
    String jsonStr;
    serializeJson(jsonBuffer, jsonStr);
    
    httpClient.beginRequest();
    httpClient.put(path);
    httpClient.sendHeader("Content-Type", "application/json");
    httpClient.sendHeader("Content-Length", jsonStr.length());
    httpClient.beginBody();
    httpClient.print(jsonStr);
    httpClient.endRequest();
    
    if (httpClient.responseStatusCode() == 200) {
      Serial.println("Heartbeat sent successfully");
    }
  }
}

// Send an event to Firebase
void sendEventToFirebase(String eventType, String message) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Event not sent.");
    return;
  }
  
  // Create JSON for the event
  DynamicJsonDocument jsonBuffer(512);
  jsonBuffer["type"] = eventType;
  jsonBuffer["message"] = message;
  
  if (eventType == "emergency" || eventType == "warning") {
    jsonBuffer["temperature"] = temperature;
  }
  
  // Serialize JSON to string
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Create the path for events
  String path = "/events/" + deviceID + ".json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  // Use HTTP POST to create a new event
  httpClient.beginRequest();
  httpClient.post(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    Serial.print("Event sent to Firebase: ");
    Serial.print(eventType);
    Serial.print(" - ");
    Serial.println(message);
  } else {
    Serial.print("Error sending event to Firebase. Status code: ");
    Serial.println(statusCode);
  }
}

// Load persistent data from EEPROM
void loadPersistentData() {
  // Read energy usage
  EEPROM.get(ENERGY_ADDR, energy);
  
  // Read total on time
  EEPROM.get(ON_TIME_ADDR, totalOnTime);
  
  // Validate data (simple sanity check)
  if (isnan(energy) || energy < a0.0) {
    energy = 0.0;
  }
  
  if (totalOnTime > 0xFFFFFFFF) { // Max value for unsigned long
    totalOnTime = 0;
  }
  
  Serial.println("Persistent data loaded:");
  Serial.print("Energy: ");
  Serial.print(energy);
  Serial.println(" Wh");
  Serial.print("Total On Time: ");
  Serial.print(totalOnTime / 3600000); // Convert to hours
  Serial.println(" hours");
}

// Save persistent data to EEPROM
void savePersistentData() {
  // Save energy usage
  EEPROM.put(ENERGY_ADDR, energy);
  
  // Save total on time
  EEPROM.put(ON_TIME_ADDR, totalOnTime);
  
  // Update persistent storage
  EEPROM.commit();
  
  Serial.println("Persistent data saved");
}

// Update the session uptime counter
void updateUptime() {
  unsigned long currentMillis = millis();
  sessionUptime += (currentMillis - uptimeLastCheck) / 1000;
  uptimeLastCheck = currentMillis;
}

// Blink the LED for visual feedback
void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(STATUS_LED_PIN, HIGH);
    delay(delayMs);
    digitalWrite(STATUS_LED_PIN, LOW);
    delay(delayMs);
  }
}
