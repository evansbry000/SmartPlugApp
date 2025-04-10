import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/smart_plug_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final service = Provider.of<SmartPlugService>(context, listen: false);
    final notifications = await service.getRecentNotifications();
    
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    final service = Provider.of<SmartPlugService>(context, listen: false);
    await service.markAllNotificationsAsRead();
    await _loadNotifications();
  }

  Future<void> _markAsRead(String notificationId) async {
    final service = Provider.of<SmartPlugService>(context, listen: false);
    await service.markNotificationAsRead(notificationId);
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications about your device here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isRead = notification['read'] as bool;
        final timestamp = notification['timestamp'] as dynamic;
        
        // Convert Firestore timestamp to DateTime
        DateTime dateTime;
        if (timestamp is DateTime) {
          dateTime = timestamp;
        } else {
          // Handle Firestore Timestamp object
          dateTime = timestamp.toDate();
        }
        
        final formattedDate = DateFormat('MMM d, h:mm a').format(dateTime);
        
        // Determine icon based on notification type
        IconData icon;
        Color iconColor;
        
        switch (notification['eventType']) {
          case 'emergency':
            icon = Icons.warning_amber_rounded;
            iconColor = Colors.red;
            break;
          case 'state_change':
            icon = Icons.device_hub;
            iconColor = Colors.blue;
            break;
          case 'connection':
            icon = Icons.wifi_off;
            iconColor = Colors.orange;
            break;
          case 'safety':
            icon = Icons.security;
            iconColor = Colors.deepOrange;
            break;
          default:
            icon = Icons.notifications;
            iconColor = Colors.purple;
        }
        
        return Dismissible(
          key: Key(notification['id']),
          background: Container(
            color: Colors.blue,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.done_all, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await _markAsRead(notification['id']);
              return false; // Don't remove the item
            }
            return true; // Allow removal for endToStart swipe
          },
          onDismissed: (direction) {
            // Delete notification logic here if needed
            setState(() {
              _notifications.removeAt(index);
            });
          },
          child: Card(
            elevation: isRead ? 1 : 3,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.2),
                child: Icon(icon, color: iconColor),
              ),
              title: Text(
                notification['title'],
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification['body']),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: isRead
                  ? null
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
              onTap: () => _markAsRead(notification['id']),
            ),
          ),
        );
      },
    );
  }
} 