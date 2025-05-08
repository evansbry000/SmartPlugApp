import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/smart_plug_data.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/smart_plug_event.dart';

/// Service responsible for mirroring data between Firebase Realtime Database and Firestore.
///
/// This service handles:
/// - Listening to device data from Realtime Database and mirroring to Firestore
/// - Synchronizing events from Realtime Database to Firestore
/// - Maintaining historical data records in Firestore for analytics and reporting
/// - Enforcing data retention policies through scheduled cleanup operations
/// - Ensuring data consistency between embedded devices and mobile applications
/// - Scheduling periodic full data synchronization for data integrity
///
/// The service acts as a bridge between the lightweight Realtime Database used by
/// embedded devices and the more query-capable Firestore database used by the mobile app,
/// enabling efficient data access patterns while maintaining a single source of truth.
class DataMirroringService {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Mirroring subscriptions
  final Map<String, StreamSubscription<DatabaseEvent>> _dataSubscriptions = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _eventSubscriptions = {};
  
  // State tracking
  bool _isInitialized = false;
  final Set<String> _monitoredDevices = {};
  
  // Configuration
  int _dataRetentionDays = 30; // Default retention period
  
  /// Initialize the service and set up authentication state monitoring.
  ///
  /// This method must be called before using any other methods in the service.
  /// It sets up authentication state listeners and loads service configuration.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Setup auth state monitoring
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User signed out, clean up
        _clearAllSubscriptions();
        _monitoredDevices.clear();
        debugPrint('DataMirroringService: User signed out, cleaned up resources');
      } else {
        debugPrint('DataMirroringService: User authenticated, ready to mirror data');
      }
    });
    
    // Load configuration
    await _loadConfiguration();
    
    _isInitialized = true;
    debugPrint('DataMirroringService initialized');
  }
  
  /// Load service configuration from Firestore.
  ///
  /// Retrieves settings such as data retention period from the configuration collection.
  /// Falls back to default values if configuration is not available.
  Future<void> _loadConfiguration() async {
    try {
      final configDoc = await _firestore
          .collection('configuration')
          .doc('data_mirroring')
          .get();
      
      if (configDoc.exists) {
        final data = configDoc.data();
        if (data != null && data.containsKey('retention_days')) {
          _dataRetentionDays = data['retention_days'] as int;
        }
      }
      
      debugPrint('DataMirroringService: Loaded configuration - retention: $_dataRetentionDays days');
    } catch (e) {
      debugPrint('DataMirroringService: Error loading configuration: $e');
    }
  }
  
  /// Start mirroring data for a specific device.
  ///
  /// Sets up listeners for device data and events in Realtime Database
  /// and mirrors changes to Firestore. Also initiates a cleanup of historical
  /// data according to the configured retention policy.
  ///
  /// [deviceId] The ID of the device to mirror data for
  /// Returns a Future that completes when mirroring is established
  Future<void> startMirroring(String deviceId) async {
    if (!_isInitialized) await initialize();
    if (_monitoredDevices.contains(deviceId)) return;
    
    // Verify user has access to this device
    final hasAccess = await _verifyDeviceAccess(deviceId);
    if (!hasAccess) {
      debugPrint('DataMirroringService: No access to mirror device $deviceId');
      return;
    }
    
    _monitoredDevices.add(deviceId);
    
    // Start mirroring current data
    await _subscribeToCurrentData(deviceId);
    
    // Start mirroring events
    await _subscribeToEvents(deviceId);
    
    // Run initial data cleanup
    _cleanupHistoricalData(deviceId);
    
    debugPrint('DataMirroringService: Started mirroring for device $deviceId');
  }
  
  /// Stop mirroring data for a specific device.
  ///
  /// Cancels all mirroring subscriptions for the device and removes it
  /// from the set of monitored devices.
  ///
  /// [deviceId] The ID of the device to stop mirroring for
  /// Returns a Future that completes when mirroring is stopped
  Future<void> stopMirroring(String deviceId) async {
    _monitoredDevices.remove(deviceId);
    
    // Cancel data subscription
    await _dataSubscriptions[deviceId]?.cancel();
    _dataSubscriptions.remove(deviceId);
    
    // Cancel event subscription
    await _eventSubscriptions[deviceId]?.cancel();
    _eventSubscriptions.remove(deviceId);
    
    debugPrint('DataMirroringService: Stopped mirroring for device $deviceId');
  }
  
  /// Subscribe to current device data changes from Realtime Database.
  ///
  /// Sets up a listener for changes to the device's current data
  /// and mirrors them to Firestore. Each data update triggers both
  /// an update to the current data document and recording of a
  /// historical data point.
  ///
  /// [deviceId] The ID of the device to subscribe to
  Future<void> _subscribeToCurrentData(String deviceId) async {
    // Cancel existing subscription if any
    await _dataSubscriptions[deviceId]?.cancel();
    
    // Set up subscription to current data - update path
    final dataRef = _database.ref('smart_plugs/$deviceId/status');
    
    _dataSubscriptions[deviceId] = dataRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;
      
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data == null) return;
        
        // Mirror data to Firestore
        _mirrorCurrentDataToFirestore(deviceId, data);
        
        // Record historical data
        _recordHistoricalData(deviceId, data);
        
      } catch (e) {
        debugPrint('DataMirroringService: Error processing data update: $e');
      }
    }, onError: (error) {
      debugPrint('DataMirroringService: Error subscribing to data: $error');
    });
  }
  
  /// Subscribe to device events from Realtime Database.
  ///
  /// Sets up a listener for new device events and mirrors them to Firestore.
  /// This ensures that events generated by the device are properly recorded
  /// in the Firestore database for historical tracking and user notification.
  ///
  /// [deviceId] The ID of the device to subscribe to
  Future<void> _subscribeToEvents(String deviceId) async {
    // Cancel existing subscription if any
    await _eventSubscriptions[deviceId]?.cancel();
    
    // Set up subscription to events - update path
    final eventsRef = _database.ref('smart_plugs/$deviceId/events');
    
    _eventSubscriptions[deviceId] = eventsRef.onChildAdded.listen((event) {
      if (!event.snapshot.exists) return;
      
      try {
        final eventId = event.snapshot.key ?? '';
        final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
        
        if (eventData == null || eventId.isEmpty) return;
        
        // Mirror event to Firestore
        _mirrorEventToFirestore(deviceId, eventData);
        
      } catch (e) {
        debugPrint('DataMirroringService: Error processing event: $e');
      }
    }, onError: (error) {
      debugPrint('DataMirroringService: Error subscribing to events: $error');
    });
  }
  
  /// Mirrors current device data from Realtime Database to Firestore.
  ///
  /// This method fetches the current state from RTDB and updates Firestore.
  /// It preserves fields that only exist in Firestore.
  Future<void> _mirrorCurrentDataToFirestore(String deviceId, Map<dynamic, dynamic>? data) async {
    try {
      if (data == null) {
        // If data is null (which it shouldn't be at this point), just return
        debugPrint('No current data for device $deviceId');
        return;
      }
      
      // Get the deviceData model
      final typedData = Map<String, dynamic>.from({
        'deviceId': deviceId,
        ...Map<String, dynamic>.from(data),
      });
      
      // Check timestamp type
      final String timestampType = typedData['timestampType']?.toString() ?? 'realTime';
      
      // Record first connection if needed (for device time conversion)
      if (timestampType == 'deviceTime') {
        SmartPlugData.recordDeviceFirstConnection(deviceId);
      }
      
      // Create SmartPlugData object
      final deviceData = SmartPlugData.fromRTDB(typedData);
      
      // Reference to device document in Firestore
      final deviceDoc = _firestore.collection('current_data').doc(deviceId);
      
      // Check if document exists to preserve fields that don't exist in RTDB
      final existingDoc = await deviceDoc.get();
      Map<String, dynamic> firestoreData = deviceData.toFirestore();
      
      if (existingDoc.exists) {
        final existingData = existingDoc.data() as Map<String, dynamic>?;
        if (existingData != null) {
          // Preserve fields that aren't in the RTDB data but exist in Firestore
          for (final key in existingData.keys) {
            if (!firestoreData.containsKey(key) && key != 'timestamp') {
              firestoreData[key] = existingData[key];
            }
          }
        }
      }
      
      // Set the owner ID if not already present
      if (_auth.currentUser != null && !firestoreData.containsKey('ownerId')) {
        firestoreData['ownerId'] = _auth.currentUser!.uid;
      }
      
      // Write to Firestore
      await deviceDoc.set(firestoreData, SetOptions(merge: true));
      debugPrint('Mirrored current data for device $deviceId to Firestore');
      
    } catch (e) {
      debugPrint('Error mirroring current data for device $deviceId: $e');
    }
  }
  
  /// Mirrors event data from Realtime Database to Firestore.
  ///
  /// This method processes events from RTDB and stores them in Firestore.
  /// Events are organized by device ID for easy retrieval.
  Future<void> _mirrorEventToFirestore(String deviceId, Map<dynamic, dynamic> eventData) async {
    try {
      if (_auth.currentUser == null) return;
      
      // Ensure we have a Map<String, dynamic> to work with
      final Map<String, dynamic> typedData = Map<String, dynamic>.from({
        'deviceId': deviceId,
        ...Map<String, dynamic>.from(eventData),
      });
      
      // Check timestamp type
      final String timestampType = typedData['timestampType']?.toString() ?? 'realTime';
      
      // Record first connection if needed (for device time conversion)
      if (timestampType == 'deviceTime') {
        SmartPlugData.recordDeviceFirstConnection(deviceId);
      }
      
      // Generate a unique ID for the event if not present
      final String eventId = typedData['id']?.toString() ?? 
                            '${DateTime.now().millisecondsSinceEpoch}_${deviceId}';
      
      // Process data into SmartPlugEvent model
      final event = SmartPlugEvent.fromRTDB(eventId, typedData);
      
      // Convert to Firestore format
      final firestoreData = event.toFirestore();
      
      // Add to events collection
      await _firestore
          .collection('events')
          .doc(deviceId)
          .collection('device_events')
          .add(firestoreData);
      
      // Add event to user's events collection if authenticated
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('events')
            .doc(deviceId)
            .collection('device_events')
            .add(firestoreData);
        
        // Update unacknowledged event count
        if (!event.acknowledged) {
          await _updateUnacknowledgedCount(deviceId);
        }
      }
      
      debugPrint('Mirrored event for device $deviceId to Firestore');
    } catch (e) {
      debugPrint('Error mirroring event for device $deviceId: $e');
    }
  }
  
  /// Records historical data in Firestore.
  ///
  /// This method stores time-series data in Firestore for historical analysis.
  /// It properly handles both real-time and device-time timestamp types.
  Future<void> _recordHistoricalData(String deviceId, Map<dynamic, dynamic> data) async {
    try {
      // Get the deviceData model
      final typedData = Map<String, dynamic>.from({
        'deviceId': deviceId,
        ...Map<String, dynamic>.from(data),
      });
      
      // Check timestamp type
      final String timestampType = typedData['timestampType']?.toString() ?? 'realTime';
      
      // Record first connection if needed (for device time conversion)
      if (timestampType == 'deviceTime') {
        SmartPlugData.recordDeviceFirstConnection(deviceId);
      }
      
      // Create SmartPlugData object
      final deviceData = SmartPlugData.fromRTDB(typedData);
      
      // Convert to Firestore format
      final firestoreData = deviceData.toFirestore();
      
      // Create document ID with timestamp for chronological order
      final docId = '${deviceData.timestamp.millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      
      // Store in historical data collection
      await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('historical_data')
          .doc(docId)
          .set(firestoreData);
      
      debugPrint('Recorded historical data for device $deviceId');
    } catch (e) {
      debugPrint('Error recording historical data for device $deviceId: $e');
    }
  }
  
  /// Updates the unacknowledged event count for a device.
  ///
  /// This method is called when a new unacknowledged event is added to Firestore.
  /// It updates a counter in the device document for quick access to unread events.
  Future<void> _updateUnacknowledgedCount(String deviceId) async {
    try {
      // Get current count
      final deviceDoc = _firestore.collection('devices').doc(deviceId);
      final snapshot = await deviceDoc.get();
      
      int currentCount = 0;
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('unacknowledged_events')) {
          currentCount = (data['unacknowledged_events'] as num).toInt();
        }
      }
      
      // Increment count
      await deviceDoc.set({
        'unacknowledged_events': currentCount + 1,
        'last_event_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Also update user's device document
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('devices')
            .doc(deviceId)
            .set({
          'unacknowledged_events': currentCount + 1,
          'last_event_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      debugPrint('Updated unacknowledged event count for device $deviceId');
    } catch (e) {
      debugPrint('Error updating unacknowledged event count: $e');
    }
  }
  
  /// Clean up historical data older than the retention period.
  ///
  /// Deletes old historical data records to prevent excessive storage usage.
  /// Processes deletions in batches to avoid Firestore limitations and
  /// to prevent timeouts on large datasets.
  ///
  /// [deviceId] The ID of the device to clean up data for
  Future<void> _cleanupHistoricalData(String deviceId) async {
    try {
      // Calculate cutoff date based on retention period
      final cutoffDate = DateTime.now().subtract(Duration(days: _dataRetentionDays));
      
      // Query for documents older than cutoff date
      final querySnapshot = await _firestore
          .collection('devices')
          .doc(deviceId)
          .collection('historical_data')
          .where('timestamp', isLessThan: cutoffDate)
          .limit(100) // Process in batches to avoid timeouts
          .get();
      
      // Skip if nothing to delete
      if (querySnapshot.docs.isEmpty) return;
      
      // Delete documents in batches
      final batch = _firestore.batch();
      int count = 0;
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
        count++;
      }
      
      await batch.commit();
      
      debugPrint('DataMirroringService: Deleted $count old historical records for $deviceId');
      
      // If we deleted a full batch, there might be more to clean up
      if (count == 100) {
        // Schedule another cleanup
        await Future.delayed(const Duration(seconds: 5));
        _cleanupHistoricalData(deviceId);
      }
      
    } catch (e) {
      debugPrint('DataMirroringService: Error cleaning up historical data: $e');
    }
  }
  
  /// Set the data retention period for historical data.
  ///
  /// Updates the number of days to retain historical data before cleanup.
  /// This setting is persisted to Firestore so it can be consistent
  /// across app instances and survive app restarts.
  ///
  /// [days] The number of days to retain historical data
  /// Returns a Future that completes when the setting is updated
  Future<void> setDataRetentionPeriod(int days) async {
    if (days < 1) {
      debugPrint('DataMirroringService: Invalid retention period, must be at least 1 day');
      return;
    }
    
    _dataRetentionDays = days;
    
    try {
      // Update configuration in Firestore
      await _firestore
          .collection('configuration')
          .doc('data_mirroring')
          .set({
        'retention_days': days,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('DataMirroringService: Updated retention period to $days days');
    } catch (e) {
      debugPrint('DataMirroringService: Error updating retention period: $e');
    }
  }
  
  /// Schedule a data mirroring task for a specific device.
  ///
  /// This can be used to force a full data sync at specific times.
  /// Creates a task document in Firestore that can be processed by
  /// a cloud function or background task to perform the sync.
  ///
  /// [deviceId] The ID of the device to schedule mirroring for
  /// [scheduledTime] When to perform the mirroring (default: immediate)
  /// Returns a Future that completes when the task is scheduled
  Future<void> scheduleFullSync(String deviceId, {DateTime? scheduledTime}) async {
    final syncTime = scheduledTime ?? DateTime.now();
    
    try {
      await _firestore
          .collection('tasks')
          .add({
        'type': 'full_sync',
        'device_id': deviceId,
        'scheduled_time': syncTime,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DataMirroringService: Scheduled full sync for $deviceId at $syncTime');
    } catch (e) {
      debugPrint('DataMirroringService: Error scheduling full sync: $e');
    }
  }
  
  /// Verify if the current user has access to a specific device.
  ///
  /// Checks the user's device access permissions in Firestore.
  /// Used internally to ensure that data mirroring only happens for
  /// devices the current user is authorized to access.
  ///
  /// [deviceId] The ID of the device to check access for
  /// Returns a Future that resolves to true if access is granted
  Future<bool> _verifyDeviceAccess(String deviceId) async {
    if (_auth.currentUser == null) return false;
    
    try {
      final userDeviceRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('devices')
          .doc(deviceId);
      
      final docSnapshot = await userDeviceRef.get();
      return docSnapshot.exists;
    } catch (e) {
      debugPrint('DataMirroringService: Error verifying device access: $e');
      return false;
    }
  }
  
  /// Clear all subscriptions.
  ///
  /// Cancels all data and event subscriptions to prevent memory leaks
  /// and unnecessary background processing.
  void _clearAllSubscriptions() {
    // Cancel all data subscriptions
    for (final subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    // Cancel all event subscriptions
    for (final subscription in _eventSubscriptions.values) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();
  }
  
  /// Dispose of resources when the service is no longer needed.
  ///
  /// Cleans up all subscriptions and state to prevent memory leaks
  /// and unnecessary background processing.
  void dispose() {
    _clearAllSubscriptions();
    _monitoredDevices.clear();
    _isInitialized = false;
    
    debugPrint('DataMirroringService disposed');
  }
} 