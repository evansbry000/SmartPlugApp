Smart Plug Monitoring System with Real-time Analytics and Surge Protection

Developed a comprehensive IoT smart plug monitoring system using Flutter and Firebase, designed specifically for high-powered appliances and industrial equipment. The system features a robust circuit design with integrated surge protection, ensuring safe operation of devices drawing significant power loads.

Technical Stack:
• Frontend: Flutter (Dart) with Material Design
• Backend: Firebase (Authentication, Firestore, Hosting)
• Hardware: ESP8266 + Arduino microcontroller system
• Real-time Data: WebSocket connections for live monitoring
• State Management: Provider pattern
• Data Visualization: FL Chart for real-time graphs

Key Features:
• Real-time power consumption monitoring (current, voltage, power factor)
• Temperature monitoring with automatic safety shutoff
• Advanced MOV-based surge protection for high-powered devices
• Device state tracking (off/idle/running)
• Historical data analysis with customizable time ranges
• User authentication and secure data access
• Responsive web interface with cross-platform compatibility
• Error handling with persistent state management
• Automatic data logging and event tracking

Safety Features:
• Temperature-based safety shutoff
• MOV surge protection for high-voltage appliances (175-350 joules)
• Real-time monitoring of power consumption
• Automatic circuit protection with fast-blow fuse backup
• Event logging for safety incidents

The system is specifically designed for monitoring and controlling high-powered devices (up to 30A), with a focus on safety and reliability. The surge protection circuitry ensures safe operation even with industrial-grade equipment or sensitive appliances, while the temperature monitoring system prevents overheating and potential hazards.

Technologies used: Flutter, Firebase, ESP8266, Arduino, Dart, REST APIs, Material Design, Git 