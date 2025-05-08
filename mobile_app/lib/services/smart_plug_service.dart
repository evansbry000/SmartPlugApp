import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/smart_plug_data.dart';
import 'data_mirroring_service.dart';

/// Service that manages smart plug devices and their data.
/// Uses DataMirroringService to maintain consistency between RTDB and Firestore.
class SmartPlugService extends ChangeNotifier {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: 'https://smartplugdatabase-f1fd4-default-rtdb.firebaseio.com',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Data mirroring service
  final DataMirroringService? _mirroringService;
  
  // Dependencies
  final AuthService authService;
  
  // Data state
  bool _isLoading = true;
  final Map<String, SmartPlugData> _deviceDataCache = {};
  final Map<String, bool> _deviceConnectionState = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _dataSubscriptions = {};
  final List<String> _devices = [];
  
  // Streams
  final _deviceDataStreamController = StreamController<Map<String, SmartPlugData>>.broadcast();
  final _deviceConnectionStreamController = StreamController<Map<String, bool>>.broadcast();
  
  // Getters
  bool get isLoading => _isLoading;
  Map<String, SmartPlugData> get deviceDataCache => Map.unmodifiable(_deviceDataCache);
  Map<String, bool> get deviceConnectionState => Map.unmodifiable(_deviceConnectionState);
  Stream<Map<String, SmartPlugData>> get deviceDataStream => _deviceDataStreamController.stream;
  Stream<Map<String, bool>> get deviceConnectionStream => _deviceConnectionStreamController.stream;
  SmartPlugData? get currentData => _deviceDataCache.isNotEmpty ? _deviceDataCache.values.first : null;
  List<String> get devices => List.unmodifiable(_devices);
  
  SmartPlugService({required this.authService, DataMirroringService? mirroringService}) : 
    _mirroringService = mirroringService {
    initialize();
  }
  
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Initialize the mirroring service
      await _mirroringService?.initialize();
      
      // Listen for auth state changes
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          _loadUserDevices();
        } else {
          _clearAllSubscriptions();
          _deviceDataCache.clear();
          _deviceConnectionState.clear();
          _devices.clear();
          notifyListeners();
        }
      });
      
      // If user is already signed in, load devices
      if (_auth.currentUser != null) {
        await _loadUserDevices();
      }
    } catch (e) {
      debugPrint('SmartPlugService: Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _loadUserDevices() async {
    if (_auth.currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Get user's devices from Firestore
      final devicesSnapshot = await _firestore
          .collection('smart_plugs')
          .where('ownerId', isEqualTo: _auth.currentUser!.uid)
          .get();
      
      // Clear existing devices
      _devices.clear();
      
      // Start listening to each device
      for (final doc in devicesSnapshot.docs) {
        final deviceId = doc.id;
        _devices.add(deviceId);
        await startListeningToDevice(deviceId);
        
        // Start mirroring for this device
        await _mirroringService?.startMirroring(deviceId);
      }
      
      // If no devices found, at least try to listen to "plug1" for testing
      if (devicesSnapshot.docs.isEmpty) {
        _devices.add('plug1');
        await startListeningToDevice('plug1');
        
        // Start mirroring for default device
        await _mirroringService?.startMirroring('plug1');
      }
      
      // Sort devices alphabetically
      _devices.sort();
      notifyListeners();
    } catch (e) {
      debugPrint('SmartPlugService: Error loading devices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> startListeningToDevice(String deviceId) async {
    // Cancel existing subscription if any
    await _dataSubscriptions[deviceId]?.cancel();
    
    // Set up subscription to current data
    final dataRef = _database.ref('smart_plugs/$deviceId/status');
    
    _dataSubscriptions[deviceId] = dataRef.onValue.listen((event) {
      if (!event.snapshot.exists) {
        _deviceConnectionState[deviceId] = false;
        _deviceConnectionStreamController.add(_deviceConnectionState);
        return;
      }
      
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data == null) {
          _deviceConnectionState[deviceId] = false;
          _deviceConnectionStreamController.add(_deviceConnectionState);
          return;
        }
        
        // Mark device as connected
        _deviceConnectionState[deviceId] = true;
        _deviceConnectionStreamController.add(_deviceConnectionState);
        
        // Parse data
        final smartPlugData = SmartPlugData.fromRealtimeDb(deviceId: deviceId, data: data);
        
        // Update cache
        _deviceDataCache[deviceId] = smartPlugData;
        _deviceDataStreamController.add(_deviceDataCache);
        
        // Start mirroring the data if the service is available
        if (_mirroringService != null) {
          _mirroringService!.startMirroring(deviceId);
        }
        
        // Notify listeners
        notifyListeners();
        
      } catch (e) {
        debugPrint('SmartPlugService: Error processing data update: $e');
      }
    }, onError: (error) {
      debugPrint('SmartPlugService: Error subscribing to data: $error');
      _deviceConnectionState[deviceId] = false;
      _deviceConnectionStreamController.add(_deviceConnectionState);
    });
  }
  
  // Get specific device data
  SmartPlugData? getDeviceData(String deviceId) {
    return _deviceDataCache[deviceId];
  }

  // Check if device is online
  bool isDeviceOnline(String deviceId) {
    return _deviceConnectionState[deviceId] ?? false;
  }
  
  // Toggle relay for a device
  Future<bool> toggleRelay(String deviceId) async {
    debugPrint('SmartPlugService: toggleRelay called for device $deviceId');
    
    if (_auth.currentUser == null) {
      debugPrint('SmartPlugService: Cannot toggle relay - User not authenticated');
      return false;
    }
    
    // Get current state to toggle
    final currentState = _deviceDataCache[deviceId]?.relayState ?? false;
    final newState = !currentState;
    debugPrint('SmartPlugService: Toggling relay from $currentState to $newState');
    
    try {
      final commandRef = _database.ref('smart_plugs/$deviceId/commands/relay');
      debugPrint('SmartPlugService: Writing to path: ${commandRef.path}');
      
      // Try direct update (simpler and faster)
      try {
        await commandRef.set({
          'state': newState,
          'processed': false,
          'timestamp': ServerValue.timestamp,
        });
        
        debugPrint('SmartPlugService: Relay command successfully written to Firebase');
        return true;
      } catch (e) {
        // If direct update fails, try a different approach
        debugPrint('SmartPlugService: Direct update failed: $e');
        
        // Try to update specific fields
        try {
          await commandRef.update({
            'state': newState,
            'processed': false,
            'timestamp': ServerValue.timestamp,
          });
          
          debugPrint('SmartPlugService: Relay command successfully updated with update() method');
          return true;
        } catch (updateError) {
          debugPrint('SmartPlugService: Update also failed: $updateError');
          return false;
        }
      }
    } catch (e) {
      debugPrint('SmartPlugService: Error toggling relay: $e');
      return false;
    }
  }
  
  void _clearAllSubscriptions() {
    // Cancel all data subscriptions
    for (final subscription in _dataSubscriptions.values) {
      subscription.cancel();
    }
    _dataSubscriptions.clear();
    
    // Stop mirroring for all devices
    for (final deviceId in _devices) {
      _mirroringService?.stopMirroring(deviceId);
    }
  }
  
  @override
  void dispose() {
    _clearAllSubscriptions();
    _deviceDataStreamController.close();
    _deviceConnectionStreamController.close();
    super.dispose();
  }

  // Add this method to test Firebase connectivity
  Future<bool> testDatabaseConnection() async {
    debugPrint('SmartPlugService: Testing Firebase RTDB connection...');
    
    if (_auth.currentUser == null) {
      debugPrint('SmartPlugService: Cannot test - User not authenticated');
      return false;
    }
    
    try {
      // Try writing to a test path
      final testRef = _database.ref('connection_test/${_auth.currentUser!.uid}');
      
      await testRef.set({
        'timestamp': ServerValue.timestamp,
        'device': 'app',
        'test': true
      });
      
      // Try reading it back
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('SmartPlugService: Database connection test successful!');
        return true;
      } else {
        debugPrint('SmartPlugService: Database write succeeded but read failed');
        return false;
      }
    } catch (e) {
      debugPrint('SmartPlugService: Database connection test failed: $e');
      return false;
    }
  }
} 