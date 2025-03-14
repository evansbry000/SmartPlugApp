import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SmartPlugData {
  final double voltage;
  final double current;
  final double power;
  final bool relayState;
  final DateTime timestamp;

  SmartPlugData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.relayState,
    required this.timestamp,
  });

  factory SmartPlugData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return SmartPlugData(
      voltage: (data['voltage'] as num).toDouble(),
      current: (data['current'] as num).toDouble(),
      power: (data['power'] as num).toDouble(),
      relayState: data['relayState'] as bool,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class SmartPlugService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  SmartPlugData? _currentData;
  bool _isLoading = false;
  StreamSubscription? _dataSubscription;

  SmartPlugData? get currentData => _currentData;
  bool get isLoading => _isLoading;

  SmartPlugService() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _startListening();
      } else {
        _stopListening();
      }
    });
  }

  void _startListening() {
    _dataSubscription = _firestore
        .collection('smart_plugs')
        .doc('plug1')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _currentData = SmartPlugData.fromFirestore(snapshot);
        notifyListeners();
      }
    });
  }

  void _stopListening() {
    _dataSubscription?.cancel();
    _currentData = null;
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

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
} 