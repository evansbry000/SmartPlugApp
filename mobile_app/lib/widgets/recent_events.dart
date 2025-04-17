import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class RecentEvents extends StatelessWidget {
  const RecentEvents({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Latest notifications and alerts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200, // Fixed height for event list
              child: _buildEventsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    // For now, just show dummy events
    final dummyEvents = [
      _EventItem(
        type: 'Power On',
        time: DateTime.now().subtract(const Duration(minutes: 5)),
        description: 'Device turned on',
        severity: _EventSeverity.info,
      ),
      _EventItem(
        type: 'High Power',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        description: 'Power usage above normal: 1250W',
        severity: _EventSeverity.warning,
      ),
      _EventItem(
        type: 'Connection Lost',
        time: DateTime.now().subtract(const Duration(hours: 12)),
        description: 'Device went offline for 5 minutes',
        severity: _EventSeverity.warning,
      ),
      _EventItem(
        type: 'Firmware Update',
        time: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Updated to firmware version 2.1.0',
        severity: _EventSeverity.info,
      ),
    ];
    
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      shrinkWrap: true,
      itemCount: dummyEvents.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final event = dummyEvents[index];
        return _buildEventItem(context, event);
      },
    );
  }

  Widget _buildEventItem(BuildContext context, _EventItem event) {
    IconData icon;
    Color color;
    
    switch (event.severity) {
      case _EventSeverity.info:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
      case _EventSeverity.warning:
        icon = Icons.warning_amber;
        color = Colors.orange;
        break;
      case _EventSeverity.alert:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.type,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatEventTime(event.time),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatEventTime(DateTime time) {
    // Convert to Central Time
    final centralTime = _toCentralTime(time);
    final now = _toCentralTime(DateTime.now());
    final difference = now.difference(centralTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // For older events, show the actual date
      return '${_getMonthAbbreviation(centralTime.month)} ${centralTime.day}, ${centralTime.hour.toString().padLeft(2, '0')}:${centralTime.minute.toString().padLeft(2, '0')}';
    }
  }
  
  // Convert UTC to Central Time (UTC-6, or UTC-5 during DST)
  DateTime _toCentralTime(DateTime utcTime) {
    final bool isDST = _isInDST(utcTime);
    final int offsetHours = isDST ? -5 : -6; // Central Time offset
    
    return utcTime.toUtc().add(Duration(hours: offsetHours));
  }
  
  // Simple DST check for U.S. Central Time
  // DST starts second Sunday in March, ends first Sunday in November
  bool _isInDST(DateTime dateTime) {
    final int year = dateTime.year;
    
    // Find second Sunday in March
    DateTime marchStart = DateTime.utc(year, 3, 1);
    while (marchStart.weekday != DateTime.sunday) {
      marchStart = marchStart.add(const Duration(days: 1));
    }
    marchStart = marchStart.add(const Duration(days: 7)); // Second Sunday
    
    // Find first Sunday in November
    DateTime novEnd = DateTime.utc(year, 11, 1);
    while (novEnd.weekday != DateTime.sunday) {
      novEnd = novEnd.add(const Duration(days: 1));
    }
    
    // DST is active from 2AM on second Sunday in March until 2AM on first Sunday in November
    DateTime dstStart = DateTime.utc(year, marchStart.month, marchStart.day, 2);
    DateTime dstEnd = DateTime.utc(year, novEnd.month, novEnd.day, 2);
    
    return dateTime.isAfter(dstStart) && dateTime.isBefore(dstEnd);
  }
  
  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

enum _EventSeverity {
  info,
  warning,
  alert,
}

class _EventItem {
  final String type;
  final DateTime time;
  final String description;
  final _EventSeverity severity;
  
  _EventItem({
    required this.type,
    required this.time,
    required this.description,
    required this.severity,
  });
} 