import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents real-time data from a smart plug device
class SmartPlugData {
  final String deviceId;
  final bool relayState;
  final double current;
  final double voltage;
  final double power;
  final double energyToday;
  final double energyTotal;
  final double temperature;
  final bool overTemperature;
  final bool overCurrent;
  final DateTime timestamp;
  final bool isOnline;
  final int rssi;

  SmartPlugData({
    required this.deviceId,
    required this.relayState,
    required this.current,
    required this.voltage,
    required this.power,
    required this.energyToday,
    required this.energyTotal,
    required this.temperature,
    required this.overTemperature,
    required this.overCurrent,
    required this.timestamp,
    required this.isOnline,
    this.rssi = -50,
  });

  /// Create a SmartPlugData object from RTDB data
  factory SmartPlugData.fromRTDB(Map<dynamic, dynamic> data) {
    final timestamp = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();
        
    return SmartPlugData(
      deviceId: data['deviceId']?.toString() ?? '',
      relayState: data['relay'] == true || data['relayState'] == true,
      current: _parseDouble(data['current']) ?? 0.0,
      voltage: _parseDouble(data['voltage']) ?? 0.0,
      power: _parseDouble(data['power']) ?? 0.0,
      energyToday: _parseDouble(data['energyToday']) ?? 0.0,
      energyTotal: _parseDouble(data['energyTotal']) ?? 0.0,
      temperature: _parseDouble(data['temperature']) ?? 0.0,
      overTemperature: data['overTemperature'] == true,
      overCurrent: data['overCurrent'] == true,
      timestamp: timestamp,
      isOnline: data['online'] == true || data['isOnline'] == true,
      rssi: _parseInt(data['rssi']) ?? -50,
    );
  }

  /// Create a SmartPlugData object from a Firestore document
  factory SmartPlugData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
        
    return SmartPlugData(
      deviceId: data['deviceId']?.toString() ?? doc.id,
      relayState: data['relayState'] == true,
      current: (data['current'] as num?)?.toDouble() ?? 0.0,
      voltage: (data['voltage'] as num?)?.toDouble() ?? 0.0,
      power: (data['power'] as num?)?.toDouble() ?? 0.0,
      energyToday: (data['energyToday'] as num?)?.toDouble() ?? 0.0,
      energyTotal: (data['energyTotal'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      overTemperature: data['overTemperature'] == true,
      overCurrent: data['overCurrent'] == true,
      timestamp: timestamp,
      isOnline: data['isOnline'] == true,
      rssi: (data['rssi'] as num?)?.toInt() ?? -50,
    );
  }

  /// Convert to a Map for RTDB
  Map<String, dynamic> toRTDB() {
    return {
      'deviceId': deviceId,
      'relayState': relayState,
      'current': current,
      'voltage': voltage,
      'power': power,
      'energyToday': energyToday,
      'energyTotal': energyTotal,
      'temperature': temperature,
      'overTemperature': overTemperature,
      'overCurrent': overCurrent,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'rssi': rssi,
    };
  }

  /// Convert to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'relayState': relayState,
      'current': current,
      'voltage': voltage,
      'power': power,
      'energyToday': energyToday,
      'energyTotal': energyTotal,
      'temperature': temperature,
      'overTemperature': overTemperature,
      'overCurrent': overCurrent,
      'timestamp': Timestamp.fromDate(timestamp),
      'isOnline': isOnline,
      'rssi': rssi,
    };
  }

  /// Helper method to parse doubles safely
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Helper method to parse integers safely
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Create a copy with updated fields
  SmartPlugData copyWith({
    String? deviceId,
    bool? relayState,
    double? current,
    double? voltage,
    double? power,
    double? energyToday,
    double? energyTotal,
    double? temperature,
    bool? overTemperature,
    bool? overCurrent,
    DateTime? timestamp,
    bool? isOnline,
    int? rssi,
  }) {
    return SmartPlugData(
      deviceId: deviceId ?? this.deviceId,
      relayState: relayState ?? this.relayState,
      current: current ?? this.current,
      voltage: voltage ?? this.voltage,
      power: power ?? this.power,
      energyToday: energyToday ?? this.energyToday,
      energyTotal: energyTotal ?? this.energyTotal,
      temperature: temperature ?? this.temperature,
      overTemperature: overTemperature ?? this.overTemperature,
      overCurrent: overCurrent ?? this.overCurrent,
      timestamp: timestamp ?? this.timestamp,
      isOnline: isOnline ?? this.isOnline,
      rssi: rssi ?? this.rssi,
    );
  }

  /// Create a SmartPlugData instance from Firebase Realtime Database data
  factory SmartPlugData.fromRealtimeDb(Map<dynamic, dynamic> data) {
    final Map<String, dynamic> typedData = {};
    
    // Convert dynamic keys to string keys
    data.forEach((key, value) {
      if (key is String) {
        typedData[key] = value;
      }
    });
    
    // Parse timestamp
    DateTime timestamp;
    if (typedData.containsKey('timestamp') && typedData['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(typedData['timestamp'] as int);
    } else {
      timestamp = DateTime.now();
    }
    
    return SmartPlugData(
      deviceId: typedData['deviceId']?.toString() ?? '',
      relayState: typedData['relayState'] as bool? ?? false,
      current: (typedData['current'] as num?)?.toDouble() ?? 0.0,
      voltage: (typedData['voltage'] as num?)?.toDouble() ?? 220.0,
      power: (typedData['power'] as num?)?.toDouble() ?? 0.0,
      energyToday: (typedData['energyToday'] as num?)?.toDouble() ?? 0.0,
      energyTotal: (typedData['energyTotal'] as num?)?.toDouble() ?? 0.0,
      temperature: (typedData['temperature'] as num?)?.toDouble() ?? 0.0,
      overTemperature: typedData['overTemperature'] as bool? ?? false,
      overCurrent: typedData['overCurrent'] as bool? ?? false,
      timestamp: timestamp,
      isOnline: typedData['isOnline'] as bool? ?? true,
      rssi: (typedData['rssi'] as num?)?.toInt() ?? -50,
    );
  }
}

/// Model representing a smart plug event (alert, status change, etc.)
class SmartPlugEvent {
  final String id;
  final String deviceId;
  final String eventType;
  final String description;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool acknowledged;

  SmartPlugEvent({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.description,
    required this.data,
    required this.timestamp,
    this.acknowledged = false,
  });

  /// Create a SmartPlugEvent from RTDB data
  factory SmartPlugEvent.fromRTDB(String eventId, Map<dynamic, dynamic> data) {
    final timestamp = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();
        
    return SmartPlugEvent(
      id: eventId,
      deviceId: data['deviceId']?.toString() ?? '',
      eventType: data['eventType']?.toString() ?? 'unknown',
      description: data['description']?.toString() ?? '',
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
      timestamp: timestamp,
      acknowledged: data['acknowledged'] == true,
    );
  }

  /// Create a SmartPlugEvent from a Firestore document
  factory SmartPlugEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
        
    return SmartPlugEvent(
      id: doc.id,
      deviceId: data['deviceId']?.toString() ?? '',
      eventType: data['eventType']?.toString() ?? 'unknown',
      description: data['description']?.toString() ?? '',
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
      timestamp: timestamp,
      acknowledged: data['acknowledged'] == true,
    );
  }

  /// Convert to a Map for RTDB
  Map<String, dynamic> toRTDB() {
    return {
      'deviceId': deviceId,
      'eventType': eventType,
      'description': description,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'acknowledged': acknowledged,
    };
  }

  /// Convert to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'eventType': eventType,
      'description': description,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'acknowledged': acknowledged,
    };
  }

  /// Create a copy with updated fields
  SmartPlugEvent copyWith({
    String? id,
    String? deviceId,
    String? eventType,
    String? description,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? acknowledged,
  }) {
    return SmartPlugEvent(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }
}

/// Represents user notification preferences for a smart plug
class NotificationPreferences {
  final String deviceId;
  final bool powerThresholdEnabled;
  final double powerThreshold;
  final bool connectionAlertEnabled;
  final bool relayStateChangeEnabled;

  NotificationPreferences({
    required this.deviceId,
    this.powerThresholdEnabled = false,
    this.powerThreshold = 1000.0,
    this.connectionAlertEnabled = true,
    this.relayStateChangeEnabled = false,
  });

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationPreferences(
      deviceId: data['device_id'] as String? ?? '',
      powerThresholdEnabled: data['power_threshold_enabled'] as bool? ?? false,
      powerThreshold: (data['power_threshold'] as num?)?.toDouble() ?? 1000.0,
      connectionAlertEnabled: data['connection_alert_enabled'] as bool? ?? true,
      relayStateChangeEnabled: data['relay_state_change_enabled'] as bool? ?? false,
    );
  }

  /// Convert to a map for storing in Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'device_id': deviceId,
      'power_threshold_enabled': powerThresholdEnabled,
      'power_threshold': powerThreshold,
      'connection_alert_enabled': connectionAlertEnabled,
      'relay_state_change_enabled': relayStateChangeEnabled,
    };
  }
} 