# Smart Plug App Services

This directory contains service classes that handle the core functionality of the Smart Plug application. Each service is designed with a single responsibility following the SOLID principles, and together they form a coordinated system for managing smart plug devices, data, and user interactions.

## Service Architecture

The services in this application follow a layered architecture:

1. **Authentication Layer** - Handles user identity and access
2. **Data Layer** - Manages real-time device data and historical records
3. **Event Layer** - Processes device events and alerts
4. **Notification Layer** - Manages user notifications across platforms
5. **Coordination Layer** - Orchestrates the interactions between other services

## Services Overview

### Authentication Service (`auth_service.dart`)

Manages user authentication and account-related functionality:
- User sign in, sign up, and sign out operations
- Authentication state management and monitoring
- Error handling for authentication operations
- User profile data initialization in Firestore

### Device Data Service (`device_data_service.dart`)

Manages real-time communication with smart plug devices:
- Establishing and maintaining connections to Firebase Realtime Database
- Listening for real-time updates from smart plug devices
- Processing raw device data into structured format
- Tracking device connection status
- Sending control commands to devices (toggle power, set timers, etc.)

### Event Service (`event_service.dart`)

Handles smart plug events and alerts:
- Processing and categorizing events by type and priority
- Managing event history and retrieval
- Providing queryable access to historical events
- Supporting acknowledgment of critical alerts
- Cleaning up old events based on retention policies

### Data Mirroring Service (`data_mirroring_service.dart`)

Ensures data consistency between databases:
- Mirroring data between Firebase Realtime Database and Firestore
- Maintaining historical data records for analytics
- Enforcing data retention policies
- Scheduling periodic full data synchronization
- Bridging the lightweight Realtime Database used by devices with the query-capable Firestore

### Notification Service (`notification_service.dart`)

Manages all aspects of user notifications:
- Configuring push notifications through Firebase Cloud Messaging
- Managing notification channels with appropriate importance levels
- Processing notification payloads from both foreground and background states
- Managing user notification preferences
- Storing notification history

### Smart Plug Service (`smart_plug_service.dart`)

Acts as a coordinator for all smart plug operations:
- Centralizes access to other service instances
- Coordinates activities that span multiple services
- Provides a simplified interface for UI components
- Manages service lifecycle and dependencies
- Ensures consistent state management across the application

## Usage Guidelines

1. **Service Initialization**: All services must be initialized before use, typically in the application's startup sequence.

2. **Dependency Injection**: Services are designed to be injected into UI components or other services as needed.

3. **Disposal**: Always call the `dispose()` method when a service is no longer needed to prevent memory leaks.

4. **Error Handling**: Services handle most internal errors, but consumer code should still implement appropriate error handling for service method calls.

5. **Authentication Awareness**: Most services require an authenticated user to function properly and will clean up resources when a user signs out.

## Example Service Usage

```dart
// Initialize a service
final deviceService = DeviceDataService();
await deviceService.initialize();

// Listen to a service stream
deviceService.dataStream.listen((deviceData) {
  // Update UI with new device data
});

// Call a service method
await deviceService.toggleRelay('device123', true);

// Dispose of a service when done
@override
void dispose() {
  deviceService.dispose();
  super.dispose();
}
```

## Service Extensions

When adding new functionality, consider whether it belongs in an existing service or warrants a new service. Services should maintain a single responsibility and be reasonably sized. If a service becomes too large or handles too many responsibilities, consider refactoring it into multiple focused services. 