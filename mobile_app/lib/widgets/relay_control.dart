import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class RelayControl extends StatelessWidget {
  const RelayControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SmartPlugService>(
      builder: (context, smartPlugService, child) {
        final data = smartPlugService.currentData;
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
                        context.read<SmartPlugService>().toggleRelay(value);
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