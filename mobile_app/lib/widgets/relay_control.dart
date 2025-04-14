import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class RelayControl extends StatelessWidget {
  final String? deviceId;

  const RelayControl({
    super.key,
    this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartPlugService>(
      builder: (context, smartPlugService, child) {
        // If a specific device ID is provided, use that data
        // Otherwise, use the current data from the service
        final data = deviceId != null
            ? smartPlugService.getDeviceData(deviceId!)
            : smartPlugService.currentData;
        
        if (data == null) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Power Control',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${data.relayState ? 'ON' : 'OFF'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: data.relayState ? Colors.green : Colors.red,
                      ),
                    ),
                    Switch(
                      value: data.relayState,
                      onChanged: (value) {
                        // Use the specific device ID if provided, otherwise use current data's device ID
                        final targetDeviceId = deviceId ?? data.deviceId;
                        context.read<SmartPlugService>().toggleRelay(targetDeviceId);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 