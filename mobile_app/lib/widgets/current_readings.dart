import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class CurrentReadings extends StatelessWidget {
  const CurrentReadings({super.key});

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
                  'Current Readings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildReadingRow('Voltage', '${data.voltage.toStringAsFixed(2)} V'),
                const SizedBox(height: 8),
                _buildReadingRow('Current', '${data.current.toStringAsFixed(2)} A'),
                const SizedBox(height: 8),
                _buildReadingRow('Power', '${data.power.toStringAsFixed(2)} W'),
                const SizedBox(height: 8),
                _buildReadingRow(
                  'Last Updated',
                  _formatTimestamp(data.timestamp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
} 