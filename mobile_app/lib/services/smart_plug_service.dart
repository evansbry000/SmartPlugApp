import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
  final DateTime timestamp;

  SmartPlugData({
    required this.current,
    required this.power,
    required this.temperature,
    required this.relayState,
    required this.deviceState,
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
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
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
}

class SmartPlugService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  SmartPlugData? _currentData;
  List<SmartPlugEvent> _recentEvents = [];
  bool _isLoading = false;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _eventsSubscription;

  SmartPlugData? get currentData => _currentData;
  List<SmartPlugEvent> get recentEvents => _recentEvents;
  bool get isLoading => _isLoading;

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
    
    // Listen to current data
    _dataSubscription = _firestore
        .collection('smart_plugs')
        .doc('plug1')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              print('Received smart plug data update');
              _currentData = SmartPlugData.fromFirestore(snapshot);
              notifyListeners();
            } else {
              print('No smart plug data found');
            }
          },
          onError: (error) {
            print('Error listening to smart plug data: $error');
          },
        );

    // Listen to recent events
    _eventsSubscription = _firestore
        .collection('smart_plugs')
        .doc('plug1')
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) {
            print('Received events update');
            _recentEvents = snapshot.docs
                .map((doc) => SmartPlugEvent.fromFirestore(doc))
                .toList();
            notifyListeners();
          },
          onError: (error) {
            print('Error listening to events: $error');
          },
        );
  }

  void _stopListening() {
    _dataSubscription?.cancel();
    _eventsSubscription?.cancel();
    _currentData = null;
    _recentEvents = [];
    notifyListeners();
  }

  Future<void> toggleRelay(bool state) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('smart_plugs')
          .doc('plug1')
          .collection('commands')
          .doc('relay')
          .set({'state': state});

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

      final snapshot = await _firestore
          .collection('smart_plugs')
          .doc('plug1')
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

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
} 