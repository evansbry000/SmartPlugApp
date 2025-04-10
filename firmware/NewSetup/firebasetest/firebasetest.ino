/*
 * Arduino R4 WiFi + Firebase RTDB Test
 * 
 * This test script verifies connectivity between the Arduino R4
 * and Firebase Realtime Database using the legacy secret authentication method.
 */

#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <ArduinoHttpClient.h>
#include <SSLClient.h>
#include "trust_anchors.h" // Include SSL certificates for secure connections

// WiFi credentials
const char* WIFI_SSID = "FatLARDbev";
const char* WIFI_PASSWORD = "fatlardr6";

// Firebase configuration
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG"; // Legacy database secret
const char* FIREBASE_HOST_WITHOUT_HTTPS = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const int FIREBASE_PORT = 443;

// Device ID
const char* DEVICE_ID = "plug1";

// Status LED
const int STATUS_LED = LED_BUILTIN;

// Timing variables
unsigned long sendDataPrevMillis = 0;
const unsigned long DATA_SEND_INTERVAL = 15000; // Send data every 15 seconds
unsigned long sessionUptime = 0;
unsigned long uptimeLastCheck = 0;

// Simulated sensor values
float current = 0.0;
float power = 0.0;
float temperature = 25.0;
bool relayState = false;
int deviceState = 0; // 0=OFF, 1=IDLE, 2=RUNNING
bool emergencyStatus = false;

// Create WiFi and HTTP clients
WiFiClient wifiClient;
SSLClient sslClient(wifiClient, TAs, (size_t)TAs_NUM, A7); // A7 as entropy source
HttpClient httpClient(sslClient, FIREBASE_HOST_WITHOUT_HTTPS, FIREBASE_PORT);

void setup() {
  // Initialize serial
  Serial.begin(115200);
  delay(1000); // Give time for serial monitor to open
  
  // Initialize LED
  pinMode(STATUS_LED, OUTPUT);
  
  // Print startup message
  Serial.println();
  Serial.println("Arduino R4 Firebase RTDB Test - Legacy Secret Authentication");
  Serial.println("========================================================");
  
  // Initialize simulated sensor values
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
  setupWiFi();
  
  // Test Firebase connection
  testFirebaseConnection();
  
  Serial.println("Setup complete");
  Serial.println("Sending data every 15 seconds...");
}

void loop() {
  // Update uptime
  unsigned long currentMillis = millis();
  sessionUptime += (currentMillis - uptimeLastCheck) / 1000;
  uptimeLastCheck = currentMillis;
  
  // Simulate changing sensor readings
  simulateSensorReadings();
  
  // Send data to Firebase every 15 seconds
  if (millis() - sendDataPrevMillis > DATA_SEND_INTERVAL || sendDataPrevMillis == 0) {
    sendDataPrevMillis = millis();
    sendDataToFirebase();
  }
  
  // Check for relay commands from Firebase
  if (millis() % 10000 < 20) { // Check every 10 seconds
    checkFirebaseCommands();
  }
  
  // Blink LED to indicate program is running
  if (millis() % 2000 < 100) {
    digitalWrite(STATUS_LED, HIGH);
  } else {
    digitalWrite(STATUS_LED, LOW);
  }
  
  delay(100); // Short delay to prevent CPU hogging
}

void setupWiFi() {
  Serial.print("Connecting to WiFi network: ");
  Serial.println(WIFI_SSID);
  
  // Check if WiFi module is present
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    while (true); // Don't continue
  }
  
  // Print firmware version
  String fv = WiFi.firmwareVersion();
  Serial.print("WiFi firmware version: ");
  Serial.println(fv);
  
  // Connect to WiFi
  int status = WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait for connection
  Serial.print("Connecting");
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - startTime > 30000) { // 30 second timeout
      Serial.println("\nFailed to connect to WiFi. Please check credentials and restart.");
      while (true); // Don't continue
    }
    delay(500);
    Serial.print(".");
    digitalWrite(STATUS_LED, !digitalRead(STATUS_LED)); // Toggle LED
  }
  
  // Connected
  Serial.println();
  Serial.println("WiFi connected successfully!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  // Display signal strength
  int rssi = WiFi.RSSI();
  Serial.print("Signal strength (RSSI): ");
  Serial.print(rssi);
  Serial.println(" dBm");
}

void testFirebaseConnection() {
  Serial.println("\nTesting Firebase connection...");
  
  // Test path with simple data
  String testPath = "/test/connection_test.json";
  testPath += "?auth=" + String(FIREBASE_AUTH);
  
  // Create JSON payload
  DynamicJsonDocument jsonBuffer(256);
  jsonBuffer["device"] = "Arduino R4";
  jsonBuffer["timestamp"] = millis();
  jsonBuffer["test"] = "Initial connection test";
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Send HTTP PUT request
  Serial.println("Sending test data to Firebase...");
  httpClient.beginRequest();
  httpClient.put(testPath);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  // Get response
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  Serial.print("HTTP Status: ");
  Serial.println(statusCode);
  
  // Check response
  if (statusCode == 200) {
    Serial.println("Firebase connection test successful!");
    Serial.print("Response: ");
    Serial.println(response);
    
    // Success indicator
    for (int i = 0; i < 5; i++) {
      digitalWrite(STATUS_LED, HIGH);
      delay(100);
      digitalWrite(STATUS_LED, LOW);
      delay(100);
    }
  } else {
    Serial.println("Firebase connection test failed!");
    Serial.print("Error response: ");
    Serial.println(response);
    
    // Error indicator
    for (int i = 0; i < 10; i++) {
      digitalWrite(STATUS_LED, HIGH);
      delay(50);
      digitalWrite(STATUS_LED, LOW);
      delay(50);
    }
  }
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

void sendDataToFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Cannot send data.");
    return;
  }
  
  // Create JSON payload
  DynamicJsonDocument jsonBuffer(1024);
  jsonBuffer["current"] = current;
  jsonBuffer["power"] = power;
  jsonBuffer["temperature"] = temperature;
  jsonBuffer["relayState"] = relayState;
  jsonBuffer["deviceState"] = deviceState;
  jsonBuffer["emergencyStatus"] = emergencyStatus;
  jsonBuffer["uptime"] = sessionUptime;
  jsonBuffer["timestamp"] = millis();
  jsonBuffer["ipAddress"] = WiFi.localIP().toString();
  jsonBuffer["rssi"] = WiFi.RSSI();
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Path for status data
  String path = "/devices/" + String(DEVICE_ID) + "/status.json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  // Send HTTP PUT request
  Serial.print("Sending data to Firebase... ");
  httpClient.beginRequest();
  httpClient.put(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  // Get response
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  if (statusCode == 200) {
    Serial.println("SUCCESS");
    Serial.print("Current: "); Serial.print(current); Serial.println(" A");
    Serial.print("Power: "); Serial.print(power); Serial.println(" W");
    Serial.print("Temperature: "); Serial.print(temperature); Serial.println(" °C");
    Serial.print("Relay State: "); Serial.println(relayState ? "ON" : "OFF");
    Serial.print("Device State: "); Serial.println(deviceState);
    Serial.print("Emergency Status: "); Serial.println(emergencyStatus ? "YES" : "NO");
    Serial.print("Uptime: "); Serial.print(sessionUptime); Serial.println(" s");
    Serial.println();
    
    // Success indicator
    digitalWrite(STATUS_LED, HIGH);
    delay(50);
    digitalWrite(STATUS_LED, LOW);
  } else {
    Serial.println("FAILED");
    Serial.print("HTTP Status: ");
    Serial.println(statusCode);
    Serial.print("Response: ");
    Serial.println(response);
    Serial.println();
    
    // Error indicator
    for (int i = 0; i < 3; i++) {
      digitalWrite(STATUS_LED, HIGH);
      delay(50);
      digitalWrite(STATUS_LED, LOW);
      delay(50);
    }
  }
  
  // Randomly generate test events (10% chance)
  if (random(100) < 10) {
    sendTestEvent();
  }
}

void sendTestEvent() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  
  // Create JSON for the event
  DynamicJsonDocument jsonBuffer(512);
  String eventType = "";
  String message = "";
  
  // Choose a random event type for testing
  int eventChoice = random(4);
  
  switch (eventChoice) {
    case 0:
      eventType = "info";
      message = "STATUS_UPDATE";
      break;
    case 1:
      eventType = "warning";
      message = "HIGH_TEMP";
      jsonBuffer["temperature"] = temperature;
      break;
    case 2:
      eventType = "state_change";
      message = deviceState == 0 ? "OFF" : (deviceState == 1 ? "IDLE" : "RUNNING");
      break;
    case 3:
      eventType = "connection";
      message = "HEARTBEAT";
      break;
  }
  
  jsonBuffer["type"] = eventType;
  jsonBuffer["message"] = message;
  jsonBuffer["timestamp"] = millis();
  
  // Serialize JSON
  String jsonStr;
  serializeJson(jsonBuffer, jsonStr);
  
  // Path for events
  String path = "/events/" + String(DEVICE_ID) + ".json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  Serial.print("Sending test event to Firebase... ");
  
  // Use HTTP POST for events
  httpClient.beginRequest();
  httpClient.post(path);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Content-Length", jsonStr.length());
  httpClient.beginBody();
  httpClient.print(jsonStr);
  httpClient.endRequest();
  
  // Get response
  int statusCode = httpClient.responseStatusCode();
  
  if (statusCode == 200) {
    Serial.println("SUCCESS");
    Serial.print("Event Type: "); Serial.print(eventType);
    Serial.print(", Message: "); Serial.println(message);
  } else {
    Serial.println("FAILED");
    Serial.print("HTTP Status: "); Serial.println(statusCode);
  }
}

void checkFirebaseCommands() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }
  
  // Path for relay commands
  String path = "/devices/" + String(DEVICE_ID) + "/commands/relay.json";
  path += "?auth=" + String(FIREBASE_AUTH);
  
  // Send HTTP GET request
  httpClient.beginRequest();
  httpClient.get(path);
  httpClient.endRequest();
  
  // Get response
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  if (statusCode == 200 && response != "null") {
    Serial.println("Checking for commands...");
    
    // Parse JSON response
    DynamicJsonDocument doc(512);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      // Check if there is a command not yet processed
      if (doc.containsKey("state") && !doc["processed"]) {
        bool newState = doc["state"];
        
        if (newState != relayState) {
          Serial.print("Relay command received: ");
          Serial.println(newState ? "ON" : "OFF");
          
          // Update relay state
          relayState = newState;
          
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
          httpClient.sendHeader("Content-Length", ackJson.length());
          httpClient.beginBody();
          httpClient.print(ackJson);
          httpClient.endRequest();
          
          if (httpClient.responseStatusCode() == 200) {
            Serial.println("Command acknowledged");
          }
        }
      }
    } else {
      Serial.print("JSON parsing error: ");
      Serial.println(error.c_str());
    }
  }
}
