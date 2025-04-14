import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for managing user authentication and account management.
///
/// This service handles:
/// - User authentication (sign in, sign up, sign out)
/// - Authentication state management and monitoring
/// - Error handling for authentication operations
/// - User profile data initialization in Firestore
/// - Secure credential management
/// - Authentication state change notifications
///
/// The service uses Firebase Authentication for identity management and
/// integrates with Firestore to store additional user profile information
/// and initial device setup data.
class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  /// Current authenticated user, or null if not signed in.
  ///
  /// This provides access to user information like email, display name,
  /// and unique ID for use throughout the application.
  User? get user => _user;
  
  /// Indicates whether an authentication operation is in progress.
  ///
  /// Can be used to show loading indicators in the UI during
  /// authentication operations.
  bool get isLoading => _isLoading;
  
  /// Indicates whether a user is currently authenticated.
  ///
  /// A convenience getter that checks if the user object is non-null.
  bool get isAuthenticated => _user != null;
  
  /// Current authentication error message, if any.
  ///
  /// Contains user-friendly error messages from the most recent
  /// authentication operation that failed.
  String? get errorMessage => _errorMessage;

  /// Clear any existing authentication error message.
  ///
  /// Resets the error state and notifies listeners of the change.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Set an authentication error message.
  ///
  /// Updates the error state with a new message and notifies listeners.
  ///
  /// [message] The error message to set
  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Initialize the auth service and listen for authentication state changes.
  ///
  /// Sets up a listener for Firebase authentication state changes and
  /// updates the local user state accordingly.
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        _errorMessage = null; // Clear error when user logs out
      }
      notifyListeners();
      debugPrint('AuthService: Authentication state changed. User: ${user?.email ?? 'None'}');
    });
  }

  /// Initialize user data in Firestore for a new user.
  ///
  /// Creates the user document and initial smart plug data
  /// in Firestore when a new user signs up.
  ///
  /// [userId] The ID of the newly created user
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

      debugPrint('AuthService: User data initialized successfully');
    } catch (e) {
      debugPrint('AuthService: Error initializing user data: $e');
      rethrow;
    }
  }

  /// Sign in a user with email and password.
  ///
  /// Authenticates a user with Firebase using their email and password
  /// credentials. Updates the authentication state and handles errors.
  ///
  /// [email] The user's email address
  /// [password] The user's password
  /// Returns a Future that completes when the sign-in attempt is finished
  /// Throws FirebaseAuthException if authentication fails
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
      debugPrint('AuthService: User signed in successfully: $email');
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      debugPrint('AuthService: Firebase Auth Error: ${e.code} - ${e.message}');
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
      debugPrint('AuthService: General Error: $e');
      setError('An unexpected error occurred');
      rethrow;
    }
  }

  /// Create a new user account with email and password.
  ///
  /// Registers a new user with Firebase using their email and password,
  /// and initializes their user profile in Firestore. Updates the
  /// authentication state and handles errors.
  ///
  /// [email] The new user's email address
  /// [password] The new user's password
  /// Returns a Future that completes when the sign-up attempt is finished
  /// Throws FirebaseAuthException if account creation fails
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
      debugPrint('AuthService: New user registered successfully: $email');
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      debugPrint('AuthService: Firebase Auth Error: ${e.code} - ${e.message}');
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
      debugPrint('AuthService: General Error: $e');
      setError('An unexpected error occurred');
      rethrow;
    }
  }

  /// Sign out the current user.
  ///
  /// Ends the current user session and updates the authentication state.
  /// After signing out, the user will need to sign in again to access
  /// protected resources.
  ///
  /// Returns a Future that completes when the sign-out is finished
  Future<void> signOut() async {
    try {
      _isLoading = true;
      clearError();
      notifyListeners();
      
      await _auth.signOut();
      
      _isLoading = false;
      clearError();
      notifyListeners();
      debugPrint('AuthService: User signed out successfully');
    } catch (e) {
      _isLoading = false;
      setError('Error signing out');
      debugPrint('AuthService: Error signing out: $e');
      rethrow;
    }
  }

  /// Get the current authenticated user.
  ///
  /// Returns the currently authenticated user object.
  User? get currentUser => _auth.currentUser;
} 