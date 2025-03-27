#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Firebase configuration
const char* FIREBASE_API_KEY = "YOUR_FIREBASE_API_KEY";
const char* FIREBASE_AUTH_DOMAIN = "YOUR_FIREBASE_AUTH_DOMAIN";
const char* FIREBASE_PROJECT_ID = "YOUR_FIREBASE_PROJECT_ID";
const char* FIREBASE_STORAGE_BUCKET = "YOUR_FIREBASE_STORAGE_BUCKET";
const char* FIREBASE_MESSAGING_SENDER_ID = "YOUR_FIREBASE_MESSAGING_SENDER_ID";
const char* FIREBASE_APP_ID = "YOUR_FIREBASE_APP_ID";

// Firebase data object
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Serial communication with Arduino
const int ARDUINO_RX = 16;  // ESP32 RX pin
const int ARDUINO_TX = 17;  // ESP32 TX pin

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

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  
  // Initialize Serial2 for communication with Arduino
  Serial2.begin(9600, SERIAL_8N1, ARDUINO_RX, ARDUINO_TX);
  
  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nConnected to WiFi");
  
  // Configure Firebase
  config.api_key = FIREBASE_API_KEY;
  config.auth_domain = FIREBASE_AUTH_DOMAIN;
  config.project_id = FIREBASE_PROJECT_ID;
  config.storage_bucket = FIREBASE_STORAGE_BUCKET;
  config.messaging_sender_id = FIREBASE_MESSAGING_SENDER_ID;
  config.app_id = FIREBASE_APP_ID;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  unsigned long currentTime = millis();
  
  // Read data from Arduino
  if (Serial2.available()) {
    String data = Serial2.readStringUntil('\n');
    parseArduinoData(data);
    lastDataTime = currentTime;
  }
  
  // Check connection status
  if (currentTime - lastDataTime > CONNECTION_TIMEOUT) {
    handleConnectionLost();
  }
  
  // Update Firebase
  updateFirebase();
  
  // Check for Firebase commands
  checkFirebaseCommands();
  
  delay(1000);
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
  
  current = data.substring(cStart, cEnd).toFloat();
  power = data.substring(pStart, pEnd).toFloat();
  temperature = data.substring(tStart, tEnd).toFloat();
  relayState = data.substring(rStart, rEnd).toInt() == 1;
  deviceState = data.substring(sStart).toInt();
  
  // Check for emergency messages
  if (data.startsWith("EMERGENCY:")) {
    handleEmergency(data.substring(9));
  } else if (data.startsWith("WARNING:")) {
    handleWarning(data.substring(8));
  }
}

void handleEmergency(String message) {
  if (message == "TEMP_SHUTOFF") {
    // Update Firebase with emergency status
    if (Firebase.ready()) {
      StaticJsonDocument<200> doc;
      doc["type"] = "emergency";
      doc["message"] = "Temperature exceeded shutoff threshold";
      doc["temperature"] = temperature;
      doc["timestamp"] = Firebase.Timestamp();
      
      String jsonString;
      serializeJson(doc, jsonString);
      
      Firebase.Firestore.setDocument(&fbdo, "smart_plugs/plug1/events/latest", jsonString);
    }
  }
}

void handleWarning(String message) {
  if (message == "HIGH_TEMP") {
    // Update Firebase with warning status
    if (Firebase.ready()) {
      StaticJsonDocument<200> doc;
      doc["type"] = "warning";
      doc["message"] = "High temperature warning";
      doc["temperature"] = temperature;
      doc["timestamp"] = Firebase.Timestamp();
      
      String jsonString;
      serializeJson(doc, jsonString);
      
      Firebase.Firestore.setDocument(&fbdo, "smart_plugs/plug1/events/latest", jsonString);
    }
  }
}

void handleConnectionLost() {
  if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    reconnectAttempts++;
    Serial.println("Connection lost. Attempting to reconnect...");
    
    // Send connection lost event to Firebase
    if (Firebase.ready()) {
      StaticJsonDocument<200> doc;
      doc["type"] = "connection";
      doc["status"] = "lost";
      doc["attempt"] = reconnectAttempts;
      doc["timestamp"] = Firebase.Timestamp();
      
      String jsonString;
      serializeJson(doc, jsonString);
      
      Firebase.Firestore.setDocument(&fbdo, "smart_plugs/plug1/events/latest", jsonString);
    }
    
    // Attempt to reconnect
    Serial2.begin(9600, SERIAL_8N1, ARDUINO_RX, ARDUINO_TX);
    delay(RECONNECT_INTERVAL);
  } else {
    Serial.println("Max reconnection attempts reached. Manual intervention required.");
    // Send final connection lost event
    if (Firebase.ready()) {
      StaticJsonDocument<200> doc;
      doc["type"] = "connection";
      doc["status"] = "failed";
      doc["timestamp"] = Firebase.Timestamp();
      
      String jsonString;
      serializeJson(doc, jsonString);
      
      Firebase.Firestore.setDocument(&fbdo, "smart_plugs/plug1/events/latest", jsonString);
    }
  }
}

void updateFirebase() {
  if (Firebase.ready()) {
    // Create JSON document
    StaticJsonDocument<200> doc;
    doc["current"] = current;
    doc["power"] = power;
    doc["temperature"] = temperature;
    doc["relayState"] = relayState;
    doc["deviceState"] = deviceState;
    doc["timestamp"] = Firebase.Timestamp();
    
    String jsonString;
    serializeJson(doc, jsonString);
    
    // Update Firestore
    Firebase.Firestore.setDocument(&fbdo, "smart_plugs/plug1", jsonString);
  }
}

void checkFirebaseCommands() {
  if (Firebase.ready()) {
    // Get relay command from Firestore
    Firebase.Firestore.getDocument(&fbdo, "smart_plugs/plug1/commands/relay");
    
    if (fbdo.payload() != "") {
      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, fbdo.payload());
      
      if (!error && doc.containsKey("state")) {
        bool newState = doc["state"];
        sendRelayCommand(newState);
      }
    }
  }
}

void sendRelayCommand(bool state) {
  String command = "RELAY:" + String(state ? "1" : "0");
  Serial2.println(command);
} 