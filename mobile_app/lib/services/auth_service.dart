import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> _initializeUserData(String userId) async {
    try {
      // Create user document
      await _firestore.collection('users').doc(userId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'email': _user?.email,
      });

      // Create initial smart plug data
      await _firestore.collection('smart_plugs').doc('plug1').set({
        'current': 0.0,
        'power': 0.0,
        'temperature': 25.0,
        'relayState': false,
        'deviceState': 0, // off
        'timestamp': FieldValue.serverTimestamp(),
        'ownerId': userId,
      });

      print('User data initialized successfully');
    } catch (e) {
      print('Error initializing user data: $e');
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Initialize user data in Firestore
      await _initializeUserData(userCredential.user!.uid);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signOut();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
} 