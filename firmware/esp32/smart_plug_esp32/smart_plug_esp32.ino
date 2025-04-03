#define FIREBASE_ESP_CLIENT_ENABLE_RTDB
#define DISABLE_FIREBASE_STORAGE
#define DISABLE_FIREBASE_FIRESTORE
#define DISABLE_FIREBASE_FUNCTIONS
#define DISABLE_FIREBASE_MESSAGING
#define WM_NODEBUG

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>
#include <ESPmDNS.h>
#include <WiFiUdp.h>
#include <ArduinoOTA.h>
#include <EEPROM.h>

// PIN Definitions
const int ARDUINO_RX = 16;  // ESP32 RX pin connected to Arduino TX
const int ARDUINO_TX = 17;  // ESP32 TX pin connected to Arduino TX
const int STATUS_LED = 2;   // Status LED (built-in LED on most ESP32 boards)

// WiFi credentials (used as fallback if WiFiManager fails)
const char* WIFI_SSID = "FatLARDbev";
const char* WIFI_PASSWORD = "fatlardr6";

// Firebase configuration
const char* FIREBASE_API_KEY = "AIzaSyCDETZaO4KfbuahJuCrvupJgo4nFPvkA8E";
const char* FIREBASE_DATABASE_URL = "https://smartplugdatabase-f1fd4.firebaseio.com";

// Device Information
String deviceID = "plug1";  // Unique device identifier
String deviceName = "Smart Plug"; // Human-readable name
String firmwareVersion = "1.2.0";

// Firebase data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variables for sensor data
float current = 0.0;
float voltage = 0.0;
float power = 0.0;
float energy = 0.0;
float temperature = 0.0;
bool relayState = false;
int deviceState = 0;  // 0: OFF, 1: IDLE, 2: RUNNING
unsigned long powerOnTime = 0;
unsigned long totalOnTime = 0;

// Connection handling
unsigned long lastDataTime = 0;
unsigned long lastFirebaseUpdate = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastHeartbeat = 0;
const unsigned long CONNECTION_TIMEOUT = 180000; // 3 minutes
const unsigned long RECONNECT_INTERVAL = 30000;  // 30 seconds
const unsigned long FIREBASE_UPDATE_INTERVAL = 30000; // 30 seconds
const unsigned long WIFI_CHECK_INTERVAL = 60000; // 60 seconds
const unsigned long HEARTBEAT_INTERVAL = 60000; // 60 seconds
int reconnectAttempts = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;
bool isConfigMode = false;

// EEPROM
const int EEPROM_SIZE = 512;
const int ENERGY_ADDR = 0;
const int ON_TIME_ADDR = 4;

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  Serial.println("\n\n--- Smart Plug ESP32 Starting ---");
  Serial.println("Firmware version: " + firmwareVersion);
  
  // Initialize status LED
  pinMode(STATUS_LED, OUTPUT);
  blinkLED(2, 500); // Startup indicator
  
  // Initialize EEPROM
  EEPROM.begin(EEPROM_SIZE);
  loadPersistentData();
  
  // Initialize Serial2 for communication with Arduino
  Serial2.begin(115200, SERIAL_8N1, ARDUINO_RX, ARDUINO_TX);
  
  // Setup WiFi Manager
  setupWiFi();
  
  // Setup OTA updates
  setupOTA();
  
  // Configure Firebase
  setupFirebase();
  
  blinkLED(3, 200); // Setup complete indicator
  Serial.println("Setup completed");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Handle OTA updates
  ArduinoOTA.handle();
  
  // If in config mode, don't proceed with normal operations
  if (isConfigMode) {
    // Blink LED to indicate config mode
    if (currentTime % 1000 < 500) {
      digitalWrite(STATUS_LED, HIGH);
    } else {
      digitalWrite(STATUS_LED, LOW);
    }
    return;
  }
  
  // Check WiFi connection periodically
  if (currentTime - lastWifiCheck > WIFI_CHECK_INTERVAL) {
    checkWiFiConnection();
    lastWifiCheck = currentTime;
  }
  
  // Read data from Arduino
  if (Serial2.available()) {
    String data = Serial2.readStringUntil('\n');
    parseArduinoData(data);
    lastDataTime = currentTime;
    digitalWrite(STATUS_LED, HIGH); // Flash LED on data receive
    delay(20);
    digitalWrite(STATUS_LED, LOW);
  }
  
  // Track powered on time
  if (relayState) {
    totalOnTime = (powerOnTime > 0) ? totalOnTime + (currentTime - powerOnTime) : totalOnTime;
    powerOnTime = currentTime;
  } else if (powerOnTime > 0) {
    totalOnTime += (currentTime - powerOnTime);
    powerOnTime = 0;
    savePersistentData(); // Save data when turning off
  }
  
  // Check connection status
  if (currentTime - lastDataTime > CONNECTION_TIMEOUT) {
    handleConnectionLost();
  }
  
  // Update Firebase periodically
  if (currentTime - lastFirebaseUpdate > FIREBASE_UPDATE_INTERVAL) {
    updateFirebase();
    lastFirebaseUpdate = currentTime;
  }
  
  // Send periodic heartbeat
  if (currentTime - lastHeartbeat > HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = currentTime;
  }
  
  // Check for Firebase commands
  checkFirebaseCommands();
  
  // Small delay to prevent CPU hogging
  delay(50);
}

void setupWiFi() {
  WiFiManager wifiManager;
  
  // Set static parameter for device name
  WiFiManagerParameter custom_device_name("devicename", "Device Name", deviceName.c_str(), 40);
  wifiManager.addParameter(&custom_device_name);
  
  // Set custom timeout
  wifiManager.setConfigPortalTimeout(180); // 3 minutes timeout
  
  // Callback for entering the configuration portal
  wifiManager.setAPCallback([](WiFiManager *wifiManager) {
    Serial.println("Entered config mode");
    isConfigMode = true;
    blinkLED(5, 200); // Indicate config mode
  });
  
  // Callback for when connected to WiFi
  wifiManager.setSaveConfigCallback([]() {
    Serial.println("WiFi credentials saved");
    isConfigMode = false;
  });
  
  // Attempt to connect, start portal if it fails
  Serial.println("Connecting to WiFi...");
  if (!wifiManager.autoConnect("SmartPlug_Setup")) {
    Serial.println("Failed to connect using WiFiManager. Trying with hardcoded credentials...");
    
    // Try connecting with hardcoded credentials as fallback
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    // Wait for connection with timeout
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(500);
      Serial.print(".");
      retries++;
    }
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\nFailed to connect with hardcoded credentials. Restarting...");
      ESP.restart();
    }
    
    Serial.println("\nConnected with hardcoded credentials");
  }
  
  // Update device name if changed
  deviceName = custom_device_name.getValue();
  
  Serial.println("Connected to WiFi");
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
  
  isConfigMode = false;
}

void setupOTA() {
  // Port defaults to 3232
  ArduinoOTA.setPort(3232);
  
  // Hostname defaults to esp3232-[MAC]
  ArduinoOTA.setHostname(("SmartPlug-" + deviceID).c_str());
  
  // No authentication by default
  ArduinoOTA.setPassword("smartplug");
  
  ArduinoOTA.onStart([]() {
    String type;
    if (ArduinoOTA.getCommand() == U_FLASH)
      type = "sketch";
    else // U_SPIFFS
      type = "filesystem";
    
    Serial.println("Start updating " + type);
    savePersistentData(); // Save data before OTA update
  });
  
  ArduinoOTA.onEnd([]() {
    Serial.println("\nOTA update complete");
    blinkLED(10, 100);
  });
  
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
    digitalWrite(STATUS_LED, !digitalRead(STATUS_LED)); // Toggle LED
  });
  
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("Error[%u]: ", error);
    if (error == OTA_AUTH_ERROR) Serial.println("Auth Failed");
    else if (error == OTA_BEGIN_ERROR) Serial.println("Begin Failed");
    else if (error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
    else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
    else if (error == OTA_END_ERROR) Serial.println("End Failed");
  });
  
  ArduinoOTA.begin();
  Serial.println("OTA initialized");
}

void setupFirebase() {
  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DATABASE_URL;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Firebase initialized");
  
  // Register device in Firebase
  registerDevice();
}

void registerDevice() {
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("name", deviceName);
    json.set("id", deviceID);
    json.set("firmwareVersion", firmwareVersion);
    json.set("ipAddress", WiFi.localIP().toString());
    json.set("macAddress", WiFi.macAddress());
    json.set("lastSeen/.sv", "timestamp");
    json.set("status", "online");
    
    if (Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID, &json)) {
      Serial.println("Device registered in Firebase");
    } else {
      Serial.println("Failed to register device");
      Serial.println(fbdo.errorReason());
    }
  }
}

void parseArduinoData(String data) {
  // Parse the data string in format: "C:current,V:voltage,P:power,T:temperature,R:relayState,S:deviceState"
  // Check if data is valid
  if (!data.startsWith("C:")) {
    Serial.println("Invalid data format: " + data);
    return;
  }
  
  int cStart = data.indexOf("C:") + 2;
  int cEnd = data.indexOf(",V:");
  int vStart = data.indexOf("V:") + 2;
  int vEnd = data.indexOf(",P:");
  int pStart = data.indexOf("P:") + 2;
  int pEnd = data.indexOf(",T:");
  int tStart = data.indexOf("T:") + 2;
  int tEnd = data.indexOf(",R:");
  int rStart = data.indexOf("R:") + 2;
  int rEnd = data.indexOf(",S:");
  int sStart = data.indexOf("S:") + 2;
  
  if (cEnd == -1 || vEnd == -1 || pEnd == -1 || tEnd == -1 || rEnd == -1 || sStart == -1) {
    Serial.println("Data parsing error: " + data);
    return;
  }
  
  // Parse values
  current = data.substring(cStart, cEnd).toFloat();
  voltage = data.substring(vStart, vEnd).toFloat();
  power = data.substring(pStart, pEnd).toFloat();
  temperature = data.substring(tStart, tEnd).toFloat();
  relayState = data.substring(rStart, rEnd).toInt() == 1;
  deviceState = data.substring(sStart).toInt();
  
  // Calculate energy in kWh (power in watts / 1000 × hours)
  // For each sample, we add the energy used since the last sample
  // Assuming loop runs approximately every second
  if (relayState && power > 0) {
    energy += (power / 1000.0) / 3600.0; // Convert W to kWh
  }
  
  // Update device state based on power usage and relay state
  if (!relayState) {
    deviceState = 0; // OFF
  } else if (power < 5.0) {
    deviceState = 1; // IDLE (less than 5W)
  } else {
    deviceState = 2; // RUNNING
  }
  
  // Check for special messages
  if (data.indexOf("EMERGENCY:") >= 0) {
    handleEmergency(data.substring(data.indexOf("EMERGENCY:") + 10));
  } else if (data.indexOf("WARNING:") >= 0) {
    handleWarning(data.substring(data.indexOf("WARNING:") + 8));
  }
}

void handleEmergency(String message) {
  Serial.println("EMERGENCY: " + message);
  
  // Turn off relay immediately
  sendRelayCommand(false);
  
  // Update Firebase with emergency status
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("type", "emergency");
    json.set("message", message);
    json.set("temperature", temperature);
    json.set("current", current);
    json.set("power", power);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.RTDB.pushJSON(&fbdo, "events/" + deviceID, &json)) {
      Serial.println("Emergency event recorded in Firebase");
      
      // Update last event in device status
      Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/lastEvent", &json);
    } else {
      Serial.println("Failed to record emergency event");
      Serial.println(fbdo.errorReason());
    }
  }
  
  // Fast blink to indicate emergency
  blinkLED(10, 100);
}

void handleWarning(String message) {
  Serial.println("WARNING: " + message);
  
  // Update Firebase with warning status
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("type", "warning");
    json.set("message", message);
    json.set("temperature", temperature);
    json.set("current", current);
    json.set("power", power);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.RTDB.pushJSON(&fbdo, "events/" + deviceID, &json)) {
      Serial.println("Warning event recorded in Firebase");
      
      // Update last event in device status
      Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/lastEvent", &json);
    } else {
      Serial.println("Failed to record warning event");
      Serial.println(fbdo.errorReason());
    }
  }
  
  // Medium blink to indicate warning
  blinkLED(5, 200);
}

void handleConnectionLost() {
  if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    reconnectAttempts++;
    Serial.println("Connection lost. Attempting to reconnect...");
    
    // Send connection lost event to Firebase
    if (Firebase.ready()) {
      FirebaseJson json;
      json.set("type", "connection");
      json.set("status", "lost");
      json.set("attempt", reconnectAttempts);
      json.set("timestamp/.sv", "timestamp");
      
      if (Firebase.RTDB.pushJSON(&fbdo, "events/" + deviceID + "_connection", &json)) {
        Serial.println("Connection lost event recorded in Firebase");
      } else {
        Serial.println("Failed to record connection lost event");
        Serial.println(fbdo.errorReason());
      }
    }
    
    // Attempt to reconnect
    Serial2.end();
    delay(500);
    Serial2.begin(115200, SERIAL_8N1, ARDUINO_RX, ARDUINO_TX);
    lastDataTime = millis(); // Reset timeout
    
    // Send ping to Arduino
    Serial2.println("PING");
    
  } else {
    Serial.println("Max reconnection attempts reached. Restarting ESP32.");
    savePersistentData(); // Save data before restart
    
    // Send final connection lost event
    if (Firebase.ready()) {
      FirebaseJson json;
      json.set("type", "connection");
      json.set("status", "failed");
      json.set("timestamp/.sv", "timestamp");
      
      if (Firebase.RTDB.pushJSON(&fbdo, "events/" + deviceID + "_connection", &json)) {
        Serial.println("Final connection lost event recorded in Firebase");
      } else {
        Serial.println("Failed to record final connection lost event");
        Serial.println(fbdo.errorReason());
      }
    }
    
    delay(1000);
    ESP.restart(); // Restart ESP32
  }
}

void updateFirebase() {
  if (!Firebase.ready()) {
    Serial.println("Firebase not ready");
    return;
  }
  
  // Create JSON document for device status
  FirebaseJson json;
  json.set("current", current);
  json.set("voltage", voltage);
  json.set("power", power);
  json.set("energy", energy);
  json.set("temperature", temperature);
  json.set("relayState", relayState);
  json.set("deviceState", deviceState);
  json.set("totalOnTime", getTotalOnTimeFormatted());
  json.set("onTimeSeconds", getTotalOnTimeSeconds());
  json.set("timestamp/.sv", "timestamp");
  json.set("ipAddress", WiFi.localIP().toString());
  json.set("rssi", WiFi.RSSI());
  
  // Update RTDB
  if (Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/status", &json)) {
    reconnectAttempts = 0; // Reset reconnect attempts after successful update
  } else {
    Serial.println("Firebase update failed: " + fbdo.errorReason());
  }
  
  // Update history (once every 5 minutes)
  static unsigned long lastHistoryUpdate = 0;
  unsigned long currentTime = millis();
  
  if (currentTime - lastHistoryUpdate > 300000) { // 5 minutes
    // Format timestamp for push ID
    String historyPath = "devices/" + deviceID + "/history";
    
    if (Firebase.RTDB.pushJSON(&fbdo, historyPath, &json)) {
      lastHistoryUpdate = currentTime;
      
      // Save persistent data every 5 minutes
      savePersistentData();
    }
  }
}

void checkFirebaseCommands() {
  if (!Firebase.ready()) {
    return;
  }
  
  // Get relay command from Firebase
  if (Firebase.RTDB.getJSON(&fbdo, "devices/" + deviceID + "/commands/relay")) {
    FirebaseJson json;
    FirebaseJsonData result;
    
    json.setJsonData(fbdo.to<String>());
    json.get(result, "state");
    
    if (result.success) {
      bool newState = result.to<bool>();
      
      if (newState != relayState) {
        sendRelayCommand(newState);
        Serial.println("Relay command received: " + String(newState ? "ON" : "OFF"));
        
        // Clear command after processing
        FirebaseJson ackJson;
        ackJson.set("processed", true);
        ackJson.set("timestamp/.sv", "timestamp");
        
        Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/commands/relay", &ackJson);
      }
    }
  }
  
  // Check for firmware update command
  if (Firebase.RTDB.getJSON(&fbdo, "devices/" + deviceID + "/commands/update")) {
    FirebaseJson json;
    FirebaseJsonData result;
    
    json.setJsonData(fbdo.to<String>());
    json.get(result, "check");
    
    if (result.success && result.to<bool>()) {
      // Clear command
      FirebaseJson ackJson;
      ackJson.set("processed", true);
      ackJson.set("timestamp/.sv", "timestamp");
      
      Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/commands/update", &ackJson);
      
      // Restart to trigger OTA check
      Serial.println("Update command received. Restarting...");
      savePersistentData();
      delay(1000);
      ESP.restart();
    }
  }
  
  // Check for reset command
  if (Firebase.RTDB.getJSON(&fbdo, "devices/" + deviceID + "/commands/reset")) {
    FirebaseJson json;
    FirebaseJsonData result;
    FirebaseJson ackJson; // Declare ackJson here for use throughout this block
    
    json.setJsonData(fbdo.to<String>());
    json.get(result, "type");
    
    if (result.success) {
      String resetType = result.to<String>();
      
      // Process reset command
      if (resetType == "energy") {
        energy = 0;
        savePersistentData();
        Serial.println("Energy counter reset");
      } else if (resetType == "time") {
        totalOnTime = 0;
        savePersistentData();
        Serial.println("On-time counter reset");
      } else if (resetType == "wifi") {
        // Clear command first
        ackJson.set("processed", true);
        ackJson.set("timestamp/.sv", "timestamp");
        
        Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/commands/reset", &ackJson);
        
        // Reset WiFi
        Serial.println("WiFi settings reset requested. Resetting...");
        WiFiManager wifiManager;
        wifiManager.resetSettings();
        delay(1000);
        ESP.restart();
      } else if (resetType == "device") {
        // Clear command first
        ackJson.set("processed", true);
        ackJson.set("timestamp/.sv", "timestamp");
        
        Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/commands/reset", &ackJson);
        
        // Reset device
        Serial.println("Device reset requested. Restarting...");
        delay(1000);
        ESP.restart();
      }
      
      // Clear command
      ackJson.set("processed", true);
      ackJson.set("timestamp/.sv", "timestamp");
      Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/commands/reset", &ackJson);
    }
  }
}

void sendRelayCommand(bool state) {
  String command = "RELAY:" + String(state ? "1" : "0");
  Serial2.println(command);
  
  // Update internal state immediately
  relayState = state;
  
  // If turning on, start tracking powerOnTime
  if (state) {
    powerOnTime = millis();
  } else if (powerOnTime > 0) {
    // If turning off, update totalOnTime
    totalOnTime += (millis() - powerOnTime);
    powerOnTime = 0;
    savePersistentData();
  }
  
  // Update device state
  deviceState = state ? 1 : 0;
}

void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connection lost. Reconnecting...");
    
    WiFi.disconnect();
    WiFi.reconnect();
    
    // Wait for reconnection
    for (int i = 0; i < 20; i++) {
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("WiFi reconnected");
        
        // Update device IP address in Firebase
        if (Firebase.ready()) {
          FirebaseJson json;
          json.set("ipAddress", WiFi.localIP().toString());
          json.set("reconnected", true);
          json.set("timestamp/.sv", "timestamp");
          
          if (Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID, &json)) {
            Serial.println("Device IP address updated in Firebase");
          } else {
            Serial.println("Failed to update device IP address in Firebase");
            Serial.println(fbdo.errorReason());
          }
        }
        
        return;
      }
      
      delay(500);
      blinkLED(1, 50);
    }
    
    // If reconnection fails, restart ESP
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi reconnection failed. Restarting ESP32");
      savePersistentData();
      delay(1000);
      ESP.restart();
    }
  }
}

void sendHeartbeat() {
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("timestamp/.sv", "timestamp");
    json.set("uptime", millis() / 1000);
    json.set("rssi", WiFi.RSSI());
    json.set("freeHeap", ESP.getFreeHeap());
    
    Firebase.RTDB.updateNode(&fbdo, "devices/" + deviceID + "/heartbeat", &json);
  }
}

void blinkLED(int times, int delayMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(STATUS_LED, HIGH);
    delay(delayMs);
    digitalWrite(STATUS_LED, LOW);
    delay(delayMs);
  }
}

void savePersistentData() {
  // Save energy data to EEPROM
  EEPROM.writeFloat(ENERGY_ADDR, energy);
  
  // Save on-time data to EEPROM (as seconds)
  unsigned long totalSeconds = getTotalOnTimeSeconds();
  EEPROM.writeULong(ON_TIME_ADDR, totalSeconds);
  
  EEPROM.commit();
  Serial.println("Persistent data saved");
}

void loadPersistentData() {
  // Load energy data from EEPROM
  energy = EEPROM.readFloat(ENERGY_ADDR);
  
  // Load on-time data from EEPROM (as seconds)
  unsigned long seconds = EEPROM.readULong(ON_TIME_ADDR);
  totalOnTime = seconds * 1000; // Convert to milliseconds
  
  Serial.println("Loaded persistent data - Energy: " + String(energy) + " kWh, On-time: " + getTotalOnTimeFormatted());
}

unsigned long getTotalOnTimeSeconds() {
  unsigned long currentOnTime = totalOnTime;
  
  // Add current session if relay is on
  if (relayState && powerOnTime > 0) {
    currentOnTime += (millis() - powerOnTime);
  }
  
  return currentOnTime / 1000; // Convert to seconds
}

String getTotalOnTimeFormatted() {
  unsigned long seconds = getTotalOnTimeSeconds();
  
  unsigned long days = seconds / (24 * 3600);
  seconds = seconds % (24 * 3600);
  unsigned long hours = seconds / 3600;
  seconds = seconds % 3600;
  unsigned long minutes = seconds / 60;
  seconds = seconds % 60;
  
  char buffer[50];
  sprintf(buffer, "%lu days, %lu hours, %lu minutes, %lu seconds", days, hours, minutes, seconds);
  return String(buffer);
} 