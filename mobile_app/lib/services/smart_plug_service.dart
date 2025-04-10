import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/smart_plug_data.dart';

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

class SmartPlugService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  SmartPlugData? _currentData;
  List<SmartPlugEvent> _recentEvents = [];
  bool _isLoading = false;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _eventsSubscription;
  Timer? _historyTimer;
  Timer? _connectionCheckTimer;
  DateTime? _lastDataTimestamp;
  bool _isDeviceConnected = true;
  
  // Constants for data management
  static const String DEVICE_ID = 'plug1';
  static const Duration HISTORY_INTERVAL = Duration(minutes: 2);
  static const Duration CONNECTION_CHECK_INTERVAL = Duration(minutes: 1);
  static const Duration STALE_DATA_THRESHOLD = Duration(minutes: 5);
  static const int HISTORY_RETENTION_DAYS = 7;
  // Thresholds for emergency conditions
  static const double HIGH_TEMPERATURE_THRESHOLD = 80.0; // Celsius
  static const double HIGH_CURRENT_THRESHOLD = 15.0; // Amperes

  SmartPlugData? get currentData => _currentData;
  List<SmartPlugEvent> get recentEvents => _recentEvents;
  bool get isLoading => _isLoading;
  bool get isDeviceConnected => _isDeviceConnected;

  SmartPlugService() {
    // Initialize after a short delay to ensure Firebase Auth is ready
    Future.delayed(Duration.zero, () {
      final user = _auth.currentUser;
      if (user != null) {
        _startListening();
      }
    });

    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _startListening();
      } else {
        _stopListening();
      }
    });
  }

  void _startListening() {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return;
    }

    print('Starting data listeners for user: ${user.uid}');
    
    // Listen to current data from RTDB
    _dataSubscription = _rtdb
        .ref('devices/$DEVICE_ID/status')
        .onValue
        .listen(
          (event) {
            if (event.snapshot.exists) {
              print('Received smart plug data update from RTDB');
              final data = Map<dynamic, dynamic>.from(
                  event.snapshot.value as Map<dynamic, dynamic>);
              
              _currentData = SmartPlugData.fromRTDB(data);
              
              // Update the last data timestamp
              _lastDataTimestamp = DateTime.now();
              
              // If the device was previously disconnected, mark it as connected and notify
              if (!_isDeviceConnected) {
                _isDeviceConnected = true;
                
                // Create a connection event
                final connectionEvent = SmartPlugEvent(
                  type: 'connection',
                  message: 'CONNECTED',
                  timestamp: DateTime.now(),
                );
                
                // Mirror the event to Firestore
                _mirrorEventToFirestore(connectionEvent);
                
                notifyListeners();
              }
              
              // Check for emergency conditions and handle them
              _handleEmergencyConditions(_currentData!);
              
              // Mirror current data to Firestore
              _mirrorCurrentDataToFirestore(_currentData!);
              
              notifyListeners();
            } else {
              print('No smart plug data found in RTDB');
            }
          },
          onError: (error) {
            print('Error listening to RTDB smart plug data: $error');
          },
        );

    // Listen to events from RTDB
    _eventsSubscription = _rtdb
        .ref('events/$DEVICE_ID')
        .onChildAdded
        .listen(
          (event) {
            print('Received new event from RTDB');
            if (event.snapshot.exists) {
              final data = Map<dynamic, dynamic>.from(
                  event.snapshot.value as Map<dynamic, dynamic>);
              
              final newEvent = SmartPlugEvent.fromRTDB(data);
              
              // Mirror event to Firestore
              _mirrorEventToFirestore(newEvent);
              
              // Update local events list
              _recentEvents.insert(0, newEvent);
              if (_recentEvents.length > 10) {
                _recentEvents = _recentEvents.sublist(0, 10);
              }
              
              notifyListeners();
            }
          },
          onError: (error) {
            print('Error listening to RTDB events: $error');
          },
        );
        
    // Start historical data timer (every 2 minutes)
    _historyTimer = Timer.periodic(HISTORY_INTERVAL, (timer) {
      if (_currentData != null) {
        _recordHistoricalData(_currentData!);
      }
      
      // Once a day, clean up old data
      final now = DateTime.now();
      if (now.hour == 0 && now.minute < 2) {
        _cleanupHistoricalData();
      }
    });
    
    // Start connection check timer (every minute)
    _connectionCheckTimer = Timer.periodic(CONNECTION_CHECK_INTERVAL, (timer) {
      _checkForStaleData();
    });
  }

  void _stopListening() {
    _dataSubscription?.cancel();
    _eventsSubscription?.cancel();
    _historyTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _currentData = null;
    _recentEvents = [];
    _isDeviceConnected = true;
    notifyListeners();
  }
  
  // Check if data is stale (no updates for 5+ minutes)
  void _checkForStaleData() {
    if (_lastDataTimestamp == null) return;
    
    final now = DateTime.now();
    final timeSinceLastUpdate = now.difference(_lastDataTimestamp!);
    
    if (timeSinceLastUpdate > STALE_DATA_THRESHOLD && _isDeviceConnected) {
      // Data is stale, device might be disconnected
      _isDeviceConnected = false;
      
      // Create a disconnection event
      final disconnectionEvent = SmartPlugEvent(
        type: 'connection',
        message: 'DISCONNECTED',
        timestamp: now,
      );
      
      // Mirror the event to Firestore
      _mirrorEventToFirestore(disconnectionEvent);
      
      notifyListeners();
      
      print('Device appears to be disconnected - no data for ${timeSinceLastUpdate.inMinutes} minutes');
    }
  }
  
  // Handle emergency conditions like high temperature or current
  void _handleEmergencyConditions(SmartPlugData data) async {
    // Check for emergency conditions
    bool isEmergency = false;
    String emergencyType = '';
    String emergencyMessage = '';
    
    // Check for high temperature
    if (data.temperature >= HIGH_TEMPERATURE_THRESHOLD) {
      isEmergency = true;
      emergencyType = 'emergency';
      emergencyMessage = 'HIGH_TEMPERATURE';
      
      // Only create a new emergency event if the current data doesn't already have emergencyStatus set
      if (!data.emergencyStatus) {
        // Create an emergency event
        final event = SmartPlugEvent(
          type: emergencyType,
          message: emergencyMessage,
          temperature: data.temperature,
          timestamp: data.timestamp,
        );
        
        // Record the event in Firestore
        await _mirrorEventToFirestore(event);
        
        // If configured, automatically turn off the device in emergency
        await _checkAndApplyAutoSafety(data);
      }
    }
    
    // Check for high current
    if (data.current >= HIGH_CURRENT_THRESHOLD) {
      isEmergency = true;
      emergencyType = 'emergency';
      emergencyMessage = 'HIGH_CURRENT';
      
      // Only create a new emergency event if the current data doesn't already have emergencyStatus set
      if (!data.emergencyStatus) {
        // Create an emergency event
        final event = SmartPlugEvent(
          type: emergencyType,
          message: emergencyMessage,
          temperature: data.temperature,
          timestamp: data.timestamp,
        );
        
        // Record the event in Firestore
        await _mirrorEventToFirestore(event);
        
        // If configured, automatically turn off the device in emergency
        await _checkAndApplyAutoSafety(data);
      }
    }
    
    // If we detected an emergency condition but the status doesn't reflect it,
    // update the emergency status in RTDB
    if (isEmergency && !data.emergencyStatus) {
      try {
        await _rtdb
            .ref('devices/$DEVICE_ID/status/emergencyStatus')
            .set(true);
      } catch (e) {
        print('Error updating emergency status in RTDB: $e');
      }
    }
    
    // If there's no emergency but status indicates one, clear it
    if (!isEmergency && data.emergencyStatus) {
      try {
        await _rtdb
            .ref('devices/$DEVICE_ID/status/emergencyStatus')
            .set(false);
      } catch (e) {
        print('Error clearing emergency status in RTDB: $e');
      }
    }
  }
  
  // Check user preferences and apply automatic safety measures if configured
  Future<void> _checkAndApplyAutoSafety(SmartPlugData data) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Get user preferences
      final prefsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc('preferences')
          .get();
          
      if (!prefsDoc.exists) return;
      
      final prefs = prefsDoc.data()!;
      
      // If temperature shutoff is enabled, turn off the relay
      if (prefs['temperatureShutoff'] == true && 
          data.temperature >= HIGH_TEMPERATURE_THRESHOLD && 
          data.relayState) {
        // Turn off the device
        await toggleRelay(false);
        
        // Record an event about automatic shutoff
        final event = SmartPlugEvent(
          type: 'safety',
          message: 'AUTO_SHUTOFF_TEMPERATURE',
          temperature: data.temperature,
          timestamp: DateTime.now(),
        );
        
        await _mirrorEventToFirestore(event);
      }
      
      // If current shutoff is enabled, turn off the relay for high current
      if (prefs['currentShutoff'] == true && 
          data.current >= HIGH_CURRENT_THRESHOLD && 
          data.relayState) {
        // Turn off the device
        await toggleRelay(false);
        
        // Record an event about automatic shutoff
        final event = SmartPlugEvent(
          type: 'safety',
          message: 'AUTO_SHUTOFF_CURRENT',
          temperature: data.temperature,
          timestamp: DateTime.now(),
        );
        
        await _mirrorEventToFirestore(event);
      }
    } catch (e) {
      print('Error in auto safety check: $e');
    }
  }
  
  // Mirror current data from RTDB to Firestore
  Future<void> _mirrorCurrentDataToFirestore(SmartPlugData data) async {
    try {
      // Create a proper Firestore-compatible map from the data
      final firestoreData = data.toMap();
      
      // Convert timestamp to Firestore timestamp if needed
      if (firestoreData['timestamp'] is DateTime) {
        firestoreData['timestamp'] = Timestamp.fromDate(firestoreData['timestamp'] as DateTime);
      } else if (firestoreData['timestamp'] is int) {
        firestoreData['timestamp'] = Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(firestoreData['timestamp'] as int));
      }
      
      await _firestore
          .collection('smart_plugs')
          .doc(DEVICE_ID)
          .set(firestoreData);
      
      print('Current data mirrored to Firestore');
    } catch (e) {
      print('Error mirroring current data to Firestore: $e');
    }
  }
  
  // Mirror event from RTDB to Firestore
  Future<void> _mirrorEventToFirestore(SmartPlugEvent event) async {
    try {
      // Create a proper Firestore-compatible map from the event
      final firestoreData = event.toMap();
      
      // Convert timestamp to Firestore timestamp if needed
      if (firestoreData['timestamp'] is DateTime) {
        firestoreData['timestamp'] = Timestamp.fromDate(firestoreData['timestamp'] as DateTime);
      } else if (firestoreData['timestamp'] is int) {
        firestoreData['timestamp'] = Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(firestoreData['timestamp'] as int));
      }
      
      // Add the event to Firestore
      final docRef = await _firestore
          .collection('smart_plugs')
          .doc(DEVICE_ID)
          .collection('events')
          .add(firestoreData);
      
      print('Event mirrored to Firestore with ID: ${docRef.id}');
      
      // Check if we need to send a notification to the user about this event
      await _checkAndSendNotification(event);
    } catch (e) {
      print('Error mirroring event to Firestore: $e');
    }
  }
  
  // Check user preferences and send notifications if configured
  Future<void> _checkAndSendNotification(SmartPlugEvent event) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      // Get user preferences
      final prefsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc('preferences')
          .get();
          
      if (!prefsDoc.exists) return;
      
      final prefs = prefsDoc.data()!;
      
      // Check if this type of event should trigger a notification
      bool shouldNotify = false;
      String notificationTitle = 'Smart Plug Alert';
      String notificationBody = 'An event occurred with your smart plug.';
      
      // Temperature warning
      if (event.type == 'emergency' && 
          event.message == 'HIGH_TEMPERATURE' && 
          prefs['temperatureWarning'] == true) {
        shouldNotify = true;
        notificationTitle = 'High Temperature Warning';
        notificationBody = 'Your device temperature has reached ${event.temperature}°C.';
      }
      
      // Device state change
      else if (event.type == 'state_change' && 
          prefs['deviceStateChange'] == true) {
        shouldNotify = true;
        notificationTitle = 'Device State Changed';
        notificationBody = 'Your device changed state: ${event.message}';
      }
      
      // Connection lost
      else if (event.type == 'connection' && 
          event.message == 'DISCONNECTED' && 
          prefs['connectionLost'] == true) {
        shouldNotify = true;
        notificationTitle = 'Device Disconnected';
        notificationBody = 'Your smart plug has disconnected from the network.';
      }
      
      // Auto shutoff
      else if (event.type == 'safety' && 
          (event.message == 'AUTO_SHUTOFF_TEMPERATURE' || 
           event.message == 'AUTO_SHUTOFF_CURRENT')) {
        shouldNotify = true;
        notificationTitle = 'Safety Shutoff Activated';
        notificationBody = event.message == 'AUTO_SHUTOFF_TEMPERATURE' 
            ? 'Your device was turned off due to high temperature.' 
            : 'Your device was turned off due to high current.';
      }
      
      // If we should send a notification, record it in Firestore
      if (shouldNotify) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
              'title': notificationTitle,
              'body': notificationBody,
              'read': false,
              'timestamp': Timestamp.now(),
              'eventType': event.type,
              'eventMessage': event.message,
            });
            
        print('Notification added to Firestore for event: ${event.type} - ${event.message}');
      }
    } catch (e) {
      print('Error checking notification preferences: $e');
    }
  }
  
  // Record historical data to Firestore
  Future<void> _recordHistoricalData(SmartPlugData data) async {
    try {
      // Create a proper Firestore-compatible map from the data
      final firestoreData = data.toMap();
      
      // Convert timestamp to Firestore timestamp if needed
      if (firestoreData['timestamp'] is DateTime) {
        firestoreData['timestamp'] = Timestamp.fromDate(firestoreData['timestamp'] as DateTime);
      } else if (firestoreData['timestamp'] is int) {
        firestoreData['timestamp'] = Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(firestoreData['timestamp'] as int));
      }
      
      // Add the historical record to Firestore
      final docRef = await _firestore
          .collection('smart_plugs')
          .doc(DEVICE_ID)
          .collection('history')
          .add(firestoreData);
      
      print('Historical data recorded to Firestore with ID: ${docRef.id}');
    } catch (e) {
      print('Error recording historical data to Firestore: $e');
    }
  }
  
  // Clean up historical data older than retention period
  Future<void> _cleanupHistoricalData() async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: HISTORY_RETENTION_DAYS));
      final timestamp = Timestamp.fromDate(cutoffDate);
      
      await _deleteQueryBatch(
        _firestore.collection('smart_plugs')
          .doc(DEVICE_ID)
          .collection('history')
          .where('timestamp', isLessThan: timestamp)
          .limit(100)
      );
    } catch (e) {
      print('Error cleaning up historical data: $e');
    }
  }
  
  // Helper method to delete documents in batches
  Future<void> _deleteQueryBatch(Query query) async {
    while (true) {
      final snapshot = await query.get();
      
      // If no documents found, we're done
      if (snapshot.docs.isEmpty) {
        break;
      }
      
      // Create a write batch
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Commit the batch
      await batch.commit();
      print('Deleted ${snapshot.docs.length} old records');
    }
  }

  Future<void> toggleRelay(bool state) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Send command to RTDB
      await _rtdb
          .ref('devices/$DEVICE_ID/commands/relay')
          .set({
            'state': state,
            'processed': false,
            'timestamp': ServerValue.timestamp,
          });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<SmartPlugData>> getHistoricalData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get historical data from Firestore
      final snapshot = await _firestore
          .collection('smart_plugs')
          .doc(DEVICE_ID)
          .collection('history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp', descending: false)
          .get();

      final data = snapshot.docs
          .map((doc) => SmartPlugData.fromFirestore(doc))
          .toList();

      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateNotificationPreferences({
    required bool temperatureWarning,
    required bool temperatureShutoff,
    required bool currentShutoff,
    required bool deviceStateChange,
    required bool connectionLost,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc('preferences')
            .set({
          'temperatureWarning': temperatureWarning,
          'temperatureShutoff': temperatureShutoff,
          'currentShutoff': currentShutoff,
          'deviceStateChange': deviceStateChange,
          'connectionLost': connectionLost,
        });
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .count()
          .get();
          
      return snapshot.count;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }
  
  // Get recent notifications
  Future<List<Map<String, dynamic>>> getRecentNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include the document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error getting recent notifications: $e');
      return [];
    }
  }
  
  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
  
  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
          
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
} 