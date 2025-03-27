// Smart Plug Arduino Code
// This code runs on the Arduino board

// Pin Definitions
const int CURRENT_SENSOR_PIN = A0;  // ACS712 current sensor
const int TEMP_SENSOR_PIN = A1;     // LM35 temperature sensor
const int RELAY_PIN = 7;            // Relay control pin

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
unsigned long lastReadingTime = 0;
const unsigned long READING_INTERVAL = 30000; // 30 seconds

// Device State Enum
enum DeviceState {
  OFF,
  IDLE,
  RUNNING
};
DeviceState currentState = OFF;

void setup() {
  Serial.begin(9600);
  
  // Configure pins
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(CURRENT_SENSOR_PIN, INPUT);
  pinMode(TEMP_SENSOR_PIN, INPUT);
  
  // Initialize relay as OFF
  digitalWrite(RELAY_PIN, LOW);
  
  Serial.println("Smart Plug Initialized");
}

void loop() {
  unsigned long currentTime = millis();
  
  // Read sensors every 30 seconds
  if (currentTime - lastReadingTime >= READING_INTERVAL) {
    readSensors();
    updateDeviceState();
    checkTemperature();
    sendDataToESP32();
    lastReadingTime = currentTime;
  }
  
  // Process any incoming commands
  processCommand();
}

void readSensors() {
  // Read current sensor
  float voltage = getVPP();
  float vRMS = (voltage/2.0) * 0.707;  // root 2 is 0.707
  current = (vRMS * 1000)/MV_PER_AMP;
  
  // Calculate power (using 120V AC)
  power = current * 120.0 / 1.3;  // 1.3 is empirical calibration factor
  
  // Read temperature sensor
  int tempRaw = analogRead(TEMP_SENSOR_PIN);
  temperature = tempRaw * TEMP_SENSOR_RATIO;
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
    // State change will be reported in sendDataToESP32
  }
}

void checkTemperature() {
  if (temperature >= TEMP_SHUTOFF) {
    // Emergency shutoff
    setRelay(false);
    // Send emergency shutoff notification
    Serial.println("EMERGENCY:TEMP_SHUTOFF");
  } else if (temperature >= TEMP_WARNING) {
    // Send warning notification
    Serial.println("WARNING:HIGH_TEMP");
  }
}

void sendDataToESP32() {
  // Format: "C:current,P:power,T:temperature,R:relayState,S:deviceState"
  Serial.print("C:");
  Serial.print(current);
  Serial.print(",P:");
  Serial.print(power);
  Serial.print(",T:");
  Serial.print(temperature);
  Serial.print(",R:");
  Serial.print(relayState);
  Serial.print(",S:");
  Serial.println(currentState);
}

void setRelay(bool state) {
  relayState = state;
  digitalWrite(RELAY_PIN, state ? HIGH : LOW);
}

void processCommand() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    
    if (command.startsWith("RELAY:")) {
      bool newState = command.substring(6).toInt() == 1;
      setRelay(newState);
    }
  }
} 