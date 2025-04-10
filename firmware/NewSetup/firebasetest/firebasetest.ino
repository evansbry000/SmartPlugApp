/*
 * Arduino R4 WiFi - Firebase Test
 * This sketch tests connectivity to Firebase Realtime Database using WiFiSSLClient
 * 
 * Required Libraries:
 * - WiFiS3 (Arduino)
 * - ArduinoJson (Benoit Blanchon)
 * - ArduinoHttpClient (Arduino)
 */

#include <WiFiS3.h>
#include <ArduinoJson.h>
#include <ArduinoHttpClient.h>

// WiFi credentials
const char* WIFI_SSID = "FatLARDbev";
const char* WIFI_PASSWORD = "fatlardr6";

// Firebase settings
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_API_KEY = "AIzaSyCDETZaO4KfbuahJuCrvupJgo4nFPvkA8E";  // Web API key

// Firebase path
const char* FIREBASE_PATH = "/test";

// Connection objects
WiFiSSLClient wifiSSLClient;  // Using WiFiSSLClient instead of WiFiClient
HttpClient httpClient(wifiSSLClient, FIREBASE_HOST, 443);  // Back to port 443 for HTTPS

// Status LED
const int LED_PIN = 13;  // Built-in LED on Arduino R4

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(1000);
  Serial.println("Arduino R4 WiFi - Firebase Test (using WiFiSSLClient)");
  
  // Configure LED pin
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Connect to WiFi
  connectToWiFi();
  
  // Test Firebase connection by sending initial data
  bool success = sendTestData();
  
  // Set LED based on Firebase connection status
  digitalWrite(LED_PIN, success ? HIGH : LOW);
}

void loop() {
  // Send test data every 15 seconds
  static unsigned long previousMillis = 0;
  const long interval = 15000;  // 15 seconds
  
  unsigned long currentMillis = millis();
  
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;
    
    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi connection lost. Reconnecting...");
      connectToWiFi();
    }
    
    // Send test data
    bool success = sendTestData();
    
    // Update LED status
    digitalWrite(LED_PIN, success ? HIGH : LOW);
  }
}

void connectToWiFi() {
  // Disconnect if connected
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }
  
  Serial.print("Connecting to WiFi...");
  
  // Begin WiFi connection - Note: WiFiS3 doesn't use mode() function
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // Wait for connection (with timeout)
  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && 
         millis() - startAttemptTime < 10000) {
    Serial.print(".");
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
    Serial.println("Failed to connect to WiFi. Please check credentials.");
  }
}

void configTime() {
  // Get time from NTP server
  WiFi.getTime();
  delay(1000);
}

bool sendTestData() {
  // Prepare test data
  static int testInt = 0;
  float testFloat = random(0, 100) / 10.0;
  
  // Create JSON document
  StaticJsonDocument<128> doc;
  doc["int_value"] = testInt++;
  doc["float_value"] = testFloat;
  doc["timestamp"] = millis();
  
  // Serialize JSON to string
  String jsonData;
  serializeJson(doc, jsonData);
  
  Serial.println("Sending data to Firebase:");
  Serial.println(jsonData);
  
  // Set up the HTTPS PUT request
  String path = String(FIREBASE_PATH) + ".json";
  String authParam = "?auth=" + String(FIREBASE_API_KEY);
  
  // Make the request with longer timeout
  httpClient.connectionKeepAlive(); // Keep connection open
  httpClient.setTimeout(10000); // 10 second timeout
  
  httpClient.beginRequest();
  httpClient.put(path + authParam);
  httpClient.sendHeader("Content-Type", "application/json");
  httpClient.sendHeader("Connection", "keep-alive");
  httpClient.sendHeader("Content-Length", jsonData.length());
  httpClient.beginBody();
  httpClient.print(jsonData);
  httpClient.endRequest();
  
  // Get the response
  int statusCode = httpClient.responseStatusCode();
  String response = httpClient.responseBody();
  
  Serial.print("Status code: ");
  Serial.println(statusCode);
  Serial.print("Response: ");
  Serial.println(response);
  
  // Check if successful
  bool success = (statusCode >= 200 && statusCode < 300);
  
  if (success) {
    Serial.println("Data sent successfully!");
  } else {
    Serial.println("Failed to send data to Firebase");
  }
  
  return success;
}
