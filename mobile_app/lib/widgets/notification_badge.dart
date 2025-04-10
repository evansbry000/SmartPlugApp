import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';
import '../screens/notifications_screen.dart';

class NotificationBadge extends StatefulWidget {
  final bool showIcon;
  
  const NotificationBadge({
    super.key,
    this.showIcon = true,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<SmartPlugService>(context, listen: false);
      final count = await service.getUnreadNotificationCount();
      
      setState(() {
        _unreadCount = count;
      });
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showIcon) {
      return IconButton(
        icon: Stack(
          children: [
            const Icon(Icons.notifications),
            if (_unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => _navigateToNotifications(context),
      );
    } else {
      // Just the badge to be used alongside other widgets
      return GestureDetector(
        onTap: () => _navigateToNotifications(context),
        child: _unreadCount > 0
          ? Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : const SizedBox.shrink(),
      );
    }
  }
}

// A simpler version for use in list tiles
class ListTileNotificationBadge extends StatelessWidget {
  final int count;
  
  const ListTileNotificationBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
} 