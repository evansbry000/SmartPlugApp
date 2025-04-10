import 'package:cloud_firestore/cloud_firestore.dart';

class SmartPlugData {
  final bool state;
  final double power;
  final double voltage;
  final double current;
  final DateTime? timestamp; // Optional, only used for historical data

  SmartPlugData({
    required this.state,
    required this.power,
    required this.voltage,
    required this.current,
    this.timestamp,
  });

  // Create from RTDB data format
  factory SmartPlugData.fromRtdb(Map<String, dynamic> data) {
    return SmartPlugData(
      state: data['state'] as bool? ?? false,
      power: _parseDouble(data['power']),
      voltage: _parseDouble(data['voltage']),
      current: _parseDouble(data['current']),
    );
  }

  // Create from Firestore data format
  factory SmartPlugData.fromFirestore(Map<String, dynamic> data) {
    return SmartPlugData(
      state: data['state'] as bool? ?? false,
      power: _parseDouble(data['power']),
      voltage: _parseDouble(data['voltage']),
      current: _parseDouble(data['current']),
      timestamp: data['timestamp'] is DateTime 
          ? data['timestamp'] as DateTime
          : null,
    );
  }

  // Convert to map for storing in Firestore/RTDB
  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'power': power,
      'voltage': voltage,
      'current': current,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  // Helper to safely parse double values from various sources
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
} 