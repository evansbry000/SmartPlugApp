import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/smart_plug_service.dart';

class RecentEventsWidget extends StatelessWidget {
  final int maxEvents;
  final bool showTitle;

  const RecentEventsWidget({
    super.key,
    this.maxEvents = 3,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartPlugService>(
      builder: (context, service, child) {
        final events = service.recentEvents;
        
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Recent Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length > maxEvents ? maxEvents : events.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final formattedDate = DateFormat('MMM d, h:mm a').format(event.timestamp);
                  
                  // Set icon and color based on event type
                  IconData icon;
                  Color color;
                  
                  switch (event.type) {
                    case 'emergency':
                      icon = Icons.warning_amber_rounded;
                      color = Colors.red;
                      break;
                    case 'state_change':
                      icon = Icons.device_hub;
                      color = Colors.blue;
                      break;
                    case 'connection':
                      icon = event.message == 'CONNECTED' ? Icons.wifi : Icons.wifi_off;
                      color = event.message == 'CONNECTED' ? Colors.green : Colors.orange;
                      break;
                    case 'safety':
                      icon = Icons.security;
                      color = Colors.deepOrange;
                      break;
                    default:
                      icon = Icons.info_outline;
                      color = Colors.purple;
                  }
                  
                  // Format message for display
                  String displayMessage;
                  switch (event.message) {
                    case 'HIGH_TEMPERATURE':
                      displayMessage = 'High temperature detected: ${event.temperature?.toStringAsFixed(1)}°C';
                      break;
                    case 'HIGH_CURRENT':
                      displayMessage = 'High current detected';
                      break;
                    case 'AUTO_SHUTOFF_TEMPERATURE':
                      displayMessage = 'Device auto-shutoff due to high temperature';
                      break;
                    case 'AUTO_SHUTOFF_CURRENT':
                      displayMessage = 'Device auto-shutoff due to high current';
                      break;
                    case 'CONNECTED':
                      displayMessage = 'Device connected';
                      break;
                    case 'DISCONNECTED':
                      displayMessage = 'Device disconnected';
                      break;
                    default:
                      displayMessage = event.message;
                  }
                  
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(displayMessage),
                    subtitle: Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
} 