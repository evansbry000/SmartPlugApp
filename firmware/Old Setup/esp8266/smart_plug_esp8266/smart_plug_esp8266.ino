#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <ArduinoJson.h>
#include <SoftwareSerial.h>

// Debug mode - set to true for more detailed information
#define DEBUG_MODE true

// Maximum number of connection attempts before rebooting
#define MAX_BOOT_ATTEMPTS 3
int bootAttempts = 0;

// WiFi credentials
const char* WIFI_SSID = "Corner Office";  // Update to your current network
const char* WIFI_PASSWORD = "fatlardr6";  // Use your actual password

// Static IP configuration (optional)
// Uncomment and configure these if you want to use static IP
// IPAddress staticIP(192,168,4,200);
// IPAddress gateway(192,168,4,1);
// IPAddress subnet(255,255,255,0);
// IPAddress dns1(8,8,8,8);

// Firebase configuration
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG"; // Database Secret

// Firebase data object
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Check if we're using an older Firebase library (before v3.0.0)
// You might need to modify this depending on your library version
#ifdef FIREBASE_ESP8266_VERSION
  #if FIREBASE_ESP8266_VERSION < 300
    #define FIREBASE_USE_LEGACY_API
  #endif
#endif

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
bool emergencyStatus = false; // Flag for emergency status
unsigned long sessionUptime = 0; // Session-based uptime in seconds
unsigned long uptimeLastCheck = 0; // Last time uptime was updated

// Connection handling
unsigned long lastDataTime = 0;
const unsigned long CONNECTION_TIMEOUT = 180000; // 3 minutes
const unsigned long RECONNECT_INTERVAL = 30000;  // 30 seconds
int reconnectAttempts = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;
uint8_t wifiRetries = 0;
const uint8_t MAX_WIFI_RETRIES = 20;
bool wifiConnected = false;

// Firebase connection status
bool firebaseConnected = false;
unsigned long lastFirebaseConnectionAttempt = 0;
const unsigned long FIREBASE_RECONNECT_INTERVAL = 10000; // 10 seconds

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
  
  // Print MAC address right away
  Serial.print("ESP8266 MAC Address: ");
  Serial.println(WiFi.macAddress());
  
  // Initialize SoftwareSerial for communication with Arduino
  arduinoSerial.begin(115200);
  
  // Connect to WiFi using more robust method
  connectToWiFi();
  
  if (wifiConnected) {
    bootAttempts = 0; // Reset boot attempts on successful connection
    
    // Initialize Firebase with the simplest approach
    Serial.println("Initializing Firebase...");
    
    // Format the host properly
    String host = FIREBASE_HOST;
    if (host.startsWith("https://")) {
      host = host.substring(8);
    }
    if (host.endsWith("/")) {
      host = host.substring(0, host.length() - 1);
    }
    
    Serial.print("Using Firebase Host: ");
    Serial.println(host);
    
    // ABSOLUTE SIMPLEST INITIALIZATION - Using first principles
    fbdo.setReuseStringObject(true); // Optimize for memory
    
    // Try to detect the version and use appropriate initialization method
    Serial.println("Using direct host/auth initialization");
    
    // Set the values directly in Firebase object properties
    FirebaseData::setDefaultHost(host.c_str());
    FirebaseData::setDefaultAuth(FIREBASE_AUTH);
    
    // Call simple init function
    if(Firebase.reconnect()) {
      Serial.println("Firebase initialized via direct method");
    } else {
      Serial.println("Failed to initialize Firebase directly");
    }
    
    Firebase.reconnectWiFi(true);
    
    // Test Firebase connection
    testFirebaseConnection();
    
    // Send data to establish initial values in Firebase
    if (firebaseConnected) {
      registerDevice();
      createInitialFirebaseData();
    }
  } else {
    bootAttempts++;
    if (bootAttempts >= MAX_BOOT_ATTEMPTS) {
      Serial.println("Failed to connect to WiFi after multiple attempts. Rebooting ESP8266...");
      ESP.restart();
    }
  }
  
  // Initialize session uptime tracking
  sessionUptime = 0;
  uptimeLastCheck = millis();
}

void loop() {
  static unsigned long lastRebootCheck = 0;
  unsigned long currentTime = millis();
  
  // Every 5 minutes, check if we need to reboot due to persistent issues
  if (currentTime - lastRebootCheck > 300000) {
    lastRebootCheck = currentTime;
    
    if (!wifiConnected) {
      bootAttempts++;
      if (bootAttempts >= MAX_BOOT_ATTEMPTS) {
        Serial.println("Persistent connection issues detected. Rebooting ESP8266...");
        ESP.restart();
      }
    } else {
      bootAttempts = 0; // Reset if currently connected
    }
  }
  
  // Check WiFi connection first
  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiConnected) {
      // WiFi just reconnected
      Serial.println("WiFi reconnected successfully");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
      wifiConnected = true;
      
      // Test Firebase connection after WiFi reconnection
      testFirebaseConnection();
      
      // Update device status in Firebase after reconnection
      if (firebaseConnected) {
        updateDeviceStatus();
      }
    }
    
    // If Firebase is not connected, try to reconnect periodically
    if (!firebaseConnected && (currentTime - lastFirebaseConnectionAttempt > FIREBASE_RECONNECT_INTERVAL)) {
      testFirebaseConnection();
      lastFirebaseConnectionAttempt = currentTime;
    }
    
    // Only proceed with Firebase operations if connected
    if (firebaseConnected) {
      // Read data from Arduino
      if (arduinoSerial.available()) {
        String data = arduinoSerial.readStringUntil('\n');
        if (DEBUG_MODE) {
          Serial.print("Data from Arduino: ");
          Serial.println(data);
        }
        
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
    } else if (DEBUG_MODE) {
      // Print message about Firebase not connected every 5 seconds
      static unsigned long lastDebugPrint = 0;
      if (currentTime - lastDebugPrint > 5000) {
        Serial.println("Waiting for Firebase connection...");
        lastDebugPrint = currentTime;
      }
    }
  } else {
    // WiFi is not connected
    wifiConnected = false;
    firebaseConnected = false;
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

void testFirebaseConnection() {
  Serial.println("Testing Firebase connection...");
  
  // Try to read a test value from Firebase
  if (Firebase.ready() && Firebase.getString(fbdo, "/test")) {
    Serial.println("Firebase connection successful!");
    firebaseConnected = true;
    
    // Create a test node if it doesn't exist
    FirebaseJson json;
    json.set("lastConnection", WiFi.macAddress());
    json.set("timestamp/.sv", "timestamp");
    Firebase.updateNode(fbdo, "/test", json);
  } else {
    Serial.println("Firebase connection failed!");
    Serial.print("Error reason: ");
    Serial.println(fbdo.errorReason());
    firebaseConnected = false;
  }
}

void connectToWiFi() {
  wifiRetries = 0;
  
  Serial.println("\n\nAttempting to connect to WiFi with optimized settings...");
  
  // Disconnect if already connected
  WiFi.disconnect(true);
  delay(1000);
  
  // Set WiFi mode explicitly
  WiFi.mode(WIFI_OFF);
  delay(1000);
  WiFi.mode(WIFI_STA);
  delay(1000);
  
  // Disable sleep mode
  WiFi.setSleepMode(WIFI_NONE_SLEEP);
  
  // Maximum power
  WiFi.setOutputPower(20.5);
  
  // Optional: Set static IP if configured
  // Uncomment this if you're using static IP
  /*
  if(staticIP.isSet()) {
    Serial.println("Configuring static IP...");
    WiFi.config(staticIP, gateway, subnet, dns1);
  }
  */
  
  // Set explicit channel requirements
  // Some eero routers work better when we initially force 2.4GHz channels
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD, 1); // Start with channel 1
  Serial.print("Connecting to ");
  Serial.print(WIFI_SSID);
  Serial.println(" on channel 1...");
  
  // Give it a few seconds on channel 1
  for(int i = 0; i < 5; i++) {
    if(WiFi.status() == WL_CONNECTED) {
      wifiConnected = true;
      break;
    }
    Serial.print(".");
    delay(1000);
  }
  
  // If that didn't work, try channel 6
  if(!wifiConnected) {
    Serial.println("\nTrying channel 6...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD, 6);
    for(int i = 0; i < 5; i++) {
      if(WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        break;
      }
      Serial.print(".");
      delay(1000);
    }
  }
  
  // If still not connected, try channel 11
  if(!wifiConnected) {
    Serial.println("\nTrying channel 11...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD, 11);
    for(int i = 0; i < 5; i++) {
      if(WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        break;
      }
      Serial.print(".");
      delay(1000);
    }
  }
  
  // If still not connected, let it auto-select channel
  if(!wifiConnected) {
    Serial.println("\nTrying auto channel selection...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    // Wait for connection with timeout
    while (WiFi.status() != WL_CONNECTED && wifiRetries < MAX_WIFI_RETRIES) {
      Serial.print(".");
      wifiRetries++;
      delay(1000);
    }
  }
  
  // Check connection status
  if (WiFi.status() == WL_CONNECTED) {
    // WiFi connected successfully
    wifiConnected = true;
    Serial.println("\nSuccessfully connected to WiFi");
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
    
    // Display channel information
    Serial.print("Connected on channel: ");
    Serial.println(WiFi.channel());
  } else {
    // Connection failed
    wifiConnected = false;
    Serial.println("\nFailed to connect to WiFi");
    Serial.println("Will retry again later");
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
    json.set("lastSeen/.sv", "timestamp");
    json.set("status", "online");
    
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
  // Expected format: "C:current,P:power,T:temperature,R:relayState,S:deviceState,E:emergencyStatus"
  float newCurrent = 0.0;
  float newPower = 0.0;
  float newTemperature = 0.0;
  bool newRelayState = false;
  int newDeviceState = 0;
  bool newEmergencyStatus = false;
  
  // Parse the data
  int cPos = data.indexOf("C:");
  int pPos = data.indexOf(",P:");
  int tPos = data.indexOf(",T:");
  int rPos = data.indexOf(",R:");
  int sPos = data.indexOf(",S:");
  int ePos = data.indexOf(",E:");
  
  if (cPos != -1 && pPos != -1 && tPos != -1 && rPos != -1 && sPos != -1) {
    newCurrent = data.substring(cPos + 2, pPos).toFloat();
    newPower = data.substring(pPos + 3, tPos).toFloat();
    newTemperature = data.substring(tPos + 3, rPos).toFloat();
    newRelayState = data.substring(rPos + 3, sPos).toInt() == 1;
    
    // Check for emergency status field
    if (ePos != -1) {
      newDeviceState = data.substring(sPos + 3, ePos).toInt();
      newEmergencyStatus = data.substring(ePos + 3).toInt() == 1;
    } else {
      newDeviceState = data.substring(sPos + 3).toInt();
    }
    
    // Update values
    current = newCurrent;
    power = newPower;
    temperature = newTemperature;
    relayState = newRelayState;
    deviceState = newDeviceState;
    emergencyStatus = newEmergencyStatus;
    
    if (DEBUG_MODE) {
      Serial.print("Parsed values - Current: ");
      Serial.print(current);
      Serial.print("A, Power: ");
      Serial.print(power);
      Serial.print("W, Temp: ");
      Serial.print(temperature);
      Serial.print("°C, Relay: ");
      Serial.print(relayState ? "ON" : "OFF");
      Serial.print(", State: ");
      Serial.print(deviceState);
      Serial.print(", Emergency: ");
      Serial.println(emergencyStatus ? "YES" : "NO");
    }
  }
  
  // Check for special messages
  if (data.indexOf("EMERGENCY:") >= 0) {
    handleEmergency(data.substring(data.indexOf("EMERGENCY:") + 10));
  } else if (data.indexOf("WARNING:") >= 0) {
    handleWarning(data.substring(data.indexOf("WARNING:") + 8));
  } else if (data.indexOf("INFO:") >= 0) {
    handleInfo(data.substring(data.indexOf("INFO:") + 5));
  }
}

void handleEmergency(String message) {
  // Set emergency status flag
  emergencyStatus = true;
  
  if (DEBUG_MODE) {
    Serial.println("EMERGENCY: " + message);
  }
  
  // Update Firebase with emergency status
  if (firebaseConnected) {
    FirebaseJson json;
    json.set("type", "emergency");
    json.set("message", message);
    json.set("temperature", temperature);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.pushJSON(fbdo, "events/" + deviceID, json)) {
      Serial.println("Emergency event recorded in Firebase");
    } else {
      Serial.println("Failed to record emergency event");
      Serial.println(fbdo.errorReason());
    }
  }
}

void handleWarning(String message) {
  if (DEBUG_MODE) {
    Serial.println("WARNING: " + message);
  }
  
  // Update Firebase with warning status
  if (firebaseConnected) {
    FirebaseJson json;
    json.set("type", "warning");
    json.set("message", message);
    json.set("temperature", temperature);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.pushJSON(fbdo, "events/" + deviceID, json)) {
      Serial.println("Warning event recorded in Firebase");
    } else {
      Serial.println("Failed to record warning event");
      Serial.println(fbdo.errorReason());
    }
  }
}

void handleInfo(String message) {
  if (DEBUG_MODE) {
    Serial.println("INFO: " + message);
  }
  
  // Reset emergency status if it was temperature related
  if (message == "TEMP_NORMAL") {
    emergencyStatus = false;
  }
  
  // Update Firebase with info status
  if (firebaseConnected) {
    FirebaseJson json;
    json.set("type", "info");
    json.set("message", message);
    json.set("temperature", temperature);
    json.set("timestamp/.sv", "timestamp");
    
    if (Firebase.pushJSON(fbdo, "events/" + deviceID, json)) {
      Serial.println("Info event recorded in Firebase");
    } else {
      Serial.println("Failed to record info event");
      Serial.println(fbdo.errorReason());
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
    arduinoSerial.begin(115200);
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
  if (!firebaseConnected) {
    return;
  }
  
  // Update session uptime
  unsigned long currentMillis = millis();
  sessionUptime += (currentMillis - uptimeLastCheck) / 1000;
  uptimeLastCheck = currentMillis;
  
  FirebaseJson json;
  json.set("current", current);
  json.set("power", power);
  json.set("temperature", temperature);
  json.set("relayState", relayState);
  json.set("deviceState", deviceState);
  json.set("emergencyStatus", emergencyStatus);
  json.set("uptime", sessionUptime);
  json.set("timestamp/.sv", "timestamp");
  json.set("ipAddress", WiFi.localIP().toString());
  json.set("rssi", WiFi.RSSI());
  
  if (Firebase.updateNode(fbdo, "devices/" + deviceID + "/status", json)) {
    reconnectAttempts = 0; // Reset reconnect attempts after successful update
    if (DEBUG_MODE) {
      Serial.println("Firebase update successful");
    }
  } else {
    Serial.println("Firebase update failed: " + fbdo.errorReason());
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