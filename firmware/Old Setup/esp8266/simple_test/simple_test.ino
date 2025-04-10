#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>

// WiFi credentials
const char* WIFI_SSID = "Corner Office";
const char* WIFI_PASSWORD = "WhyweeAlecBev";

// Firebase configuration
#define FIREBASE_HOST "smartplugdatabase-f1fd4-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "HpJdlh2JYLAyxFuORNf4CmygciMeIwbC1ZZpWAjG"

// Define Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Store Firebase response
bool firebaseSuccess = false;

void setup() {
  // Initialize Serial
  Serial.begin(115200);
  delay(100);
  Serial.println();
  Serial.println("ESP8266 Firebase Test");

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

  // Initialize Firebase with proper configuration
  Serial.println("Initializing Firebase...");
  
  // Format host string (remove https:// and trailing slash)
  String host = FIREBASE_HOST;
  if (host.startsWith("https://")) {
    host = host.substring(8);
  }
  if (host.endsWith("/")) {
    host = host.substring(0, host.length() - 1);
  }
  
  Serial.print("Using Firebase Host: ");
  Serial.println(host);
  Serial.print("Using Firebase Auth: ");
  Serial.println(FIREBASE_AUTH);
  
  // Configure the FirebaseConfig object
  // NOTE: database_url is the key field that must be set
  config.database_url = host.c_str();
  
  // Try both authentication methods
  config.signer.tokens.legacy_token = FIREBASE_AUTH;  // For Database Secret auth
  
  // Initialize Firebase with config and auth objects
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Firebase initialized, waiting 3 seconds before testing...");
  delay(3000);
  
  // Test writing data to multiple paths
  firebaseSuccess = tryWriteToFirebase();
  
  if (!firebaseSuccess) {
    Serial.println("All Firebase write attempts failed.");
    Serial.println("Please check Firebase configuration and database rules.");
  }
}

bool tryWriteToFirebase() {
  // Try multiple paths in case the root path doesn't work
  if (tryPath("test")) return true;
  if (tryPath("devices/plug1/test")) return true;
  if (tryPath("smart_plugs/plug1/test")) return true;
  if (tryPath("devices/plug1/status")) return true;
  return false;
}

bool tryPath(const String& path) {
  Serial.print("Trying to write to path: ");
  Serial.println(path);
  
  if (Firebase.setString(fbdo, path, "Hello from ESP8266")) {
    Serial.println("Firebase write successful!");
    Serial.println("PATH: " + fbdo.dataPath());
    Serial.println("TYPE: " + fbdo.dataType());
    return true;
  } else {
    Serial.println("Firebase write failed");
    Serial.println("REASON: " + fbdo.errorReason());
    return false;
  }
}

void loop() {
  // Only attempt reads if we were successful in writing
  if (firebaseSuccess) {
    // Try all paths that worked for writing
    String path = fbdo.dataPath();
    if (path.length() > 0) {
      if (Firebase.getString(fbdo, path)) {
        printFirebaseData();
      } else {
        Serial.println("Failed to read from path: " + path);
        Serial.println("REASON: " + fbdo.errorReason());
      }
    } else {
      // Fallback to trying all paths if we don't have a known working path
      if (Firebase.getString(fbdo, "test") || 
          Firebase.getString(fbdo, "devices/plug1/test") ||
          Firebase.getString(fbdo, "smart_plugs/plug1/test") ||
          Firebase.getString(fbdo, "devices/plug1/status")) {
        printFirebaseData();
      } else {
        Serial.println("Failed to read from any Firebase path");
        Serial.println("REASON: " + fbdo.errorReason());
      }
    }
  }
  
  delay(10000);
}

void printFirebaseData() {
  Serial.print("Data from Firebase (Path: ");
  Serial.print(fbdo.dataPath());
  Serial.print("): ");
  Serial.println(fbdo.stringData());
} 