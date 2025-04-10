// Smart Plug Arduino Code
// This code runs on the Arduino board

// Pin Definitions
const int CURRENT_SENSOR_PIN = A0;  // ACS712 current sensor
const int TEMP_SENSOR_PIN = A1;     // LM35 temperature sensor on analog pin A1
const int RELAY_PIN = 7;            // Relay control pin D7
const int ESP_RX_PIN = 10;          // D10 Arduino pin to ESP8266 TX
const int ESP_TX_PIN = 11;          // D11 Arduino pin to ESP8266 RX

// Relay configuration
const bool USE_RELAY = false;       // Set to true if relay hardware is connected

// Sensor Constants
const int MV_PER_AMP = 66;          // 66 for 30A Module
const float TEMP_SENSOR_RATIO = 0.01; // LM35: 10mV per degree Celsius

// Device State Thresholds
const float IDLE_POWER_THRESHOLD = 10.0;  // Watts
const float RUNNING_POWER_THRESHOLD = 10.0; // Watts

// Temperature Thresholds
const float TEMP_WARNING = 35.0;    // Celsius
const float TEMP_SHUTOFF = 45.0;    // Celsius
const float TEMP_MAX = 65.0;        // Celsius
const float TEMP_MIN = 0.0;         // Celsius

// Variables
float current = 0.0;
float power = 0.0;
float temperature = 0.0;
bool relayState = false;
bool emergencyStatus = false;       // Flag for emergency conditions
unsigned long lastReadingTime = 0;
const unsigned long READING_INTERVAL = 30000; // 30 seconds

// Device State Enum
enum DeviceState {
  OFF,
  IDLE,
  RUNNING
};
DeviceState currentState = OFF;

#include <SoftwareSerial.h>
SoftwareSerial espSerial(ESP_RX_PIN, ESP_TX_PIN); // RX, TX

// Uncomment and configure with values matching your network
IPAddress staticIP(192,168,4,200); // Choose unused IP
IPAddress gateway(192,168,4,1);    // Your router's IP
IPAddress subnet(255,255,255,0);
IPAddress dns1(8,8,8,8);

void setup() {
  Serial.begin(9600);  // Serial monitor for debugging
  espSerial.begin(9600); // Communication with ESP8266
  
  // Configure pins
  if (USE_RELAY) {
    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, LOW); // Initialize relay as OFF
  }
  
  pinMode(CURRENT_SENSOR_PIN, INPUT);
  pinMode(TEMP_SENSOR_PIN, INPUT);
  
  // Initialize variables
  emergencyStatus = false;
  
  Serial.println("Smart Plug Initialized");
  espSerial.println("Arduino Ready");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Read sensors every 30 seconds
  if (currentTime - lastReadingTime >= READING_INTERVAL) {
    readSensors();
    updateDeviceState();
    checkTemperature();
    sendDataToESP8266();
    lastReadingTime = currentTime;
  }
  
  // Process any incoming commands from ESP8266
  processCommand();
}

void readSensors() {
  // Read current sensor
  float voltage = getVPP();
  float vRMS = (voltage/2.0) * 0.707;  // root 2 is 0.707
  current = (vRMS * 1000)/MV_PER_AMP;
  
  // Calculate power (using 120V AC)
  power = current * 120.0 / 1.3;  // 1.3 is empirical calibration factor
  
  // Read temperature sensor from analog pin A1
  int tempRaw = analogRead(TEMP_SENSOR_PIN);
  // Convert analog reading to temperature (0-1023 maps to 0-5V)
  // LM35 outputs 10mV per degree Celsius
  float tempVoltage = tempRaw * (5.0 / 1023.0);
  temperature = tempVoltage / 0.01; // 10mV per degree
  
  // Debug output
  Serial.print("Current: ");
  Serial.print(current);
  Serial.print("A, Power: ");
  Serial.print(power);
  Serial.print("W, Temp: ");
  Serial.print(temperature);
  Serial.println("°C");
}

float getVPP() {
  float result;
  int readValue;
  int maxValue = 0;
  int minValue = 1024;
  
  uint32_t start_time = millis();
  while((millis()-start_time) < 1000) //sample for 1 Sec
  {
    readValue = analogRead(CURRENT_SENSOR_PIN);
    if (readValue > maxValue) {
      maxValue = readValue;
    }
    if (readValue < minValue) {
      minValue = readValue;
    }
  }
  
  result = ((maxValue - minValue) * 5.0)/1024.0;
  return result;
}

void updateDeviceState() {
  DeviceState newState;
  
  if (power < IDLE_POWER_THRESHOLD) {
    newState = OFF;
  } else if (power < RUNNING_POWER_THRESHOLD) {
    newState = IDLE;
  } else {
    newState = RUNNING;
  }
  
  // Only update if state changed
  if (newState != currentState) {
    currentState = newState;
    // State change will be reported in sendDataToESP8266
  }
}

void checkTemperature() {
  if (temperature >= TEMP_SHUTOFF) {
    // Emergency shutoff
    setRelay(false);
    
    // Set emergency flag
    emergencyStatus = true;
    
    // Send emergency shutoff notification
    espSerial.println("EMERGENCY:TEMP_SHUTOFF");
    Serial.println("EMERGENCY: Temperature shutoff threshold reached!");
  } else if (temperature >= TEMP_WARNING) {
    // Send warning notification
    espSerial.println("WARNING:HIGH_TEMP");
    Serial.println("WARNING: High temperature detected!");
  } else if (emergencyStatus && temperature < (TEMP_WARNING - 5.0)) {
    // Reset emergency status if temperature drops below warning level minus 5°C (hysteresis)
    emergencyStatus = false;
    espSerial.println("INFO:TEMP_NORMAL");
    Serial.println("INFO: Temperature returned to normal range");
  }
}

void sendDataToESP8266() {
  // Format: "C:current,P:power,T:temperature,R:relayState,S:deviceState,E:emergencyStatus"
  espSerial.print("C:");
  espSerial.print(current);
  espSerial.print(",P:");
  espSerial.print(power);
  espSerial.print(",T:");
  espSerial.print(temperature);
  espSerial.print(",R:");
  espSerial.print(relayState);
  espSerial.print(",S:");
  espSerial.print(currentState);
  espSerial.print(",E:");
  espSerial.println(emergencyStatus ? "1" : "0");
}

void setRelay(bool state) {
  relayState = state;
  if (USE_RELAY) {
    digitalWrite(RELAY_PIN, state ? HIGH : LOW);
    Serial.print("Relay set to: ");
    Serial.println(state ? "ON" : "OFF");
  } else {
    Serial.print("Relay simulation: ");
    Serial.println(state ? "ON" : "OFF");
  }
}

void processCommand() {
  if (espSerial.available()) {
    String command = espSerial.readStringUntil('\n');
    Serial.print("Command received: ");
    Serial.println(command);
    
    if (command.startsWith("RELAY:")) {
      bool newState = command.substring(6).toInt() == 1;
      setRelay(newState);
    }
  }
} 