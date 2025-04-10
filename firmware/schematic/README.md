# Smart Plug Hardware Schematic

This directory contains information about the hardware design and schematic for the Smart Plug system.

## Hardware Update

**Note: The system has been upgraded to use the Arduino R4 WiFi board** instead of the previous Arduino + ESP8266/ESP32 combination. This simplifies the design by using a single board with integrated WiFi capabilities.

## Surge Protection Circuit Design

The surge protection circuit is designed to protect high-powered appliances from voltage spikes and surges. The system uses:

### Components:
- Metal Oxide Varistors (MOVs) - Main surge suppression components
- Fast-blow fuse - For catastrophic failure protection
- Thermal fuse - For overheat protection
- X-capacitors - For filtering line-to-line noise
- Y-capacitors - For filtering line-to-ground noise
- Common mode choke - For electromagnetic interference suppression

### Design Parameters:
- Operating voltage: 120V/240V AC (configurable)
- Maximum current: 30A
- Surge energy absorption: 175-350 joules
- Response time: <25 nanoseconds
- Temperature range: -40°C to +85°C

## System Block Diagram

```
                                            ┌───────────────────┐
                                            │                   │
                                            │    High-Powered   │
                                            │                   │
      ┌────────────────────┐               │    Appliance /    │
      │                    │               │                   │
      │     Arduino R4     │               │    Device         │
      │      (WiFi)        │               │                   │
      │                    │               └────────┬──────────┘
      │                    │                        │
      │                    ├────────────┐           │
      │                    │            │           │
┌─────┴────┐    ┌──────────┴────┐    ┌──┴───────┐  │
│          │    │                │    │          │  │
│ Firebase │    │    Sensors     │    │  Relay   ├──┘
│          │    │  - Current     │    │          │
│ Cloud    │    │  - Temperature │    └──────┬───┘
│          │    │                │           │
└──────────┘    └────────────────┘    ┌──────┴───────┐
                                      │              │
                                      │  Surge       │
                                      │  Protection  │
                                      │  Circuit     │
                                      │              │
                                      └──────────────┘
```

## Arduino R4 WiFi Advantages

The Arduino R4 WiFi offers several advantages for this project:

1. **Integrated WiFi** - No need for separate WiFi module
2. **Higher Processing Power** - Improved performance for sensor data processing
3. **Simplified Wiring** - Eliminates serial communication between Arduino and ESP
4. **Enhanced Security** - Better support for modern encryption and authentication
5. **Improved Reliability** - Single-board solution reduces points of failure
6. **USB-C Connectivity** - Modern connection for programming and debugging

## Pin Configuration

- **A0**: ACS712 Current Sensor
- **A1**: LM35 Temperature Sensor  
- **D7**: Relay Control
- **LED_BUILTIN**: Status indicator

## Surge Protection Working Principle

1. **Normal Operation:**
   - MOVs have high resistance, effectively out of the circuit
   - Power flows normally to the connected appliance

2. **Surge Event:**
   - When voltage exceeds threshold (typically ~300V for 120V systems)
   - MOV resistance drops dramatically
   - Excess energy diverted to ground, protecting appliance
   - X and Y capacitors filter smaller transients

3. **Catastrophic Surge:**
   - If surge exceeds MOV capacity, fuse blows
   - Circuit disconnects completely, preventing damage
   - Thermal fuse provides backup protection if overheating occurs

## Recommended MOVs for High-Powered Applications

For appliances drawing significant power (refrigerators, AC units, heavy power tools):
- 14mm or 20mm diameter MOVs
- 275V or 300V nominal voltage rating
- 4000-6000A surge current rating
- Multiple MOVs in parallel for increased capacity

## Implementation Notes

1. Always place surge protection circuit before relay to protect electronics
2. Use proper isolation between high and low voltage sections
3. Ensure adequate heat dissipation for MOVs
4. Consider adding LED indicator for protection status
5. Design enclosure with proper clearances for high voltage
6. Use separate PCB for surge protection if possible 