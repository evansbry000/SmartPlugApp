import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class CurrentReadings extends StatelessWidget {
  final String? deviceId;

  const CurrentReadings({
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
                  'Current Readings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildReadingRow('Amperage', '${data.current.toStringAsFixed(2)} A'),
                const SizedBox(height: 8),
                _buildReadingRow('Power', '${data.power.toStringAsFixed(2)} W'),
                const SizedBox(height: 8),
                _buildReadingRow('Temperature', '${data.temperature.toStringAsFixed(1)}°C'),
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
    // Convert to Central Time
    final centralTime = _toCentralTime(timestamp);
    
    // Format date and time
    return '${centralTime.hour.toString().padLeft(2, '0')}:'
        '${centralTime.minute.toString().padLeft(2, '0')}:'
        '${centralTime.second.toString().padLeft(2, '0')} '
        '${_getMonthAbbreviation(centralTime.month)} ${centralTime.day}';
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