import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class ConnectionStatus extends StatelessWidget {
  final bool compact;
  
  const ConnectionStatus({
    super.key, 
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartPlugService>(
      builder: (context, service, child) {
        final isConnected = service.isDeviceConnected;
        
        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        } else {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Device Online' : 'Device Offline',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isConnected
                              ? 'Your smart plug is connected and sending data'
                              : 'Your smart plug is not sending data. Check your device\'s power and internet connection.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
} 