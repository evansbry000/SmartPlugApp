#include <Arduino.h>
#if defined(ESP32)
  #include <WiFi.h>
#elif defined(ESP8266)
  #include <ESP8266WiFi.h>
#endif
#include <Firebase_ESP_Client.h>

// Provide the RTDB payload printing info and other helper functions.
#include "addons/RTDBHelper.h"

// Insert your network credentials
#define WIFI_SSID "FatLARDbev"
#define WIFI_PASSWORD "fatlardr6"

// Firebase project settings
#define DATABASE_URL "https://smartplugdatabase-f1fd4-default-rtdb.firebaseio.com/"
#define DATABASE_SECRET "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG" // Legacy secret for database access

// Device ID
#define DEVICE_ID "plug1"

// Define Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Timing variables
unsigned long sendDataPrevMillis = 0;
const unsigned long DATA_SEND_INTERVAL = 30000; // Send data every 30 seconds
unsigned long sessionUptime = 0;
unsigned long uptimeLastCheck = 0;

// Simulated sensor values
float current = 0.0;
float power = 0.0;
float temperature = 25.0;
bool relayState = false;
int deviceState = 0; // 0=OFF, 1=IDLE, 2=RUNNING
bool emergencyStatus = false;

void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("ESP32 Firebase RTDB Test - Legacy Secret Authentication");
  Serial.println("===================================================");
  
  // Initialize sensor values with some random data
  current = random(10, 100) / 100.0; // 0.1 to 1.0 A
  power = current * 120.0;           // P = I*V (assuming 120V)
  temperature = random(20, 35);      // 20 to 35 °C
  relayState = false;
  deviceState = 0;
  emergencyStatus = false;
  
  // Initialize uptime tracking
  sessionUptime = 0;
  uptimeLastCheck = millis();
  
  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  
  // Configure Firebase with legacy token authentication
  config.database_url = DATABASE_URL;
  config.signer.tokens.legacy_token = DATABASE_SECRET;
  
  // Set buffer sizes and timeouts for better performance
  fbdo.setBSSLBufferSize(4096, 1024);
  fbdo.setResponseSize(4096);
  
  // Initialize Firebase
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  // Set timeouts directly on the FirebaseData object
  fbdo.setReadTimeout(60 * 1000); // 1 minute timeout
  
  Serial.println("Firebase setup complete");
  Serial.println("Sending data every 30 seconds...");
}

void loop() {
  // Update simulated sensor values periodically
  simulateSensorReadings();
  
  // Check if it's time to send data
  if (Firebase.ready() && (millis() - sendDataPrevMillis > DATA_SEND_INTERVAL || sendDataPrevMillis == 0)) {
    sendDataPrevMillis = millis();
    
    // Update session uptime (in seconds)
    unsigned long currentMillis = millis();
    sessionUptime += (currentMillis - uptimeLastCheck) / 1000;
    uptimeLastCheck = currentMillis;
    
    // Create JSON payload
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
    
    // Path to your device's status in RTDB
    String path = "devices/" + String(DEVICE_ID) + "/status";
    
    // Send data to Firebase
    Serial.print("Sending data to Firebase... ");
    if (Firebase.RTDB.updateNode(&fbdo, path, &json)) {
      Serial.println("SUCCESS");
      Serial.print("Current: "); Serial.print(current); Serial.println(" A");
      Serial.print("Power: "); Serial.print(power); Serial.println(" W");
      Serial.print("Temperature: "); Serial.print(temperature); Serial.println(" °C");
      Serial.print("Relay State: "); Serial.println(relayState ? "ON" : "OFF");
      Serial.print("Device State: "); Serial.println(deviceState);
      Serial.print("Emergency Status: "); Serial.println(emergencyStatus ? "YES" : "NO");
      Serial.print("Uptime: "); Serial.print(sessionUptime); Serial.println(" s");
      Serial.println();
    } else {
      Serial.println("FAILED");
      Serial.println("REASON: " + fbdo.errorReason());
      Serial.println();
    }
    
    // Check if we should simulate an emergency event
    if (random(100) < 5) { // 5% chance of an event
      simulateEvent();
    }
  }
  
  // Check for relay commands from Firebase
  if (Firebase.ready() && (millis() - sendDataPrevMillis > 5000)) {
    checkFirebaseCommands();
  }
  
  // Allow time for WiFi/Firebase tasks
  delay(1000);
}

void simulateSensorReadings() {
  // Simulate small changes in sensor readings for demonstration
  current = max(0.0, current + (random(-20, 20) / 100.0));
  power = current * 120.0;
  temperature = max(20.0, min(45.0, temperature + (random(-10, 10) / 10.0)));
  
  // Update device state based on power usage
  if (!relayState) {
    deviceState = 0; // OFF
  } else if (power < 10.0) {
    deviceState = 1; // IDLE
  } else {
    deviceState = 2; // RUNNING
  }
  
  // Set emergency status if temperature is too high
  if (temperature > 40.0) {
    emergencyStatus = true;
  } else if (temperature < 35.0) {
    emergencyStatus = false;
  }
}

void simulateEvent() {
  // Create a simulated event to test event mirroring
  FirebaseJson json;
  String eventType = "";
  String message = "";
  
  if (temperature > 40.0) {
    eventType = "emergency";
    message = "TEMP_SHUTOFF";
  } else if (temperature > 35.0) {
    eventType = "warning";
    message = "HIGH_TEMP";
  } else {
    eventType = "info";
    message = "STATUS_UPDATE";
  }
  
  json.set("type", eventType);
  json.set("message", message);
  json.set("temperature", temperature);
  json.set("timestamp/.sv", "timestamp");
  
  // Path to events in RTDB
  String path = "events/" + String(DEVICE_ID);
  
  Serial.print("Sending event to Firebase... ");
  if (Firebase.RTDB.pushJSON(&fbdo, path, &json)) {
    Serial.println("SUCCESS");
    Serial.print("Event Type: "); Serial.println(eventType);
    Serial.print("Message: "); Serial.println(message);
    Serial.println();
  } else {
    Serial.println("FAILED");
    Serial.println("REASON: " + fbdo.errorReason());
    Serial.println();
  }
}

void checkFirebaseCommands() {
  // Check for relay commands from Firebase
  if (Firebase.RTDB.getJSON(&fbdo, "devices/" + String(DEVICE_ID) + "/commands/relay")) {
    FirebaseJson json;
    FirebaseJsonData result;
    
    json.setJsonData(fbdo.to<String>());
    json.get(result, "state");
    
    if (result.success) {
      bool newState = result.to<bool>();
      
      if (newState != relayState) {
        relayState = newState;
        Serial.print("Relay command received: ");
        Serial.println(relayState ? "ON" : "OFF");
        
        // Clear command after processing
        FirebaseJson ackJson;
        ackJson.set("processed", true);
        ackJson.set("timestamp/.sv", "timestamp");
        
        Firebase.RTDB.updateNode(&fbdo, "devices/" + String(DEVICE_ID) + "/commands/relay", &ackJson);
      }
    }
  }
} 
