import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  SharedPreferences? _prefs;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _initPrefs();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        clearError(); // Clear error when user logs out
      }
      notifyListeners();
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _errorMessage = _prefs?.getString('auth_error');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _prefs?.remove('auth_error');
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _prefs?.setString('auth_error', message);
    notifyListeners();
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
      clearError();
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _isLoading = false;
      clearError();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-login-credentials':
          errorMessage = 'Incorrect login information';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }
      setError(errorMessage);
      throw e;
    } catch (e) {
      _isLoading = false;
      print('General Error: $e');
      setError('An unexpected error occurred');
      rethrow;
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      _isLoading = true;
      clearError();
      notifyListeners();
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Initialize user data in Firestore
      await _initializeUserData(userCredential.user!.uid);
      
      _isLoading = false;
      clearError();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }
      setError(errorMessage);
      throw e;
    } catch (e) {
      _isLoading = false;
      print('General Error: $e');
      setError('An unexpected error occurred');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      clearError();
      notifyListeners();
      
      await _auth.signOut();
      
      _isLoading = false;
      clearError();
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      setError('Error signing out');
      rethrow;
    }
  }
} 