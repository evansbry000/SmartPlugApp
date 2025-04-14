import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an event or alert from a smart plug device
class SmartPlugEvent {
  /// Unique identifier for the event
  final String id;
  
  /// ID of the device that generated the event
  final String deviceId;
  
  /// Type of event (e.g., 'power_on', 'high_temperature', etc.)
  final String type;
  
  /// Timestamp when the event occurred
  final DateTime timestamp;
  
  /// Value associated with the event (e.g., temperature reading)
  final dynamic value;
  
  /// Additional details or message for the event
  final String? details;
  
  /// Severity level (e.g., 'info', 'warning', 'alert')
  final String severity;
  
  /// Whether the event has been acknowledged by the user
  final bool acknowledged;
  
  /// Timestamp when the event was acknowledged (if applicable)
  final int? acknowledgedAt;
  
  /// User ID who acknowledged the event (if applicable)
  final String? acknowledgedBy;

  SmartPlugEvent({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.timestamp,
    this.value,
    this.details,
    this.severity = 'info',
    this.acknowledged = false,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  /// Create a SmartPlugEvent from a Firestore document
  factory SmartPlugEvent.fromFirestore({
    required String deviceId,
    required String eventId,
    required Map<String, dynamic> data,
  }) {
    // Handle Firestore timestamp conversion
    DateTime timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is DateTime) {
      timestamp = data['timestamp'] as DateTime;
    } else if (data['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    } else {
      timestamp = DateTime.now();
    }

    // Parse acknowledged timestamp if present
    int? acknowledgedAt;
    if (data['acknowledged_at'] is Timestamp) {
      acknowledgedAt = (data['acknowledged_at'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['acknowledged_at'] is int) {
      acknowledgedAt = data['acknowledged_at'] as int;
    }
    
    return SmartPlugEvent(
      id: eventId,
      deviceId: deviceId,
      type: data['type'] ?? 'unknown',
      timestamp: timestamp,
      value: data['value'],
      details: data['details'],
      severity: data['severity'] ?? 'info',
      acknowledged: data['acknowledged'] ?? false,
      acknowledgedAt: acknowledgedAt,
      acknowledgedBy: data['acknowledged_by'],
    );
  }
  
  /// Create a SmartPlugEvent from a Firestore document
  factory SmartPlugEvent.fromFirestore2(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Handle Firestore timestamp conversion
    DateTime timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is DateTime) {
      timestamp = data['timestamp'] as DateTime;
    } else if (data['timestamp'] is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
    } else {
      timestamp = DateTime.now();
    }

    // Parse acknowledged timestamp if present
    int? acknowledgedAt;
    if (data['acknowledged_at'] is Timestamp) {
      acknowledgedAt = (data['acknowledged_at'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['acknowledged_at'] is int) {
      acknowledgedAt = data['acknowledged_at'] as int;
    }
    
    return SmartPlugEvent(
      id: doc.id,
      deviceId: data['device_id'] ?? '',
      type: data['type'] ?? 'unknown',
      timestamp: timestamp,
      value: data['value'],
      details: data['details'],
      severity: data['severity'] ?? 'info',
      acknowledged: data['acknowledged'] ?? false,
      acknowledgedAt: acknowledgedAt,
      acknowledgedBy: data['acknowledged_by'],
    );
  }

  /// Convert to a map for Firestore storage
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'type': type,
      'timestamp': timestamp,
      'value': value,
      'severity': severity,
      'acknowledged': acknowledged,
    };
    
    if (details != null) {
      map['details'] = details;
    }
    
    if (acknowledgedAt != null) {
      map['acknowledged_at'] = acknowledgedAt;
    }
    
    if (acknowledgedBy != null) {
      map['acknowledged_by'] = acknowledgedBy;
    }
    
    return map;
  }
  
  @override
  String toString() {
    return 'SmartPlugEvent{id: $id, deviceId: $deviceId, type: $type, timestamp: $timestamp, severity: $severity}';
  }
} 