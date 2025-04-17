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
 * - RTC (Built-in)
 */

#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <arduino-timer.h>
#include <EEPROM.h>

// Add debug flag at the top of the file after the includes
#define DEBUG_MODE false  // Set to true for verbose debugging output

// Device Configuration
#define DEVICE_ID "plug1"              // Unique identifier for this device
#define FIRMWARE_VERSION "1.0.0"       // Firmware version

// Hardware Configuration
#define CURRENT_SENSOR_PIN A0          // ACS712 sensor pin
#define TEMP_SENSOR_PIN A1             // LM35 temperature sensor pin
#define RELAY_PIN 7                    // Relay control pin
#define STATUS_LED_PIN LED_BUILTIN     // Status LED pin

// ACS712 Sensor Configuration
#define MVPERAMP 66                    // 66mV per Amp for 30A Module
#define VOLTAGE 120.0                  // Line voltage assumption (V)
#define CURRENT_CALIBRATION 1.3        // Empirical calibration factor

// Safety Settings
#define TEMP_THRESHOLD 70.0           // Temperature threshold for auto-shutoff (°C)
#define MAX_CURRENT 3.0              // Maximum allowable current (A)

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
const unsigned long STATUS_UPDATE_INTERVAL = 1500;    // 1.5 seconds for normal status updates
const unsigned long SENSOR_READ_INTERVAL = 1000;       // 1 second for sensor readings
const unsigned long COMMAND_CHECK_INTERVAL = 1500;     // Changed from 5000 to 1500 to match status updates
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

// Add this variable
unsigned long deviceStartTime = 0;

// Structure for persistent configuration
struct DeviceConfig {
  byte initialized;
  float totalEnergy;      // Lifetime kWh
  float dailyEnergy;      // Daily kWh
  unsigned long lastReset; // Timestamp of last daily reset
};

DeviceConfig config;

// Timer for scheduled tasks
Timer<5> timer;

// Function prototypes
float getVPP(void);  // New function for measuring peak-to-peak voltage
bool readSensors(void *);
bool checkCommands(void *);
bool updateStatus(void *);
bool checkSafety(void *);
bool saveEnergyData(void *);
void loadConfigFromEEPROM();
void saveConfigToEEPROM();
void connectToWiFi();
void processRelay(bool state);
void sendEventToFirebase(const char* eventType, const char* message);
void calculateEnergy();
void resetDailyEnergy();
unsigned long getDeviceTime();
void initializeCommandState();

// After the includes, add this function for direct Firebase communication
#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <arduino-timer.h>
#include <EEPROM.h>

// Replace the HttpClient with direct WiFiSSLClient usage
// Remove this line: HttpClient httpClient(wifiSSLClient, FIREBASE_HOST, 443);

// Debug settings
#define DEBUG_MODE true
#define FIREBASE_PORT 443

// Add direct communication functions
bool firebaseGet(const String& path, String& response) {
  WiFiSSLClient client;
  
  // Already simplified, no need for a message here now
  
  if (DEBUG_MODE) {
    Serial.print("Connecting to Firebase: ");
    Serial.println(FIREBASE_HOST);
  }
  
  if (!client.connect(FIREBASE_HOST, FIREBASE_PORT)) {
    Serial.println("WiFi: Connection to Firebase failed");
    return false;
  }
  
  if (DEBUG_MODE) {
    Serial.print("GET: ");
    Serial.println(path);
  }

  // Send HTTP request with simplified headers
  client.print("GET ");
  client.print(path);
  client.println(" HTTP/1.1");
  client.print("Host: ");
  client.println(FIREBASE_HOST);
  client.println("Connection: close");
  client.println();
  
  // Allocate a large buffer for the response
  const int bufSize = 2048;
  char buffer[bufSize];
  int pos = 0;
  memset(buffer, 0, bufSize);
  
  // Wait for server response (longer timeout)
  unsigned long timeout = millis() + 15000; // 15 seconds timeout
  while (millis() < timeout) {
    // Process incoming data while available
    while (client.available()) {
      char c = client.read();
      
      // Store in buffer if space available
      if (pos < bufSize - 1) {
        buffer[pos++] = c;
      }
    }
    
    // If disconnected and we have data, we're done
    if (!client.connected() && pos > 0) {
      break;
    }
    
    delay(10); // Small delay
  }
  
  // Close connection
  client.stop();
  
  // Success criteria: we got some data
  if (pos > 0) {
    buffer[pos] = '\0'; // Ensure null-termination
    String fullResponse = String(buffer);
    
    // Now extract just the JSON body, skipping HTTP headers
    int bodyStart = fullResponse.indexOf("\r\n\r\n");
    if (bodyStart > 0) {
      // Skip the empty line sequence (4 chars: \r\n\r\n)
      response = fullResponse.substring(bodyStart + 4);
      
      if (DEBUG_MODE) {
        Serial.print("Response body extracted, length: ");
        Serial.println(response.length());
        Serial.print("Body content: ");
        Serial.println(response);
      }
      
      return true;
    } else {
      if (DEBUG_MODE) {
        Serial.println("Could not find body separator. Raw response:");
        Serial.println(fullResponse);
      } else {
        Serial.println("WiFi: Response format error");
      }
      return false;
    }
  } else {
    Serial.println("WiFi: No data received within timeout");
    return false;
  }
}

bool firebasePut(const String& path, const String& jsonData) {
  WiFiSSLClient client;
  bool success = false;
  unsigned long timeout = millis() + 10000; // 10 second timeout
  
  if (DEBUG_MODE) {
    Serial.print("Connecting to Firebase: ");
    Serial.println(FIREBASE_HOST);
  }
  
  if (client.connect(FIREBASE_HOST, FIREBASE_PORT)) {
    if (DEBUG_MODE) {
      Serial.print("PUT: ");
      Serial.println(path);
    }
    
    // Send HTTP request
    client.print("PUT ");
    client.print(path);
    client.println(" HTTP/1.1");
    client.print("Host: ");
    client.println(FIREBASE_HOST);
    client.println("Content-Type: application/json");
    client.print("Content-Length: ");
    client.println(jsonData.length());
    client.println("Connection: close");
    client.println();
    client.println(jsonData);
    
    // Wait for response with timeout
    while (client.connected() && millis() < timeout) {
      if (client.available()) {
        String line = client.readStringUntil('\n');
        if (DEBUG_MODE) {
          Serial.println(line);
        }
        
        // Check if the response starts with HTTP/1.1 2
        if (line.startsWith("HTTP/1.1 2")) {
          success = true;
        }
        
        // Look for the empty line
        if (line == "\r") {
          break;
        }
      }
      delay(10);
    }
    
    // Read the rest of the response if needed
    if (DEBUG_MODE) {
      while (client.available()) {
        String line = client.readStringUntil('\n');
        Serial.println(line);
      }
    }
    
    client.stop();
    
    if (success) {
      if (DEBUG_MODE) {
        Serial.println("PUT operation successful");
      }
    } else {
      Serial.println("WiFi: PUT operation failed");
    }
  } else {
    Serial.println("WiFi: Connection to Firebase failed");
  }
  
  return success;
}

bool firebasePost(const String& path, const String& jsonData) {
  WiFiSSLClient client;
  bool success = false;
  unsigned long timeout = millis() + 10000; // 10 second timeout
  
  Serial.print("Connecting to Firebase: ");
  Serial.println(FIREBASE_HOST);
  
  if (client.connect(FIREBASE_HOST, FIREBASE_PORT)) {
    Serial.print("POST: ");
    Serial.println(path);
    
    // Send HTTP request
    client.print("POST ");
    client.print(path);
    client.println(" HTTP/1.1");
    client.print("Host: ");
    client.println(FIREBASE_HOST);
    client.println("Content-Type: application/json");
    client.print("Content-Length: ");
    client.println(jsonData.length());
    client.println("Connection: close");
    client.println();
    client.println(jsonData);
    
    // Wait for response with timeout
    while (client.connected() && millis() < timeout) {
      if (client.available()) {
        String line = client.readStringUntil('\n');
        if (DEBUG_MODE) {
          Serial.println(line);
        }
        
        // Check if the response starts with HTTP/1.1 2
        if (line.startsWith("HTTP/1.1 2")) {
          success = true;
        }
        
        // Look for the empty line
        if (line == "\r") {
          break;
        }
      }
      delay(10);
    }
    
    // Read the rest of the response if needed
    if (DEBUG_MODE) {
      while (client.available()) {
        String line = client.readStringUntil('\n');
        Serial.println(line);
      }
    }
    
    client.stop();
    
    if (success) {
      Serial.println("POST operation successful");
    } else {
      Serial.println("POST operation failed");
    }
  } else {
    Serial.println("Connection to Firebase failed");
  }
  
  return success;
}

// Function to check if WiFi is properly connected with valid IP
bool checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }
  
  // Check for valid IP address
  IPAddress ip = WiFi.localIP();
  if (ip[0] == 0) {
    return false;
  }
  
  return true;
}

// Update timeout value to allow more time for slow connections
#define HTTP_TIMEOUT 30000   // 30 seconds

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(1000);
  Serial.println("\nArduino R4 WiFi - Smart Plug Starting...");
  
  // Record device start time
  deviceStartTime = millis();
  
  // Initialize EEPROM and load saved configuration
  EEPROM.begin(); // No size parameter needed for Arduino R4
  loadConfigFromEEPROM();
  
  // Initialize hardware pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  // Initialize relay to OFF state (HIGH for active-low relay)
  digitalWrite(RELAY_PIN, HIGH);
  relayState = false;
  
  // Connect to WiFi
  connectToWiFi();
  
  // No more time synchronization attempts
  
  // Initialize command state in Firebase to match physical relay state
  initializeCommandState();
  
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
    
    // Check if it's time for daily energy reset (based on uptime instead of real time)
    // Reset every 24 hours of uptime
    if (uptime % 86400 == 0 && uptime > 0) {
      resetDailyEnergy();
    }
  }
  
  // No more time synchronization in the loop
  
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
  // Read current sensor (ACS712) using improved AC measurement method
  float voltagePP = getVPP();
  float voltageRMS = (voltagePP/2.0) * 0.707;  // Convert to RMS value
  current = (voltageRMS * 1000)/MVPERAMP;      // Convert to current
  
  // Apply calibration factor
  current = current / CURRENT_CALIBRATION;
  if(current < .15){
    current=0;
  }
  
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
  if (!checkWiFiConnection()) {
    if (DEBUG_MODE) {
      Serial.println("Command check skipped: WiFi not properly connected");
    }
    return true;
  }
  
  // Path for relay commands
  String path = "/devices/" + String(DEVICE_ID) + "/commands/relay.json";
  String pathWithAuth = path + "?auth=" + String(FIREBASE_API_KEY);
  
  String response = "";
  if (firebaseGet(pathWithAuth, response)) {
    if (response != "null" && response.length() > 5) {
      // Parse JSON response
      DynamicJsonDocument doc(512);
      DeserializationError error = deserializeJson(doc, response);
      
      if (!error) {
        if (DEBUG_MODE) {
          Serial.print("Parsed JSON: ");
          serializeJson(doc, Serial);
          Serial.println();
        }
        
        // Check if there is a command not yet processed
        if (doc.containsKey("state")) {
          if (DEBUG_MODE) {
            Serial.print("Command state field exists: ");
            Serial.println(doc["state"].as<bool>() ? "ON" : "OFF");
          }
          
          if (!doc["processed"]) {
            bool newState = doc["state"].as<bool>();
            Serial.print("Command: Relay ");
            Serial.println(newState ? "ON" : "OFF");
            
            if (newState != relayState) {
              // Update relay state (unless emergency shutdown is active)
              if (!emergencyShutdown || !newState) {
                // CRITICAL CHANGE: Send acknowledgment BEFORE processing the relay
                // to improve app UI responsiveness
                DynamicJsonDocument ackDoc(256);
                ackDoc["state"] = newState; // Use the new state here, not the current relayState
                ackDoc["processed"] = true;
                
                // Use device uptime for timestamp
                ackDoc["timestamp"] = getDeviceTime();
                ackDoc["timestampType"] = "deviceTime"; // Indicate this is device time, not real time
                
                String ackJson;
                serializeJson(ackDoc, ackJson);
                
                // Send acknowledgment FIRST
                Serial.println("Command: Acknowledging");
                if (firebasePut(pathWithAuth, ackJson)) {
                  // Now process the relay after the acknowledgment is sent
                  processRelay(newState);
                  // Moved after relay activation
                  Serial.println("Command: Acknowledged");
                } else {
                  // Still process the relay even if acknowledgment fails
                  processRelay(newState);
                  Serial.println("Command: Failed to acknowledge");
                }
              } else {
                Serial.println("Command: Rejected (emergency shutdown)");
                sendEventToFirebase("command", "REJECTED_EMERGENCY");
              }
            } else {
              // Still need to acknowledge even if state doesn't change
              DynamicJsonDocument ackDoc(256);
              ackDoc["state"] = relayState;
              ackDoc["processed"] = true;
              ackDoc["timestamp"] = getDeviceTime();
              ackDoc["timestampType"] = "deviceTime";
              
              String ackJson;
              serializeJson(ackDoc, ackJson);
              
              // Send acknowledgment
              if (firebasePut(pathWithAuth, ackJson)) {
                Serial.println("Command: Acknowledged (no change needed)");
              }
            }
          } else {
            if (DEBUG_MODE) {
              Serial.println("Command already processed, skipping");
            }
          }
        } else {
          if (DEBUG_MODE) {
            Serial.println("No 'state' field in command JSON");
          }
        }
      } else {
        Serial.print("Error: JSON parsing error: ");
        Serial.println(error.c_str());
      }
    } else if (response == "null") {
      if (DEBUG_MODE) {
        Serial.println("No command found (null response)");
      }
    }
  } else {
    if (DEBUG_MODE) {
      Serial.println("Failed to check for commands");
    }
  }
  
  return true;
}

bool updateStatus(void *) {
  if (!checkWiFiConnection()) {
    if (DEBUG_MODE) {
      Serial.println("Status update skipped: WiFi not properly connected");
    }
    return true;
  }
  
  // Only print status update message in debug mode
  if (DEBUG_MODE) {
    Serial.println("Status: Sending update");
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
  
  // Use device uptime for timestamp
  jsonBuffer["timestamp"] = getDeviceTime();
  jsonBuffer["timestampType"] = "deviceTime"; // Indicate this is device time, not real time
  
  jsonBuffer["ipAddress"] = WiFi.localIP().toString();
  jsonBuffer["rssi"] = WiFi.RSSI();
  jsonBuffer["firmwareVersion"] = FIRMWARE_VERSION;
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Path for status data
  String path = "/devices/" + String(DEVICE_ID) + "/status.json";
  path += "?auth=" + String(FIREBASE_API_KEY);
  
  if (firebasePut(path, jsonStr)) {
    if (DEBUG_MODE) {
      Serial.println("Status update sent successfully");
    }
  } else {
    Serial.println("WiFi: Status update failed");
    
    // Try reconnecting to WiFi if status update fails
    static int failureCount = 0;
    failureCount++;
    
    if (failureCount >= 3) {
      Serial.println("WiFi: Multiple failures. Resetting connection...");
      connectToWiFi();
      failureCount = 0;
    }
  }
  
  return true;
}

bool checkSafety(void *) {
  bool previousEmergency = emergencyShutdown;
  
  // Check for over-temperature condition
  if (temperature > TEMP_THRESHOLD) {
    emergencyShutdown = true;
    Serial.println("Temperature Over Max Threshold");
    if (relayState) {
      processRelay(false);  // Turn off relay
      sendEventToFirebase("emergency", "OVER_TEMPERATURE");
    }
  }
  
  // Check for over-current condition
  if (current > MAX_CURRENT) {
    emergencyShutdown = true;
    Serial.println("Current Over Max Threshold");
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

// Update the connectToWiFi function for better reliability
void connectToWiFi() {
  // Disconnect if connected
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi: Disconnecting from previous connection");
    WiFi.disconnect();
    delay(1000);
  }
  
  Serial.print("WiFi: Connecting to ");
  Serial.println(WIFI_SSID);
  
  // Reset WiFi hardware first
  WiFi.end();
  delay(1000);
  
  // Begin WiFi connection
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait for connection (with timeout)
  unsigned long startAttemptTime = millis();
  bool connected = false;
  
  while (millis() - startAttemptTime < 30000) { // 30 second timeout
    if (WiFi.status() == WL_CONNECTED) {
      IPAddress ip = WiFi.localIP();
      // Check if we have a valid IP address (not 0.0.0.0)
      if (ip[0] != 0) {
        connected = true;
        break;
      }
    }
    Serial.print(".");
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));  // Toggle LED
    delay(500);
  }
  
  // Check connection status
  if (connected) {
    Serial.println();
    Serial.print("WiFi: Connected! IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("WiFi: Signal strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Try a basic HTTP request to check internet connectivity
    if (DEBUG_MODE) {
      Serial.println("Testing internet connectivity...");
      
      // Simple test to google.com
      WiFiSSLClient testClient;
      if (testClient.connect("www.google.com", 443)) {
        Serial.println("Internet connection confirmed");
        testClient.stop();
      } else {
        Serial.println("Internet connectivity might be limited");
      }
    }
    
    // Delay before first Firebase connection to ensure network is stable
    delay(2000);
  } else {
    Serial.println();
    Serial.println("WiFi: Failed to connect or obtain valid IP");
    // Print the WiFi status code for debugging
    int status = WiFi.status();
    
    // Try to print status meaning
    Serial.print("WiFi status: ");
    switch(status) {
      case WL_CONNECTED: 
        Serial.println("Connected");
        break;
      case WL_IDLE_STATUS:
        Serial.println("Idle");
        break;
      case WL_NO_SSID_AVAIL:
        Serial.println("SSID not available");
        break;
      case WL_SCAN_COMPLETED:
        Serial.println("Scan completed");
        break;
      case WL_CONNECT_FAILED:
        Serial.println("Connection failed");
        break;
      case WL_CONNECTION_LOST:
        Serial.println("Connection lost");
        break;
      case WL_DISCONNECTED:
        Serial.println("Disconnected");
        break;
      default:
        Serial.println("Unknown");
    }
  }
}

void processRelay(bool state) {
  // Don't allow turning on if in emergency mode
  if (emergencyShutdown && state) {
    Serial.println("Relay: Cannot turn ON during emergency shutdown");
    return;
  }
  
  // Set relay state - INVERTED LOGIC for active-low relay
  // When state is TRUE (ON), we set pin LOW to activate the relay
  // When state is FALSE (OFF), we set pin HIGH to deactivate the relay
  digitalWrite(RELAY_PIN, state ? LOW : HIGH);
  relayState = state;
  
  Serial.print("Relay: ");
  Serial.println(state ? "ON" : "OFF");
  
  // Send event to Firebase
  sendEventToFirebase("relay", state ? "ON" : "OFF");
}

void sendEventToFirebase(const char* eventType, const char* message) {
  if (!checkWiFiConnection()) {
    Serial.println("Cannot send event: WiFi not properly connected");
    return;
  }
  
  // Create JSON for the event
  DynamicJsonDocument jsonBuffer(512);
  jsonBuffer["type"] = eventType;
  jsonBuffer["message"] = message;
  
  // Use device uptime for timestamp
  jsonBuffer["timestamp"] = getDeviceTime();
  jsonBuffer["timestampType"] = "deviceTime"; // Indicate this is device time, not real time
  
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
  
  if (firebasePost(path, jsonStr)) {
    Serial.print("Event sent: ");
    Serial.print(eventType);
    Serial.print(" - ");
    Serial.println(message);
  } else {
    Serial.println("Failed to send event");
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

// New function to measure peak-to-peak voltage for AC current sensing
float getVPP() {
  int maxValue = 0;             // store max value here
  int minValue = 1024;          // store min value here
  int readValue;                // value read from the sensor
  
  // Sample for 500ms to balance accuracy with responsiveness
  uint32_t start_time = millis();
  while((millis()-start_time) < 500) { // 500ms sampling period
    readValue = analogRead(CURRENT_SENSOR_PIN);
    // Record maximum and minimum values
    if (readValue > maxValue) {
      maxValue = readValue;
    }
    if (readValue < minValue) {
      minValue = readValue;
    }
    // Small delay to prevent excessive readings
    delayMicroseconds(200);
  }
   
  // Calculate peak-to-peak voltage
  float result = ((maxValue - minValue) * 5.0)/1024.0;
  return result;
}

// Return device uptime in milliseconds, for use in timestamps
unsigned long getDeviceTime() {
  return millis() - deviceStartTime;
}

// Initialize the command state in Firebase to match the physical relay state
void initializeCommandState() {
  if (!checkWiFiConnection()) {
    Serial.println("Cannot initialize command state: WiFi not properly connected");
    return;
  }
  
  Serial.println("Initializing command state in Firebase...");
  
  // Path for relay commands
  String path = "/devices/" + String(DEVICE_ID) + "/commands/relay.json";
  path += "?auth=" + String(FIREBASE_API_KEY);
  
  // Create JSON payload with relay initialized to OFF
  DynamicJsonDocument jsonBuffer(256);
  jsonBuffer["state"] = false;       // Relay starts in OFF state
  jsonBuffer["processed"] = true;    // Marked as processed so it won't trigger again
  
  // Use device uptime for timestamp
  jsonBuffer["timestamp"] = getDeviceTime();
  jsonBuffer["timestampType"] = "deviceTime"; // Indicate this is device time, not real time
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  if (firebasePut(path, jsonStr)) {
    Serial.println("Command state initialized successfully");
  } else {
    Serial.println("Failed to initialize command state");
  }
}
