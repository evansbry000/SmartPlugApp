import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';
import '../models/smart_plug_data.dart';
import '../widgets/current_readings.dart';
import '../widgets/power_usage_chart.dart';
import '../widgets/relay_control.dart';
import '../widgets/recent_events.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
    
    // Make sure the service is listening to this device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<SmartPlugService>(context, listen: false);
      service.startListeningToDevice(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Device ${widget.deviceId.toUpperCase()}'),
      ),
      body: SingleChildScrollView(
        child: Consumer<SmartPlugService>(
          builder: (context, service, child) {
            final deviceData = service.getDeviceData(widget.deviceId);
            final isOnline = service.isDeviceOnline(widget.deviceId);
            
            if (service.isLoading) {
              return const SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            if (deviceData == null) {
              return SizedBox(
                height: MediaQuery.of(context).size.height - 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOnline ? Icons.warning : Icons.cloud_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isOnline 
                            ? 'No data available for this device' 
                            : 'Device is offline',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isOnline)
                        ElevatedButton(
                          onPressed: () {
                            service.startListeningToDevice(widget.deviceId);
                          },
                          child: const Text('Retry Connection'),
                        ),
                    ],
                  ),
                ),
              );
            }
            
            // Responsive layout
            if (isWideScreen) {
              return _buildWideLayout(deviceData, isOnline);
            } else {
              return _buildNarrowLayout(deviceData, isOnline);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Reload device data
          final service = Provider.of<SmartPlugService>(context, listen: false);
          service.startListeningToDevice(widget.deviceId);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refreshing device data...'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildWideLayout(SmartPlugData deviceData, bool isOnline) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column - 60% width
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device Overview',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildDeviceInfoList(deviceData, isOnline),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PowerUsageChart(),
                  const SizedBox(height: 80), // Add bottom padding
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right column - 40% width
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildControlCard(deviceData, isOnline),
                  const SizedBox(height: 16),
                  const CurrentReadings(),
                  const SizedBox(height: 16),
                  const RecentEvents(),
                  const SizedBox(height: 80), // Add bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNarrowLayout(SmartPlugData deviceData, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildControlCard(deviceData, isOnline),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Device Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildDeviceInfoList(deviceData, isOnline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const CurrentReadings(),
          const SizedBox(height: 16),
          const PowerUsageChart(),
          const SizedBox(height: 16),
          const RecentEvents(),
          const SizedBox(height: 80), // Extra padding at the bottom for FAB
        ],
      ),
    );
  }
  
  Widget _buildControlCard(SmartPlugData deviceData, bool isOnline) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Controls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(
                  label: Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      color: isOnline ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: isOnline ? Colors.green : Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRelayButton(deviceData, isOnline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testing Firebase connection...')),
                );
                
                final service = Provider.of<SmartPlugService>(context, listen: false);
                final success = await service.testDatabaseConnection();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                      ? 'Firebase connection successful' 
                      : 'Firebase connection failed. Check console for details.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Test Firebase Connection'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRelayButton(SmartPlugData deviceData, bool isOnline) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isLoading = false;
        
        return ElevatedButton.icon(
          onPressed: (isOnline && !isLoading)
              ? () async {
                  setState(() {
                    isLoading = true;
                  });
                  
                  try {
                    final service = Provider.of<SmartPlugService>(
                      context, 
                      listen: false,
                    );
                    
                    final success = await service.toggleRelay(widget.deviceId);
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            deviceData.relayState 
                                ? 'Turning device OFF...' 
                                : 'Turning device ON...'
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to send command'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error toggling relay: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  }
                }
              : null,
          icon: isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  deviceData.relayState
                      ? Icons.power_settings_new
                      : Icons.power_off_outlined,
                ),
          label: Text(deviceData.relayState ? 'Turn Off' : 'Turn On'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                deviceData.relayState ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }
  
  Widget _buildDeviceInfoList(SmartPlugData data, bool isOnline) {
    final timestamp = data.timestamp;
    final formattedDateTime = _formatTimestamp(timestamp);
    
    return Column(
      children: [
        _buildInfoRow('Status', isOnline ? 'Online' : 'Offline'),
        _buildInfoRow('Power', '${data.power.toStringAsFixed(2)} W'),
        _buildInfoRow('Current', '${data.current.toStringAsFixed(2)} A'),
        _buildInfoRow('Temperature', '${data.temperature}°C'),
        _buildInfoRow('Relay', data.relayState ? 'ON' : 'OFF'),
        _buildInfoRow('Signal Strength', '${data.rssi} dBm'),
        _buildInfoRow('Last Updated', formattedDateTime),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
      ),
    );
  }
  
  // Format timestamp to human-readable string with timezone adjustment
  String _formatTimestamp(DateTime timestamp) {
    // Convert to Central Time
    final centralTime = _toCentralTime(timestamp);
    
    // Format date and time
    return '${centralTime.year}-'
        '${centralTime.month.toString().padLeft(2, '0')}-'
        '${centralTime.day.toString().padLeft(2, '0')} '
        '${centralTime.hour.toString().padLeft(2, '0')}:'
        '${centralTime.minute.toString().padLeft(2, '0')}:'
        '${centralTime.second.toString().padLeft(2, '0')}';
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
} 