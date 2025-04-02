# Arduino Firmware for Smart Plug

This directory contains the firmware for the Arduino that handles direct sensor readings and device control for the smart plug system.

## Hardware Connections

```
+---------+                               +-----------------+
|         |--Pin A0----> ACS712 Current   |                 |
|         |                Sensor         |    High-Power   |
|         |                               |                 |
|         |--Pin A1----> LM35 Temperature |    Device /     |
| Arduino |                Sensor         |                 |
|         |                               |    Appliance    |
|         |--Pin D7----> Relay Module --->|                 |
|         |                               |                 |
|         |           MOV Surge           |                 |
|         |---------> Protection -------->|                 |
|         |           Circuit             +-----------------+
+---------+
    |  |
    |  | Serial
    |  v
+----------+
| ESP8266  |
+----------+
```

## Surge Protection Circuit

The surge protection circuit is based on Metal Oxide Varistors (MOVs) designed to handle high-voltage spikes that can damage connected appliances. The circuit includes:

- MOV rated for appropriate surge protection (typically 120V-275V for home appliances)
- Fuse for catastrophic failure protection
- Capacitors for line filtering
- Thermal fuse for overheat protection

This protection is especially important for high-powered devices like refrigerators, air conditioners, heaters, and industrial equipment that can be sensitive to power fluctuations.

## Required Components

1. Arduino Uno/Nano
2. ACS712 Current Sensor (30A version for high-powered appliances)
3. LM35 Temperature Sensor
4. Relay Module (rated for appropriate amperage)
5. MOV-based surge protection components
6. Capacitors, resistors, and other passive components
7. Power supply
8. Terminal blocks, wiring, enclosure, etc.

## Setup Instructions

1. Wire the components according to the diagram above
2. Connect Arduino to computer via USB
3. Upload the smart_plug.ino sketch to Arduino
4. Connect the Arduino to ESP8266 using serial:
   - Arduino TX -> ESP8266 RX (D6)
   - Arduino RX -> ESP8266 TX (D7)
   - Common ground

## Calibration

The current sensor requires calibration for accurate readings:

1. Connect a known load (such as a 100W light bulb)
2. Adjust the `MV_PER_AMP` constant in the code
3. Verify readings with a multimeter

## Safety Features

- Temperature-based automatic shutoff at 45°C
- Warning at 35°C
- MOV-based surge protection for voltage spikes
- Current monitoring to detect abnormal conditions
- Emergency shutoff protocols

## Important Notes

- This system is designed for high-powered devices up to 30A (at 120V AC)
- Always ensure proper electrical safety when working with AC power
- The circuit should be properly enclosed and insulated
- Regular testing of the surge protection is recommended
- Consider adding a grounding connection for additional safety 