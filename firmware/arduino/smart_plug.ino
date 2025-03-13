// Smart Plug Arduino Code
// This code runs on the Elegoo Uno R3 board

// Pin Definitions
const int VOLTAGE_SENSOR_PIN = A0;  // Analog pin for voltage sensor
const int CURRENT_SENSOR_PIN = A1;  // Analog pin for current sensor
const int RELAY_PIN = 7;            // Digital pin for relay control

// Sensor Calibration
const float VOLTAGE_SENSOR_RATIO = 0.00489;  // 5V / 1023 (ADC resolution)
const float CURRENT_SENSOR_RATIO = 0.185;    // 30A / 1023 (ADC resolution)

// Variables
float voltage = 0.0;
float current = 0.0;
float power = 0.0;
bool relayState = false;

void setup() {
  // Initialize serial communication
  Serial.begin(9600);
  
  // Configure pins
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // Initialize relay as OFF
  
  // Initialize sensors
  pinMode(VOLTAGE_SENSOR_PIN, INPUT);
  pinMode(CURRENT_SENSOR_PIN, INPUT);
}

void loop() {
  // Read sensor values
  readSensors();
  
  // Calculate power
  power = voltage * current;
  
  // Send data to ESP32
  sendDataToESP32();
  
  // Small delay to prevent overwhelming the serial communication
  delay(1000);
}

void readSensors() {
  // Read voltage sensor
  int voltageRaw = analogRead(VOLTAGE_SENSOR_PIN);
  voltage = voltageRaw * VOLTAGE_SENSOR_RATIO;
  
  // Read current sensor
  int currentRaw = analogRead(CURRENT_SENSOR_PIN);
  current = currentRaw * CURRENT_SENSOR_RATIO;
}

void sendDataToESP32() {
  // Format: "V:voltage,C:current,P:power,R:relayState"
  Serial.print("V:");
  Serial.print(voltage);
  Serial.print(",C:");
  Serial.print(current);
  Serial.print(",P:");
  Serial.print(power);
  Serial.print(",R:");
  Serial.println(relayState);
}

// Function to control relay
void setRelay(bool state) {
  relayState = state;
  digitalWrite(RELAY_PIN, state ? HIGH : LOW);
}

// Function to process commands from ESP32
void processCommand() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    
    // Process relay control command
    if (command.startsWith("RELAY:")) {
      bool newState = command.substring(6).toInt() == 1;
      setRelay(newState);
    }
  }
} 