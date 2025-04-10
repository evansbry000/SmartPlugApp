import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/smart_plug_data.dart';
import 'data_mirroring_service.dart';

/// Service responsible for managing real-time data from smart plug devices.
///
/// This service handles:
/// - Establishing and maintaining connections to Firebase Realtime Database
/// - Listening for real-time updates from smart plug devices
/// - Processing and normalizing raw device data
/// - Tracking device connection status and online state
/// - Providing data streams that UI components can listen to
/// - Sending control commands to devices
///
/// The service acts as the primary interface between the app and the 
/// physical smart plug devices, ensuring data consistency and reliability.
class DeviceDataService {
  // Firebase instances
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream controllers
  final StreamController<SmartPlugData> _dataStreamController = 
      StreamController<SmartPlugData>.broadcast();
  final StreamController<Map<String, bool>> _connectionStateController = 
      StreamController<Map<String, bool>>.broadcast();
  
  // Cached data
  final Map<String, SmartPlugData> _deviceDataCache = {};
  final Map<String, bool> _deviceConnectionState = {};
  final Map<String, DateTime> _lastSeenTimestamps = {};
  
  // Subscriptions
  final Map<String, StreamSubscription<DatabaseEvent>> _dataSubscriptions = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _connectionSubscriptions = {};
  
  // State
  bool _isInitialized = false;
  String? _activeDeviceId;
  
  /// Stream of real-time smart plug data that UI components can listen to.
  ///
  /// Emits SmartPlugData objects whenever new data is received from
  /// any of the devices being monitored.
  Stream<SmartPlugData> get dataStream => _dataStreamController.stream;
  
  /// Stream of device connection states.
  ///
  /// Emits a map of device IDs to boolean connection states whenever
  /// a device's connection status changes.
  Stream<Map<String, bool>> get connectionStateStream => 
      _connectionStateController.stream;
  
  /// The currently active device ID, if any.
  ///
  /// This represents the device that the user is currently interacting with
  /// or viewing in the UI.
  String? get activeDeviceId => _activeDeviceId;
  
  /// Initialize the service and establish connections.
  ///
  /// This must be called before using any other methods in the service.
  /// Sets up authentication state listeners and prepares for data monitoring.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Set up authentication state listener
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // User signed in, get their devices
        _loadUserDevices();
      } else {
        // User signed out, clean up
        _clearAllSubscriptions();
        _deviceDataCache.clear();
        _deviceConnectionState.clear();
        _lastSeenTimestamps.clear();
        _activeDeviceId = null;
      }
    });
    
    // Initialize the service
    _isInitialized = true;
    debugPrint('DeviceDataService initialized');
  }
  
  /// Load devices associated with the current user.
  ///
  /// Queries Firestore to get the list of devices owned by the user,
  /// then sets up listeners for those devices.
  Future<void> _loadUserDevices() async {
    if (_auth.currentUser == null) return;
    
    try {
      // Get user's devices from database
      final devicesRef = _database.ref('users/${_auth.currentUser!.uid}/devices');
      final devicesSnapshot = await devicesRef.get();
      
      if (devicesSnapshot.exists && devicesSnapshot.value is Map) {
        final devicesMap = Map<String, dynamic>.from(
            devicesSnapshot.value as Map);
        
        // Start monitoring each device
        for (final deviceId in devicesMap.keys) {
          startMonitoringDevice(deviceId);
        }
        
        // If we have at least one device, make it active
        if (devicesMap.isNotEmpty && _activeDeviceId == null) {
          setActiveDevice(devicesMap.keys.first);
        }
      }
    } catch (e) {
      debugPrint('DeviceDataService: Error loading user devices: $e');
    }
  }
  
  /// Start monitoring data from a specific device.
  ///
  /// Sets up listeners for both device data and connection state,
  /// ensuring that the app stays updated with the latest information.
  ///
  /// [deviceId] The ID of the device to monitor
  void startMonitoringDevice(String deviceId) {
    // Cancel existing subscriptions if any
    _dataSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions[deviceId]?.cancel();
    
    try {
      // Set up data listener
      final dataRef = _database.ref('devices/$deviceId/current_data');
      final dataSubscription = dataRef.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final dataMap = Map<String, dynamic>.from(
              event.snapshot.value as Map);
          
          // Create SmartPlugData object
          final smartPlugData = SmartPlugData.fromRealtimeDb(
            deviceId: deviceId,
            data: dataMap,
          );
          
          // Update cache
          _deviceDataCache[deviceId] = smartPlugData;
          _lastSeenTimestamps[deviceId] = DateTime.now();
          
          // Emit to stream
          _dataStreamController.add(smartPlugData);
        }
      });
      
      // Set up connection state listener
      final connectionRef = _database.ref('.info/connected');
      final deviceConnectionRef = _database.ref('devices/$deviceId/connection/last_seen');
      
      final connectionSubscription = connectionRef.onValue.listen((event) {
        final isConnected = event.snapshot.value as bool? ?? false;
        
        if (isConnected) {
          // Check last seen time for device
          deviceConnectionRef.get().then((snapshot) {
            if (snapshot.exists) {
              final lastSeen = snapshot.value as int? ?? 0;
              final now = DateTime.now().millisecondsSinceEpoch;
              
              // Device is considered online if last seen within the last minute
              final isDeviceOnline = (now - lastSeen) < 60000;
              
              // Update connection state
              _deviceConnectionState[deviceId] = isDeviceOnline;
              _connectionStateController.add(_deviceConnectionState);
            } else {
              // No last seen data, consider offline
              _deviceConnectionState[deviceId] = false;
              _connectionStateController.add(_deviceConnectionState);
            }
          });
        } else {
          // App is offline, so device must be too
          _deviceConnectionState[deviceId] = false;
          _connectionStateController.add(_deviceConnectionState);
        }
      });
      
      // Store subscriptions
      _dataSubscriptions[deviceId] = dataSubscription;
      _connectionSubscriptions[deviceId] = connectionSubscription;
      
      debugPrint('DeviceDataService: Started monitoring device $deviceId');
    } catch (e) {
      debugPrint('DeviceDataService: Error monitoring device $deviceId: $e');
    }
  }
  
  /// Stop monitoring a specific device.
  ///
  /// Cancels data and connection state subscriptions for the device,
  /// freeing up resources when the device is no longer of interest.
  ///
  /// [deviceId] The ID of the device to stop monitoring
  void stopMonitoringDevice(String deviceId) {
    // Cancel subscriptions
    _dataSubscriptions[deviceId]?.cancel();
    _dataSubscriptions.remove(deviceId);
    
    _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);
    
    // Remove from cache
    _deviceDataCache.remove(deviceId);
    _deviceConnectionState.remove(deviceId);
    
    debugPrint('DeviceDataService: Stopped monitoring device $deviceId');
  }
  
  /// Set the currently active device.
  ///
  /// Updates which device is considered "active" in the UI,
  /// typically the one the user is currently viewing or controlling.
  ///
  /// [deviceId] The ID of the device to set as active
  void setActiveDevice(String deviceId) {
    // Make sure we're monitoring this device
    if (!_dataSubscriptions.containsKey(deviceId)) {
      startMonitoringDevice(deviceId);
    }
    
    _activeDeviceId = deviceId;
    debugPrint('DeviceDataService: Active device set to $deviceId');
  }
  
  /// Get the cached data for a specific device.
  ///
  /// Retrieves the most recent data received from the device without
  /// making a new network request.
  ///
  /// [deviceId] The ID of the device to get data for
  /// Returns the device data or null if not available
  SmartPlugData? getDeviceData(String deviceId) {
    return _deviceDataCache[deviceId];
  }
  
  /// Get the cached data for the currently active device.
  ///
  /// Retrieves the most recent data received from the active device
  /// without making a new network request.
  ///
  /// Returns the device data or null if no active device
  SmartPlugData? getActiveDeviceData() {
    if (_activeDeviceId == null) return null;
    return _deviceDataCache[_activeDeviceId];
  }
  
  /// Check if a device is currently online.
  ///
  /// Determines whether a device is connected and communicating
  /// with the Firebase Realtime Database.
  ///
  /// [deviceId] The ID of the device to check
  /// Returns true if the device is online, false otherwise
  bool isDeviceOnline(String deviceId) {
    return _deviceConnectionState[deviceId] ?? false;
  }
  
  /// Toggle the relay state (on/off) for a device.
  ///
  /// Sends a command to the device to change its power state,
  /// typically turning an appliance on or off.
  ///
  /// [deviceId] The ID of the device to control
  /// [state] The desired state (true for on, false for off)
  /// Returns a Future that completes when the command is sent
  Future<void> toggleRelay(String deviceId, bool state) async {
    try {
      // Write to command node in Realtime Database
      await _database.ref('devices/$deviceId/commands/relay').set({
        'state': state,
        'timestamp': ServerValue.timestamp,
        'sender': 'app',
        'sender_id': _auth.currentUser?.uid ?? 'unknown',
      });
      
      debugPrint('DeviceDataService: Sent relay command to $deviceId: $state');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error toggling relay for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Set a timer for a device to turn on or off after a delay.
  ///
  /// Schedules a command to change the device state after a specified
  /// time period has elapsed.
  ///
  /// [deviceId] The ID of the device to control
  /// [state] The desired state (true for on, false for off)
  /// [durationMinutes] The delay in minutes before the state change
  /// Returns a Future that completes when the timer is set
  Future<void> setTimer(String deviceId, bool state, int durationMinutes) async {
    try {
      // Calculate target timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final targetTime = now + (durationMinutes * 60 * 1000);
      
      // Write to timer node in Realtime Database
      await _database.ref('devices/$deviceId/commands/timer').set({
        'state': state,
        'target_time': targetTime,
        'duration_minutes': durationMinutes,
        'created_at': ServerValue.timestamp,
        'sender': 'app',
        'sender_id': _auth.currentUser?.uid ?? 'unknown',
      });
      
      debugPrint('DeviceDataService: Set timer for $deviceId: $state in $durationMinutes minutes');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error setting timer for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Set a schedule for recurring device state changes.
  ///
  /// Creates a recurring schedule for the device to change state
  /// at specific times or days of the week.
  ///
  /// [deviceId] The ID of the device to schedule
  /// [schedule] Map containing schedule details
  /// Returns a Future that completes when the schedule is set
  Future<void> setSchedule(String deviceId, Map<String, dynamic> schedule) async {
    try {
      // Add metadata
      schedule['created_at'] = ServerValue.timestamp;
      schedule['sender'] = 'app';
      schedule['sender_id'] = _auth.currentUser?.uid ?? 'unknown';
      
      // Write to schedule node in Realtime Database
      await _database.ref('devices/$deviceId/commands/schedule').push().set(schedule);
      
      debugPrint('DeviceDataService: Set schedule for $deviceId');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error setting schedule for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Delete a schedule from a device.
  ///
  /// Removes a previously created schedule based on its ID.
  ///
  /// [deviceId] The ID of the device
  /// [scheduleId] The ID of the schedule to delete
  /// Returns a Future that completes when the schedule is deleted
  Future<void> deleteSchedule(String deviceId, String scheduleId) async {
    try {
      // Remove schedule from Realtime Database
      await _database.ref('devices/$deviceId/commands/schedule/$scheduleId').remove();
      
      debugPrint('DeviceDataService: Deleted schedule $scheduleId from $deviceId');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error deleting schedule for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Set power limits for a device.
  ///
  /// Configures safety thresholds for the device, such as maximum current
  /// or power consumption, triggering automatic shutoff if exceeded.
  ///
  /// [deviceId] The ID of the device to configure
  /// [maxCurrent] Maximum current in amps
  /// [maxPower] Maximum power in watts
  /// Returns a Future that completes when the limits are set
  Future<void> setPowerLimits(String deviceId, double maxCurrent, double maxPower) async {
    try {
      // Write to settings node in Realtime Database
      await _database.ref('devices/$deviceId/settings/power_limits').set({
        'max_current': maxCurrent,
        'max_power': maxPower,
        'updated_at': ServerValue.timestamp,
        'sender': 'app',
        'sender_id': _auth.currentUser?.uid ?? 'unknown',
      });
      
      debugPrint('DeviceDataService: Set power limits for $deviceId');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error setting power limits for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Request a firmware update for a device.
  ///
  /// Signals the device to check for and download new firmware,
  /// if available.
  ///
  /// [deviceId] The ID of the device to update
  /// Returns a Future that completes when the update request is sent
  Future<void> requestFirmwareUpdate(String deviceId) async {
    try {
      // Write to command node in Realtime Database
      await _database.ref('devices/$deviceId/commands/firmware_update').set({
        'requested_at': ServerValue.timestamp,
        'sender': 'app',
        'sender_id': _auth.currentUser?.uid ?? 'unknown',
      });
      
      debugPrint('DeviceDataService: Requested firmware update for $deviceId');
      return Future.value();
    } catch (e) {
      debugPrint('DeviceDataService: Error requesting firmware update for $deviceId: $e');
      return Future.error(e);
    }
  }
  
  /// Clear all device subscriptions.
  ///
  /// Cancels all active data and connection monitoring subscriptions,
  /// typically used when logging out or reinitializing.
  void _clearAllSubscriptions() {
    // Cancel all data subscriptions
    for (final subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    // Cancel all connection subscriptions
    for (final subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();
    
    debugPrint('DeviceDataService: Cleared all subscriptions');
  }
  
  /// Dispose of resources when the service is no longer needed.
  ///
  /// Cleans up all subscriptions and controllers to prevent memory leaks.
  void dispose() {
    // Cancel all subscriptions
    _clearAllSubscriptions();
    
    // Close controllers
    _dataStreamController.close();
    _connectionStateController.close();
    
    _isInitialized = false;
    debugPrint('DeviceDataService disposed');
  }
} 