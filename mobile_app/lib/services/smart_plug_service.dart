import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/smart_plug_data.dart';
import 'device_data_service.dart';
import 'event_service.dart';
import 'data_mirroring_service.dart';
import 'notification_service.dart';
import '../models/smart_plug_event.dart';

enum DeviceState {
  off,
  idle,
  running
}

class SmartPlugData {
  final double current;
  final double power;
  final double temperature;
  final bool relayState;
  final DeviceState deviceState;
  final bool emergencyStatus;
  final int uptime;
  final DateTime timestamp;

  SmartPlugData({
    required this.current,
    required this.power,
    required this.temperature,
    required this.relayState,
    required this.deviceState,
    required this.emergencyStatus,
    required this.uptime,
    required this.timestamp,
  });

  factory SmartPlugData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return SmartPlugData(
      current: (data['current'] as num).toDouble(),
      power: (data['power'] as num).toDouble(),
      temperature: (data['temperature'] as num).toDouble(),
      relayState: data['relayState'] as bool,
      deviceState: DeviceState.values[data['deviceState'] as int],
      emergencyStatus: data['emergencyStatus'] as bool? ?? false,
      uptime: data['uptime'] as int? ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  factory SmartPlugData.fromRTDB(Map<dynamic, dynamic> data) {
    return SmartPlugData(
      current: (data['current'] as num).toDouble(),
      power: (data['power'] as num).toDouble(),
      temperature: (data['temperature'] as num).toDouble(),
      relayState: data['relayState'] as bool,
      deviceState: DeviceState.values[data['deviceState'] as int],
      emergencyStatus: data['emergencyStatus'] as bool? ?? false,
      uptime: data['uptime'] as int? ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current': current,
      'power': power,
      'temperature': temperature,
      'relayState': relayState,
      'deviceState': deviceState.index,
      'emergencyStatus': emergencyStatus,
      'uptime': uptime,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class SmartPlugEvent {
  final String type;
  final String message;
  final double? temperature;
  final DateTime timestamp;

  SmartPlugEvent({
    required this.type,
    required this.message,
    this.temperature,
    required this.timestamp,
  });

  factory SmartPlugEvent.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return SmartPlugEvent(
      type: data['type'] as String,
      message: data['message'] as String,
      temperature: data['temperature'] != null ? (data['temperature'] as num).toDouble() : null,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  factory SmartPlugEvent.fromRTDB(Map<dynamic, dynamic> data) {
    return SmartPlugEvent(
      type: data['type'] as String,
      message: data['message'] as String,
      temperature: data['temperature'] != null ? (data['temperature'] as num).toDouble() : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'type': type,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
    if (temperature != null) {
      map['temperature'] = temperature;
    }
    return map;
  }
}

/// Main coordinator service for SmartPlug functionality
class SmartPlugService {
  // Service instances
  final DeviceDataService _deviceDataService = DeviceDataService();
  final EventService _eventService = EventService();
  final NotificationService _notificationService = NotificationService();
  final DataMirroringService _dataMirroringService = DataMirroringService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Authentication state 
  User? _currentUser;
  StreamSubscription? _authSubscription;
  
  // Active device tracking
  String? _activeDeviceId;
  final List<String> _monitoredDevices = [];
  
  // State tracking
  bool _isInitialized = false;

  // Stream controllers
  final _deviceListController = StreamController<List<String>>.broadcast();
  
  // Public accessors
  Stream<Map<String, SmartPlugData>> get deviceDataStream => _deviceDataService.deviceDataStream;
  Stream<Map<String, bool>> get deviceConnectionStream => _deviceDataService.deviceConnectionStream;
  Stream<List<String>> get deviceListStream => _deviceListController.stream;
  
  /// Initialize the service and all child services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize all services
      _deviceDataService.initialize();
      _eventService.initialize();
      await _notificationService.initialize();
      
      // Listen for authentication state changes
      _authSubscription = _auth.authStateChanges().listen(_handleAuthChange);
      
      // Get current user
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        await _loadUserDevices();
      }
      
      _isInitialized = true;
      debugPrint('SmartPlugService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing SmartPlugService: $e');
    }
  }

  /// Handle authentication state changes
  void _handleAuthChange(User? user) {
    _currentUser = user;
    
    if (user != null) {
      // User signed in, load devices
      _loadUserDevices();
    } else {
      // User signed out, clear devices
      _monitoredDevices.clear();
      _deviceListController.add([]);
      _activeDeviceId = null;
    }
  }
  
  /// Load user devices from Firestore
  Future<void> _loadUserDevices() async {
    final userId = _currentUser?.uid;
    if (userId == null) return;
    
    try {
      // Get devices from Firestore
      // For now, just using a stub implementation
      // In a real implementation, this would load from Firestore
      
      // Start monitoring devices
      final devices = ['device1', 'device2']; // Placeholder
      _monitoredDevices.clear();
      _monitoredDevices.addAll(devices);
      
      // Notify listeners
      _deviceListController.add(_monitoredDevices);
      
      // Start monitoring each device
      for (final deviceId in devices) {
        await startMonitoringDevice(deviceId);
      }
      
      // Set active device to first device if none is set
      if (_activeDeviceId == null && devices.isNotEmpty) {
        setActiveDevice(devices.first);
      }
    } catch (e) {
      debugPrint('Error loading user devices: $e');
    }
  }
  
  /// Start monitoring a device
  Future<void> startMonitoringDevice(String deviceId) async {
    // Start listening to device data
    await _deviceDataService.startListeningToDevice(deviceId);
    
    // Add to monitored devices if not already there
    if (!_monitoredDevices.contains(deviceId)) {
      _monitoredDevices.add(deviceId);
      _deviceListController.add(_monitoredDevices);
    }
  }
  
  /// Stop monitoring a device
  Future<void> stopMonitoringDevice(String deviceId) async {
    // TODO: Implement stopping device monitoring
    // This would require changes to DeviceDataService 
    
    // Remove from monitored devices
    _monitoredDevices.remove(deviceId);
    _deviceListController.add(_monitoredDevices);
    
    // If this was the active device, set a new active device
    if (_activeDeviceId == deviceId) {
      _activeDeviceId = _monitoredDevices.isNotEmpty ? _monitoredDevices.first : null;
    }
  }
  
  /// Set the active device
  void setActiveDevice(String deviceId) {
    if (_activeDeviceId == deviceId) return;
    
    _activeDeviceId = deviceId;
    
    // Update active device in services
    _eventService.setDeviceId(deviceId);
    _notificationService.setDeviceId(deviceId);
    
    // Start monitoring if not already
    if (!_monitoredDevices.contains(deviceId)) {
      startMonitoringDevice(deviceId);
    }
  }
  
  /// Get the active device ID
  String? get activeDeviceId => _activeDeviceId;
  
  /// Get data for a specific device
  SmartPlugData? getDeviceData(String deviceId) {
    return _deviceDataService.deviceDataCache[deviceId];
  }
  
  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _deviceDataService.deviceConnectionState[deviceId] ?? false;
  }
  
  /// Toggle the relay state for a device
  Future<bool> toggleRelay(String deviceId, bool state) async {
    return await _deviceDataService.toggleRelay(deviceId, state);
  }
  
  /// Get events for the active device
  Stream<List<SmartPlugEvent>> getEventStream(String deviceId) {
    return _eventService.getEventsStream(deviceId);
  }
  
  /// Get recent events for a device
  Future<List<SmartPlugEvent>> getRecentEvents(String deviceId, {int limit = 10}) async {
    return await _eventService.getRecentEvents(limit: limit);
  }
  
  /// Get events by type
  Future<List<SmartPlugEvent>> getEventsByType(String deviceId, String eventType) async {
    return await _eventService.getEventsByType(deviceId, eventType);
  }
  
  /// Acknowledge an event
  Future<void> acknowledgeEvent(String deviceId, String eventId) async {
    await _eventService.acknowledgeEvent(eventId);
  }
  
  /// Get historical data for a device
  Future<List<Map<String, dynamic>>> getHistoricalData(
    String deviceId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _dataMirroringService.getHistoricalData(
      startDate: startDate, 
      endDate: endDate,
    );
  }
  
  /// Update notification preferences
  Future<bool> updateNotificationPreferences({
    required bool powerAlerts,
    required bool connectionAlerts,
    required double powerThreshold,
  }) async {
    return await _notificationService.updateNotificationPreferences(
      powerAlerts: powerAlerts,
      connectionAlerts: connectionAlerts,
      powerThreshold: powerThreshold,
    );
  }
  
  /// Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    return await _notificationService.getNotificationPreferences();
  }
  
  /// Send a test notification
  Future<bool> sendTestNotification() async {
    return await _notificationService.sendTestNotification();
  }
  
  /// Get unacknowledged events count
  Future<int> getUnacknowledgedEventsCount(String deviceId) async {
    return await _eventService.getUnacknowledgedEventsCount();
  }
  
  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
    _deviceDataService.dispose();
    _eventService.dispose();
    _notificationService.dispose();
    _deviceListController.close();
  }
} 