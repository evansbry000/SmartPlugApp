import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/smart_plug_event.dart';

/// Service responsible for managing notifications for smart plug events and alerts.
///
/// This service handles:
/// - Setting up and configuring push notifications through Firebase Cloud Messaging
/// - Creating and managing notification channels with appropriate importance levels
/// - Processing incoming notification payloads from both foreground and background states
/// - Converting notification data into structured SmartPlugEvent objects
/// - Presenting local notifications with correct styling and priority
/// - Managing user notification preferences across categories
/// - Storing notification history for later retrieval and management
/// - Supporting notification interactions and navigation through deep links
/// - Providing test functionality to verify notification configuration
///
/// The service creates a complete notification system tailored to smart plug functionality,
/// ensuring users receive timely alerts about device status changes, energy usage
/// anomalies, and critical events requiring immediate attention.
class NotificationService {
  // Firebase instances
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Local notifications
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // State tracking
  bool _isInitialized = false;
  StreamController<SmartPlugEvent>? _notificationStreamController;
  
  // User preferences
  Map<String, bool> _notificationPreferences = {};
  
  /// Stream of notification events that can be listened to by the app.
  ///
  /// Subscribe to this stream to be notified when new notifications arrive,
  /// allowing UI components to update accordingly and navigate to relevant
  /// screens based on notification content.
  Stream<SmartPlugEvent>? get notificationStream => 
      _notificationStreamController?.stream;
  
  /// Current notification preferences for the user.
  ///
  /// A map of notification types to boolean values indicating whether
  /// notifications of that type are enabled. Used to filter notifications
  /// before they are displayed to the user.
  Map<String, bool> get notificationPreferences => _notificationPreferences;
  
  /// Initialize the notification service and request permissions.
  ///
  /// This must be called before using any other methods in the service.
  /// Sets up notification channels, requests permissions, initializes
  /// Firebase Cloud Messaging, and loads user preferences.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Create notification stream
    _notificationStreamController = StreamController<SmartPlugEvent>.broadcast();
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    // Create Android notification channel
    await _setupNotificationChannels();
    
    // Request notification permissions
    await _requestNotificationPermissions();
    
    // Set up FCM handlers
    _setupFirebaseMessaging();
    
    // Load user preferences
    await _loadNotificationPreferences();
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User signed in, register device token
        await _registerDeviceToken();
        
        // Refresh preferences
        await _loadNotificationPreferences();
        debugPrint('NotificationService: User signed in, refreshed settings');
      } else {
        // User signed out, clear preferences
        _notificationPreferences = {};
        debugPrint('NotificationService: User signed out, cleared preferences');
      }
    });
    
    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }
  
  /// Set up notification channels for Android devices.
  ///
  /// Creates channels with different importance levels for various types
  /// of notifications (alerts, events, status updates, etc.), allowing
  /// for proper categorization and user control over notification behavior.
  Future<void> _setupNotificationChannels() async {
    if (!kIsWeb) {
      // Create high priority channel for alerts
      const highImportanceChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'Smart Plug Alerts',
        description: 'Critical notifications about your smart plugs',
        importance: Importance.high,
        enableVibration: true,
      );
      
      // Create medium priority channel for events
      const mediumImportanceChannel = AndroidNotificationChannel(
        'medium_importance_channel',
        'Smart Plug Events',
        description: 'Standard notifications about your smart plugs',
        importance: Importance.defaultImportance,
      );
      
      // Create low priority channel for status updates
      const lowImportanceChannel = AndroidNotificationChannel(
        'low_importance_channel',
        'Smart Plug Updates',
        description: 'General updates about your smart plugs',
        importance: Importance.low,
      );
      
      // Register the channels
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannels([
        highImportanceChannel,
        mediumImportanceChannel,
        lowImportanceChannel,
      ]);
      
      debugPrint('NotificationService: Set up notification channels');
    }
  }
  
  /// Request notification permissions from the user.
  ///
  /// Requests permission to display alerts, play sounds, and show badges.
  /// The result indicates whether permission was granted, allowing the
  /// app to adjust its behavior accordingly.
  Future<bool> _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    final permissionGranted = 
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    
    debugPrint('NotificationService: Permission ${permissionGranted ? 'granted' : 'denied'}');
    return permissionGranted;
  }
  
  /// Set up Firebase Cloud Messaging handlers.
  ///
  /// Registers handlers for foreground, background, and terminated app states
  /// to process incoming notifications appropriately in each case. Ensures
  /// notifications are handled consistently regardless of app state.
  void _setupFirebaseMessaging() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageOpened);
    
    // Handle initial message (app opened from terminated state)
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleInitialMessage(message);
      }
    });
    
    debugPrint('NotificationService: Set up Firebase messaging handlers');
  }
  
  /// Register the device token with Firebase for the current user.
  ///
  /// Retrieves the FCM token and associates it with the user's account
  /// to enable targeted push notifications for this device. Updates
  /// the token in Firestore with platform information and timestamps.
  Future<void> _registerDeviceToken() async {
    if (_auth.currentUser == null) return;
    
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('devices_tokens')
          .doc(token)
          .set({
        'token': token,
        'platform': defaultTargetPlatform.toString(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('NotificationService: Registered device token');
    } catch (e) {
      debugPrint('NotificationService: Error registering token: $e');
    }
  }
  
  /// Load notification preferences for the current user.
  ///
  /// Retrieves user preference settings from Firestore and local storage,
  /// determining which types of notifications should be displayed. Uses
  /// a combination of local and cloud storage for reliability and performance.
  Future<void> _loadNotificationPreferences() async {
    try {
      // Default preferences (all enabled)
      _notificationPreferences = {
        'power_events': true,
        'temperature_alerts': true,
        'current_alerts': true,
        'voltage_alerts': true,
        'connection_events': true,
        'scheduled_events': true,
        'firmware_updates': true,
      };
      
      // Try to load from local storage first (for faster startup)
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString('notification_preferences');
      
      if (prefsJson != null) {
        final Map<String, dynamic> storedPrefs = 
            jsonDecode(prefsJson) as Map<String, dynamic>;
        
        storedPrefs.forEach((key, value) {
          if (value is bool && _notificationPreferences.containsKey(key)) {
            _notificationPreferences[key] = value;
          }
        });
      }
      
      // If user is signed in, load from Firestore (more authoritative)
      if (_auth.currentUser != null) {
        final doc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('settings')
            .doc('notifications')
            .get();
        
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          
          data.forEach((key, value) {
            if (value is bool && _notificationPreferences.containsKey(key)) {
              _notificationPreferences[key] = value;
            }
          });
          
          // Store updated preferences in local storage
          await prefs.setString(
            'notification_preferences', 
            jsonEncode(_notificationPreferences)
          );
        }
      }
      
      debugPrint('NotificationService: Loaded notification preferences');
    } catch (e) {
      debugPrint('NotificationService: Error loading preferences: $e');
    }
  }
  
  /// Update notification preferences for the current user.
  ///
  /// Updates both local storage and Firestore with the user's notification
  /// preference settings. This allows users to control which types of
  /// notifications they receive across all their devices.
  ///
  /// [preferences] Map containing preference keys and boolean values
  /// Returns a Future that completes when the preferences are updated
  Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
    try {
      // Update local preferences
      preferences.forEach((key, value) {
        if (_notificationPreferences.containsKey(key)) {
          _notificationPreferences[key] = value;
        }
      });
      
      // Store in local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_preferences', 
        jsonEncode(_notificationPreferences)
      );
      
      // Update in Firestore if signed in
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('settings')
            .doc('notifications')
            .set(_notificationPreferences, SetOptions(merge: true));
      }
      
      debugPrint('NotificationService: Updated notification preferences');
    } catch (e) {
      debugPrint('NotificationService: Error updating preferences: $e');
    }
  }
  
  /// Handle a foreground message from Firebase Cloud Messaging.
  ///
  /// Processes notifications received while the app is open and displays
  /// them as local notifications if appropriate based on user preferences.
  /// Also adds the event to the notification stream for in-app updates.
  ///
  /// [message] The RemoteMessage received from Firebase
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('NotificationService: Received foreground message: ${message.messageId}');
    
    try {
      // Extract notification data
      final notification = message.notification;
      final data = message.data;
      
      // Check if this is a smart plug event
      if (data.containsKey('event_type') && data.containsKey('device_id')) {
        final eventType = data['event_type'];
        
        // Check if user wants this type of notification
        if (!_shouldShowNotification(eventType)) {
          debugPrint('NotificationService: Skipping notification based on preferences');
          return;
        }
        
        // Create SmartPlugEvent
        final event = _createEventFromMessage(message);
        if (event != null) {
          // Add to stream
          _notificationStreamController?.add(event);
          
          // Show local notification
          _showLocalNotification(
            title: notification?.title ?? 'Smart Plug Alert',
            body: notification?.body ?? 'New event from your smart plug',
            payload: jsonEncode(data),
            importance: _getImportanceForEventType(eventType),
          );
          
          // Store notification in history
          _storeNotificationInHistory(event);
        }
      } else if (notification != null) {
        // Regular notification, show it
        _showLocalNotification(
          title: notification.title ?? 'Smart Plug',
          body: notification.body ?? '',
          payload: jsonEncode(data),
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error handling foreground message: $e');
    }
  }
  
  /// Handle a notification opened from the background.
  ///
  /// Processes user interaction with a notification when the app was
  /// in the background and navigates to relevant content. Parses the
  /// notification data and emits an event for navigation handling.
  ///
  /// [message] The RemoteMessage that was tapped
  void _handleBackgroundMessageOpened(RemoteMessage message) {
    debugPrint('NotificationService: Background message opened: ${message.messageId}');
    
    try {
      final data = message.data;
      
      if (data.containsKey('event_type') && data.containsKey('device_id')) {
        final event = _createEventFromMessage(message);
        if (event != null) {
          // Add to stream for navigation
          _notificationStreamController?.add(event);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error handling background message: $e');
    }
  }
  
  /// Handle a notification that opened the app from terminated state.
  ///
  /// Processes the initial notification that launched the app and
  /// navigates to the appropriate content. This ensures proper deep
  /// linking even when the app was completely closed.
  ///
  /// [message] The RemoteMessage that launched the app
  void _handleInitialMessage(RemoteMessage message) {
    debugPrint('NotificationService: Initial message: ${message.messageId}');
    
    try {
      final data = message.data;
      
      if (data.containsKey('event_type') && data.containsKey('device_id')) {
        final event = _createEventFromMessage(message);
        if (event != null) {
          // Add to stream for navigation
          _notificationStreamController?.add(event);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error handling initial message: $e');
    }
  }
  
  /// Handle a tap on a local notification.
  ///
  /// Processes user interaction with a local notification and navigates
  /// to the relevant content based on the notification payload. Parses
  /// the stored JSON payload and creates an event for navigation.
  ///
  /// [response] The notification response containing payload data
  void _handleNotificationTap(NotificationResponse response) {
    debugPrint('NotificationService: Local notification tapped: ${response.id}');
    
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        
        if (data.containsKey('event_type') && data.containsKey('device_id')) {
          final event = SmartPlugEvent(
            id: data['event_id'] ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
            deviceId: data['device_id'],
            type: data['event_type'],
            timestamp: DateTime.now(),
            value: data['value'],
            details: data['details'],
            severity: data['severity'] ?? 'info',
          );
          
          // Add to stream for navigation
          _notificationStreamController?.add(event);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error handling notification tap: $e');
    }
  }
  
  /// Show a local notification to the user.
  ///
  /// Displays a notification using the Flutter Local Notifications plugin
  /// with the appropriate channel and importance level. Configures the
  /// notification appearance differently based on platform and priority.
  ///
  /// [title] Title of the notification
  /// [body] Body text of the notification
  /// [payload] JSON payload to include with the notification
  /// [importance] Importance level for the notification channel
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    Importance importance = Importance.defaultImportance,
  }) async {
    try {
      // Determine channel based on importance
      String channelId;
      switch (importance) {
        case Importance.high:
          channelId = 'high_importance_channel';
          break;
        case Importance.low:
          channelId = 'low_importance_channel';
          break;
        default:
          channelId = 'medium_importance_channel';
          break;
      }
      
      // Build Android-specific notification
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'high_importance_channel'
            ? 'Smart Plug Alerts'
            : channelId == 'medium_importance_channel'
                ? 'Smart Plug Events'
                : 'Smart Plug Updates',
        importance: importance,
        priority: importance == Importance.high
            ? Priority.high
            : importance == Importance.low
                ? Priority.low
                : Priority.defaultPriority,
      );
      
      // Build iOS-specific notification
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      // Show notification
      await _localNotifications.show(
        DateTime.now().millisecond, // Random ID
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService: Error showing local notification: $e');
    }
  }
  
  /// Create a SmartPlugEvent from a remote message.
  ///
  /// Parses the data from a Firebase Cloud Messaging notification and
  /// constructs a structured event object for processing. Handles data
  /// format variations and provides default values when needed.
  ///
  /// [message] The RemoteMessage containing event data
  /// Returns a SmartPlugEvent if valid data was found, null otherwise
  SmartPlugEvent? _createEventFromMessage(RemoteMessage message) {
    try {
      final data = message.data;
      
      if (!data.containsKey('device_id') || !data.containsKey('event_type')) {
        return null;
      }
      
      // Parse timestamp
      DateTime timestamp;
      if (data.containsKey('timestamp') && data['timestamp'] is String) {
        timestamp = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }
      
      return SmartPlugEvent(
        id: data['event_id'] ?? 'fcm_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}',
        deviceId: data['device_id'],
        type: data['event_type'],
        timestamp: timestamp,
        value: data['value'],
        details: data['details'],
        severity: data['severity'] ?? 'info',
      );
    } catch (e) {
      debugPrint('NotificationService: Error creating event from message: $e');
      return null;
    }
  }
  
  /// Determine if a notification should be shown based on user preferences.
  ///
  /// Checks the event type against the user's notification preferences
  /// to decide whether to display the notification. This allows users
  /// to filter out notification types they don't want to see.
  ///
  /// [eventType] The type of event in the notification
  /// Returns true if the notification should be shown
  bool _shouldShowNotification(String eventType) {
    // Map event types to preference keys
    final String preferenceKey = _mapEventTypeToPreferenceKey(eventType);
    
    // Check if preference exists and is enabled
    return _notificationPreferences[preferenceKey] ?? true;
  }
  
  /// Map an event type to its corresponding preference key.
  ///
  /// Converts between the event type strings used in notifications
  /// and the preference keys used in user settings. This mapping allows
  /// for more granular categories in user preferences.
  ///
  /// [eventType] The event type from the notification
  /// Returns the corresponding preference key
  String _mapEventTypeToPreferenceKey(String eventType) {
    switch (eventType) {
      case 'power_on':
      case 'power_off':
        return 'power_events';
      case 'high_temperature':
      case 'temperature_warning':
        return 'temperature_alerts';
      case 'high_current':
      case 'current_warning':
        return 'current_alerts';
      case 'voltage_spike':
      case 'voltage_drop':
        return 'voltage_alerts';
      case 'connection_lost':
      case 'connection_restored':
        return 'connection_events';
      case 'schedule_triggered':
        return 'scheduled_events';
      case 'firmware_update':
        return 'firmware_updates';
      default:
        // For unknown types, default to showing
        return 'unknown';
    }
  }
  
  /// Get the appropriate importance level for an event type.
  ///
  /// Determines how prominently to display the notification based
  /// on the event severity and type. Critical alerts use high importance
  /// to maximize visibility, while informational updates use low importance.
  ///
  /// [eventType] The type of event in the notification
  /// Returns the importance level for the notification
  Importance _getImportanceForEventType(String eventType) {
    // Critical alerts get high importance
    if ([
      'high_temperature',
      'high_current',
      'voltage_spike',
      'voltage_drop',
      'connection_lost',
    ].contains(eventType)) {
      return Importance.high;
    }
    
    // Information updates get low importance
    if ([
      'firmware_update',
      'schedule_triggered',
    ].contains(eventType)) {
      return Importance.low;
    }
    
    // Default to medium importance
    return Importance.defaultImportance;
  }
  
  /// Store a notification in the user's history.
  ///
  /// Records notifications in Firestore for later retrieval and review
  /// in the notification history screen. This creates a persistent record
  /// of all notifications that can be accessed across devices.
  ///
  /// [event] The SmartPlugEvent to store
  Future<void> _storeNotificationInHistory(SmartPlugEvent event) async {
    if (_auth.currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notification_history')
          .doc(event.id)
          .set({
        'device_id': event.deviceId,
        'event_type': event.type,
        'timestamp': event.timestamp,
        'value': event.value,
        'details': event.details,
        'severity': event.severity,
        'read': false,
      });
    } catch (e) {
      debugPrint('NotificationService: Error storing notification in history: $e');
    }
  }
  
  /// Get the notification history for the current user.
  ///
  /// Retrieves the list of past notifications from Firestore,
  /// ordered by timestamp. Returns a stream that updates in real-time
  /// as new notifications arrive or existing ones are modified.
  ///
  /// [limit] Maximum number of notifications to retrieve (default: 50)
  /// Returns a stream of notification documents
  Stream<QuerySnapshot> getNotificationHistory({int limit = 50}) {
    if (_auth.currentUser == null) {
      return Stream.value(QuerySnapshot.withChanges(
        docChanges: [], 
        docs: [],
      ));
    }
    
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('notification_history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }
  
  /// Mark a notification as read.
  ///
  /// Updates the notification's read status in the history
  /// to track which notifications have been viewed. This allows the UI
  /// to display unread indicators and track notification status.
  ///
  /// [notificationId] ID of the notification to mark as read
  /// Returns a Future that completes when the update is finished
  Future<void> markNotificationAsRead(String notificationId) async {
    if (_auth.currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notification_history')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('NotificationService: Error marking notification as read: $e');
    }
  }
  
  /// Delete a notification from history.
  ///
  /// Removes a notification from the user's notification history.
  /// This allows users to clean up their notification list by removing
  /// individual notifications they no longer need.
  ///
  /// [notificationId] ID of the notification to delete
  /// Returns a Future that completes when the deletion is finished
  Future<void> deleteNotification(String notificationId) async {
    if (_auth.currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notification_history')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('NotificationService: Error deleting notification: $e');
    }
  }
  
  /// Clear all notifications from history.
  ///
  /// Removes all notifications from the user's notification history.
  /// This provides a way for users to reset their notification list
  /// and start fresh with an empty history.
  ///
  /// Returns a Future that completes when all notifications are deleted
  Future<void> clearAllNotifications() async {
    if (_auth.currentUser == null) return;
    
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notification_history')
          .limit(500) // Firestore batch limit
          .get();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // If we hit the batch limit, there might be more to delete
      if (snapshot.docs.length == 500) {
        await clearAllNotifications();
      }
      
      debugPrint('NotificationService: Cleared all notifications');
    } catch (e) {
      debugPrint('NotificationService: Error clearing notifications: $e');
    }
  }
  
  /// Send a test notification to the current device.
  ///
  /// Generates a test notification to verify notification settings
  /// and display are working correctly. This helps users and developers
  /// confirm that notifications are properly configured.
  ///
  /// [deviceId] Optional device ID to include in the test event
  /// Returns a Future that completes when the test notification is sent
  Future<void> sendTestNotification({String? deviceId}) async {
    try {
      final testDeviceId = deviceId ?? 'test_device';
      
      // Create test event
      final testEvent = SmartPlugEvent(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        deviceId: testDeviceId,
        type: 'test_notification',
        timestamp: DateTime.now(),
        value: null,
        details: 'This is a test notification',
        severity: 'info',
      );
      
      // Show local notification
      await _showLocalNotification(
        title: 'Smart Plug Test Notification',
        body: 'This is a test notification for your Smart Plug app',
        payload: jsonEncode({
          'event_id': testEvent.id,
          'device_id': testEvent.deviceId,
          'event_type': testEvent.type,
          'timestamp': testEvent.timestamp.toIso8601String(),
          'details': testEvent.details,
          'severity': testEvent.severity,
        }),
      );
      
      // Add to stream
      _notificationStreamController?.add(testEvent);
      
      // Store in history
      await _storeNotificationInHistory(testEvent);
      
      debugPrint('NotificationService: Sent test notification');
    } catch (e) {
      debugPrint('NotificationService: Error sending test notification: $e');
    }
  }
  
  /// Dispose of resources when the service is no longer needed.
  ///
  /// Closes the notification stream controller and cleans up resources
  /// to prevent memory leaks when the service is destroyed.
  void dispose() {
    _notificationStreamController?.close();
    _notificationStreamController = null;
    _isInitialized = false;
    debugPrint('NotificationService disposed');
  }
} 