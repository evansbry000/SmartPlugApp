#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <ArduinoJson.h>
#include <SoftwareSerial.h>

// WiFi credentials
const char* WIFI_SSID = "FatLARDbev";
const char* WIFI_PASSWORD = "fatlardr6";

// Firebase configuration
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4.firebaseio.com";
const char* FIREBASE_AUTH = "AIzaSyCDETZaO4KfbuahJuCrvupJgo4nFPvkA8E";

// Firebase data object
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Serial communication with Arduino
const int ARDUINO_RX = D6;  // ESP8266 RX pin (connect to Arduino TX: D11)
const int ARDUINO_TX = D7;  // ESP8266 TX pin (connect to Arduino RX: D10)
SoftwareSerial arduinoSerial(ARDUINO_RX, ARDUINO_TX);

// Variables for sensor data
float current = 0.0;
float power = 0.0;
float temperature = 0.0;
bool relayState = false;
int deviceState = 0;  // 0: OFF, 1: IDLE, 2: RUNNING

// Connection handling
unsigned long lastDataTime = 0;
const unsigned long CONNECTION_TIMEOUT = 180000; // 3 minutes
const unsigned long RECONNECT_INTERVAL = 30000;  // 30 seconds
int reconnectAttempts = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;
uint8_t wifiRetries = 0;
const uint8_t MAX_WIFI_RETRIES = 20;
bool wifiConnected = false;

// Device Info
String deviceID = "plug1";
String deviceName = "Smart Plug";
String firmwareVersion = "1.1.0";

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  delay(100);
  Serial.println("\n\nESP8266 Smart Plug starting...");
  Serial.println("Firmware version: " + firmwareVersion);
  
  // Initialize SoftwareSerial for communication with Arduino
  arduinoSerial.begin(115200);
  
  // Connect to WiFi using more robust method
  connectToWiFi();
  
  // Configure Firebase
  config.host = FIREBASE_HOST;
  config.api_key = FIREBASE_AUTH;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Firebase initialized");
  
  // Send data to establish initial values in Firebase
  registerDevice();
  createInitialFirebaseData();
}

void loop() {
  unsigned long currentTime = millis();
  
  // Check WiFi connection first
  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiConnected) {
      // WiFi just reconnected
      Serial.println("WiFi reconnected successfully");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
      wifiConnected = true;
      
      // Update device status in Firebase after reconnection
      if (Firebase.ready()) {
        updateDeviceStatus();
      }
    }
    
    // Read data from Arduino
    if (arduinoSerial.available()) {
      String data = arduinoSerial.readStringUntil('\n');
      Serial.print("Data from Arduino: ");
      Serial.println(data);
      
      if (data.length() > 5) { // Minimum valid data length check
        parseArduinoData(data);
        lastDataTime = currentTime;
      }
    }
    
    // Check connection status
    if (currentTime - lastDataTime > CONNECTION_TIMEOUT) {
      handleConnectionLost();
    }
    
    // Update Firebase periodically
    static unsigned long lastFirebaseUpdate = 0;
    if (currentTime - lastFirebaseUpdate > 60000) { // Every minute
      updateFirebase();
      lastFirebaseUpdate = currentTime;
    }
    
    // Check for Firebase commands
    static unsigned long lastCommandCheck = 0;
    if (currentTime - lastCommandCheck > 5000) { // Every 5 seconds
      checkFirebaseCommands();
      lastCommandCheck = currentTime;
    }
  } else {
    // WiFi is not connected
    wifiConnected = false;
    Serial.print("Trying to connect with ");
    Serial.print(WIFI_SSID);
    Serial.println("...");
    
    // Attempt to reconnect
    connectToWiFi();
  }
  
  // Allow ESP8266 to process background tasks
  yield();
  delay(100);
}

void connectToWiFi() {
  wifiRetries = 0;
  
  // Set as station mode
  WiFi.mode(WIFI_STA);
  
  // Disable WiFi sleep to improve stability
  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  
  // Enable auto-reconnect
  WiFi.setAutoReconnect(true);
  
  // Start connection
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to ");
  Serial.print(WIFI_SSID);
  Serial.println("...");
  
  // Wait for connection with timeout
  while (WiFi.status() != WL_CONNECTED && wifiRetries < MAX_WIFI_RETRIES) {
    Serial.print(".");
    wifiRetries++;
    delay(1000);
  }
  
  Serial.println();
  
  if (wifiRetries >= MAX_WIFI_RETRIES) {
    // Timeout occurred
    Serial.print("Unable to connect to ");
    Serial.println(WIFI_SSID);
    Serial.println("Will retry in the main loop...");
    wifiConnected = false;
  } else if (WiFi.status() == WL_CONNECTED) {
    // WiFi connected successfully
    Serial.print("Successfully connected to ");
    Serial.println(WIFI_SSID);
    Serial.print("IP Address: ");
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
    
    wifiConnected = true;
  }
}

void registerDevice() {
  if (Firebase.ready()) {
    FirebaseJson json;
    
    json.set("name", deviceName);
    json.set("id", deviceID);
    json.set("firmwareVersion", firmwareVersion);
    json.set("ipAddress", WiFi.localIP().toString());
    json.set("macAddress", WiFi.macAddress());
    json.set("rssi", WiFi.RSSI());
    json.set("status", "online");
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.updateNode(fbdo, "devices/" + deviceID, json)) {
      Serial.println("Device registered in Firebase");
    } else {
      Serial.println("Failed to register device");
      Serial.println(fbdo.errorReason());
    }
  }
}

void updateDeviceStatus() {
  if (Firebase.ready()) {
    FirebaseJson json;
    
    json.set("ipAddress", WiFi.localIP().toString());
    json.set("rssi", WiFi.RSSI());
    json.set("status", "online");
    json.set("lastSeen/.sv", "timestamp");
    
    if (Firebase.updateNode(fbdo, "devices/" + deviceID, json)) {
      Serial.println("Device status updated");
    } else {
      Serial.println("Failed to update device status");
      Serial.println(fbdo.errorReason());
    }
  }
}

void createInitialFirebaseData() {
  if (Firebase.ready()) {
    FirebaseJson json;
    
    json.set("current", 0.0);
    json.set("power", 0.0);
    json.set("temperature", 25.0);
    json.set("relayState", false);
    json.set("deviceState", 0);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.updateNode(fbdo, "smart_plugs/" + deviceID, json)) {
      Serial.println("Initial data created in Firebase");
    } else {
      Serial.println("Failed to create initial data");
      Serial.println(fbdo.errorReason());
    }
    
    // Create relay command node
    FirebaseJson cmdJson;
    cmdJson.set("state", false);
    
    if (Firebase.updateNode(fbdo, "smart_plugs/" + deviceID + "/commands/relay", cmdJson)) {
      Serial.println("Command node created in Firebase");
    } else {
      Serial.println("Failed to create command node");
      Serial.println(fbdo.errorReason());
    }
  }
}

void parseArduinoData(String data) {
  // Parse the data string in format: "C:current,P:power,T:temperature,R:relayState,S:deviceState"
  int cStart = data.indexOf("C:") + 2;
  int cEnd = data.indexOf(",P:");
  int pStart = data.indexOf("P:") + 2;
  int pEnd = data.indexOf(",T:");
  int tStart = data.indexOf("T:") + 2;
  int tEnd = data.indexOf(",R:");
  int rStart = data.indexOf("R:") + 2;
  int rEnd = data.indexOf(",S:");
  int sStart = data.indexOf("S:") + 2;
  
  // Check if all parts are found
  if (cStart > 1 && cEnd > 0 && pStart > 1 && pEnd > 0 && 
      tStart > 1 && tEnd > 0 && rStart > 1 && rEnd > 0 && sStart > 1) {
    
    current = data.substring(cStart, cEnd).toFloat();
    power = data.substring(pStart, pEnd).toFloat();
    temperature = data.substring(tStart, tEnd).toFloat();
    relayState = data.substring(rStart, rEnd).toInt() == 1;
    deviceState = data.substring(sStart).toInt();
    
    Serial.println("Parsed data:");
    Serial.print("Current: "); Serial.print(current); Serial.println("A");
    Serial.print("Power: "); Serial.print(power); Serial.println("W");
    Serial.print("Temperature: "); Serial.print(temperature); Serial.println("°C");
    Serial.print("Relay state: "); Serial.println(relayState ? "ON" : "OFF");
    Serial.print("Device state: "); Serial.println(deviceState);
  }
  
  // Check for emergency messages
  if (data.startsWith("EMERGENCY:")) {
    handleEmergency(data.substring(10));
  } else if (data.startsWith("WARNING:")) {
    handleWarning(data.substring(8));
  }
}

void handleEmergency(String message) {
  if (message == "TEMP_SHUTOFF") {
    // Update Firebase with emergency status
    if (Firebase.ready()) {
      FirebaseJson json;
      
      json.set("type", "emergency");
      json.set("message", "Temperature exceeded shutoff threshold");
      json.set("temperature", temperature);
      json.set("timestamp/.sv", "timestamp");
      
      if (Firebase.pushJSON(fbdo, "smart_plugs/" + deviceID + "/events", json)) {
        Serial.println("Emergency event recorded in Firebase");
      } else {
        Serial.println("Failed to record emergency event");
        Serial.println(fbdo.errorReason());
      }
    }
  }
}

void handleWarning(String message) {
  if (message == "HIGH_TEMP") {
    // Update Firebase with warning status
    if (Firebase.ready()) {
      FirebaseJson json;
      
      json.set("type", "warning");
      json.set("message", "High temperature warning");
      json.set("temperature", temperature);
      json.set("timestamp/.sv", "timestamp");
      
      if (Firebase.pushJSON(fbdo, "smart_plugs/" + deviceID + "/events", json)) {
        Serial.println("Warning event recorded in Firebase");
      } else {
        Serial.println("Failed to record warning event");
        Serial.println(fbdo.errorReason());
      }
    }
  }
}

void handleConnectionLost() {
  if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    reconnectAttempts++;
    Serial.println("Connection to Arduino lost. Attempting to reconnect...");
    
    // Send connection lost event to Firebase
    if (Firebase.ready()) {
      FirebaseJson json;
      
      json.set("type", "connection");
      json.set("status", "lost");
      json.set("attempt", reconnectAttempts);
      json.set("timestamp/.sv", "timestamp");
      
      Firebase.pushJSON(fbdo, "smart_plugs/" + deviceID + "/events", json);
    }
    
    // Attempt to reconnect
    arduinoSerial.end();
    delay(1000);
    arduinoSerial.begin(9600);
    delay(RECONNECT_INTERVAL);
  } else {
    Serial.println("Max reconnection attempts reached. Manual intervention required.");
    // Send final connection lost event
    if (Firebase.ready()) {
      FirebaseJson json;
      
      json.set("type", "connection");
      json.set("status", "failed");
      json.set("timestamp/.sv", "timestamp");
      
      Firebase.pushJSON(fbdo, "smart_plugs/" + deviceID + "/events", json);
    }
  }
}

void updateFirebase() {
  if (Firebase.ready()) {
    FirebaseJson json;
    
    json.set("current", current);
    json.set("power", power);
    json.set("temperature", temperature);
    json.set("relayState", relayState);
    json.set("deviceState", deviceState);
    json.set("rssi", WiFi.RSSI());
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.updateNode(fbdo, "smart_plugs/" + deviceID, json)) {
      Serial.println("Data updated in Firebase");
      reconnectAttempts = 0; // Reset reconnect attempts after successful update
    } else {
      Serial.println("Failed to update data");
      Serial.println(fbdo.errorReason());
    }
  }
}

void checkFirebaseCommands() {
  if (Firebase.ready()) {
    // Get relay command from Firebase
    if (Firebase.getJSON(fbdo, "smart_plugs/" + deviceID + "/commands/relay")) {
      FirebaseJson json;
      FirebaseJsonData result;
      
      json.setJsonData(fbdo.jsonString());
      json.get(result, "state");
      
      if (result.success) {
        bool newState = result.to<bool>();
        Serial.print("Relay command from Firebase: ");
        Serial.println(newState ? "ON" : "OFF");
        sendRelayCommand(newState);
      }
    }
  }
}

void sendRelayCommand(bool state) {
  String command = "RELAY:" + String(state ? "1" : "0");
  Serial.print("Sending command to Arduino: ");
  Serial.println(command);
  arduinoSerial.println(command);
} 