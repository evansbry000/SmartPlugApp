#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* WIFI_SSID = "Corner Office";
const char* WIFI_PASSWORD = "WhyweeAlecBev";

// Firebase configuration
const char* FIREBASE_HOST = "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG";

// Define multiple possible paths for testing
const char* TEST_PATHS[] = {
  "test",
  "devices/plug1/test",
  "smart_plugs/plug1/test",
  "devices/plug1/status"
};
const int NUM_PATHS = 4;

// For making HTTP requests to Firebase
HTTPClient http;
WiFiClientSecure secureClient;

// Track successful paths
String successfulPath = "";
bool hasInitialized = false;

void setup() {
  // Initialize Serial
  Serial.begin(115200);
  delay(100);
  Serial.println();
  Serial.println("ESP8266 Firebase HTTP Test");

  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  Serial.println();

  // Fingerprint for firebase - optional but recommended for security
  // You can get this fingerprint by visiting https://www.grc.com/fingerprints.htm
  // and entering your Firebase host
  // const uint8_t FIREBASE_FINGERPRINT[] = {0x03, 0x9e, 0x4f, 0xe6, 0x83, 0x56, 0x11, 0x41, 0x88, 0x28, 0x83, 0x41, 0x72, 0x94, 0x0d, 0x83, 0x71, 0x31, 0x81, 0x62};
  // secureClient.setFingerprint(FIREBASE_FINGERPRINT);
  
  // Skip SSL certificate verification for testing only
  secureClient.setInsecure();
  
  // First, attempt to retrieve the rules to verify connection
  testFirebaseAccess();
  
  // Initialize by writing to Firebase (testing each path)
  initializeFirebase();
}

void loop() {
  // Only read from Firebase if initialization was successful
  if (hasInitialized && successfulPath.length() > 0) {
    readFromFirebase(successfulPath);
  } else {
    // Try to initialize again if failed previously
    if (!hasInitialized) {
      Serial.println("Attempting to initialize Firebase again...");
      initializeFirebase();
    }
  }
  
  delay(10000);
}

void testFirebaseAccess() {
  // Try both database secret and API key authentication to determine which works
  
  // Method 1: Test with database secret (auth parameter)
  Serial.println("\nTesting Firebase connection with database secret...");
  String urlWithSecret = "https://" + String(FIREBASE_HOST) + "/.json?auth=" + String(FIREBASE_AUTH);
  
  Serial.print("URL: ");
  Serial.println(urlWithSecret);
  
  http.begin(secureClient, urlWithSecret);
  http.setTimeout(15000);
  
  int httpCode = http.GET();
  String payload = http.getString();
  
  Serial.print("HTTP Code: ");
  Serial.println(httpCode);
  Serial.println("Response: " + payload);
  
  http.end();
  
  // Method 2: Try API key authentication if database secret didn't work
  if (httpCode != 200) {
    Serial.println("\nTesting Firebase connection with API key...");
    // For REST API with API key, we use a different URL format
    String urlWithApiKey = "https://" + String(FIREBASE_HOST) + "/.json?key=" + String(FIREBASE_AUTH);
    
    Serial.print("URL: ");
    Serial.println(urlWithApiKey);
    
    http.begin(secureClient, urlWithApiKey);
    http.setTimeout(15000);
    
    httpCode = http.GET();
    payload = http.getString();
    
    Serial.print("HTTP Code: ");
    Serial.println(httpCode);
    Serial.println("Response: " + payload);
    
    http.end();
  }
}

void initializeFirebase() {
  // Try to create a data structure from the root first
  Serial.println("\nCreating base data structure if needed...");
  
  // First create the basic structure (devices and smart_plugs nodes)
  createBasicStructure();
  
  // Then try writing to all paths to find one that works
  for (int i = 0; i < NUM_PATHS; i++) {
    if (writeToFirebase(TEST_PATHS[i], "Hello from ESP8266")) {
      successfulPath = TEST_PATHS[i];
      hasInitialized = true;
      Serial.print("Successfully initialized Firebase with path: ");
      Serial.println(successfulPath);
      return;
    }
  }
  
  Serial.println("Failed to initialize Firebase with any path.");
}

void createBasicStructure() {
  // Try to create base nodes using both auth methods
  
  // Method 1: Create with database secret
  createNodeWithAuth("devices", "{\"created\":true}", "auth");
  createNodeWithAuth("smart_plugs", "{\"created\":true}", "auth");
  
  // Try to create the plug1 node under devices
  createNodeWithAuth("devices/plug1", "{\"status\":\"initializing\"}", "auth");
  
  // Method 2: If the above failed, try with API key
  createNodeWithAuth("devices", "{\"created\":true}", "key");
  createNodeWithAuth("smart_plugs", "{\"created\":true}", "key");
  createNodeWithAuth("devices/plug1", "{\"status\":\"initializing\"}", "key");
}

bool createNodeWithAuth(String path, String jsonData, String authType) {
  // Format Firebase URL with the appropriate auth parameter type
  if (path.startsWith("/")) {
    path = path.substring(1);
  }
  
  String url = "https://" + String(FIREBASE_HOST) + "/" + path + ".json";
  
  // Add authentication parameter based on type
  if (authType == "auth") {
    url += "?auth=" + String(FIREBASE_AUTH);  // Database secret
  } else {
    url += "?key=" + String(FIREBASE_AUTH);   // API key
  }
  
  Serial.print("Creating node at: ");
  Serial.println(url);
  
  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Connection", "close");
  http.setTimeout(15000);
  
  int httpCode = http.PUT(jsonData);
  String payload = http.getString();
  
  http.end();
  
  if (httpCode == 200) {
    Serial.println("Node creation successful!");
    Serial.println("Response: " + payload);
    return true;
  } else {
    Serial.println("Node creation failed");
    Serial.println("HTTP Response code: " + String(httpCode));
    Serial.println("Response: " + payload);
    return false;
  }
}

bool writeToFirebase(String path, String value) {
  // Try both authentication methods
  if (writeWithAuth(path, value, "auth")) return true;  // Try database secret first
  return writeWithAuth(path, value, "key");             // Try API key if first method failed
}

bool writeWithAuth(String path, String value, String authType) {
  // Format Firebase URL with the appropriate auth parameter type
  if (path.startsWith("/")) {
    path = path.substring(1);
  }
  
  String url = "https://" + String(FIREBASE_HOST) + "/" + path + ".json";
  
  // Add authentication parameter based on type
  if (authType == "auth") {
    url += "?auth=" + String(FIREBASE_AUTH);  // Database secret
  } else {
    url += "?key=" + String(FIREBASE_AUTH);   // API key
  }
  
  Serial.print("Writing to Firebase URL (" + authType + "): ");
  Serial.println(url);
  
  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Connection", "close");
  http.setTimeout(15000);
  
  // Format JSON properly
  String jsonData = "\"" + value + "\"";
  
  int httpCode = http.PUT(jsonData);
  String payload = http.getString();
  
  http.end();
  
  if (httpCode == 200) {
    Serial.println("Firebase write successful!");
    Serial.println("Response: " + payload);
    return true;
  } else {
    Serial.println("Firebase write failed");
    Serial.println("HTTP Response code: " + String(httpCode));
    Serial.println("Response: " + payload);
    return false;
  }
}

void readFromFirebase(String path) {
  // Try both authentication methods
  if (!readWithAuth(path, "auth")) {  // Try database secret first
    readWithAuth(path, "key");        // Try API key if first method failed
  }
}

bool readWithAuth(String path, String authType) {
  if (path.startsWith("/")) {
    path = path.substring(1);
  }
  
  String url = "https://" + String(FIREBASE_HOST) + "/" + path + ".json";
  
  // Add authentication parameter based on type
  if (authType == "auth") {
    url += "?auth=" + String(FIREBASE_AUTH);  // Database secret
  } else {
    url += "?key=" + String(FIREBASE_AUTH);   // API key
  }
  
  Serial.print("Reading from Firebase URL (" + authType + "): ");
  Serial.println(url);
  
  http.begin(secureClient, url);
  http.addHeader("Connection", "close");
  http.setTimeout(15000);
  
  int httpCode = http.GET();
  String payload = http.getString();
  
  http.end();
  
  if (httpCode == 200) {
    Serial.println("Firebase read successful!");
    Serial.println("Data: " + payload);
    
    // Parse JSON if needed
    parseJsonResponse(payload);
    return true;
  } else {
    Serial.println("Firebase read failed");
    Serial.println("HTTP Response code: " + String(httpCode));
    Serial.println("Response: " + payload);
    return false;
  }
}

void parseJsonResponse(String jsonString) {
  // For simple string values, we can check directly
  if (jsonString.startsWith("\"") && jsonString.endsWith("\"")) {
    // This is a string value - remove quotes
    String value = jsonString.substring(1, jsonString.length() - 1);
    Serial.print("Simple string value: ");
    Serial.println(value);
    return;
  }
  
  // For more complex JSON, we need to parse it
  DynamicJsonDocument doc(1024);
  DeserializationError error = deserializeJson(doc, jsonString);
  
  if (error) {
    Serial.print("JSON parsing failed: ");
    Serial.println(error.c_str());
    return;
  }
  
  // Print first level of JSON
  Serial.println("JSON data:");
  JsonObject obj = doc.as<JsonObject>();
  for (JsonPair p : obj) {
    Serial.print("  ");
    Serial.print(p.key().c_str());
    Serial.print(": ");
    
    if (p.value().is<const char*>()) {
      Serial.println(p.value().as<const char*>());
    } else if (p.value().is<int>()) {
      Serial.println(p.value().as<int>());
    } else if (p.value().is<float>()) {
      Serial.println(p.value().as<float>());
    } else if (p.value().is<bool>()) {
      Serial.println(p.value().as<bool>() ? "true" : "false");
    } else {
      Serial.println("[complex object]");
    }
  }
} 