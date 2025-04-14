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
                  child: ElevatedButton.icon(
                    onPressed: isOnline
                        ? () {
                            final service = Provider.of<SmartPlugService>(
                              context,
                              listen: false,
                            );
                            service.toggleRelay(widget.deviceId);
                          }
                        : null,
                    icon: Icon(
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
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeviceInfoList(SmartPlugData data, bool isOnline) {
    final timestamp = data.timestamp;
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final formattedDate =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    
    return Column(
      children: [
        _buildInfoRow('Status', isOnline ? 'Online' : 'Offline'),
        _buildInfoRow('Power', '${data.power.toStringAsFixed(2)} W'),
        _buildInfoRow('Current', '${data.current.toStringAsFixed(2)} A'),
        _buildInfoRow('Temperature', '${data.temperature.toStringAsFixed(1)}°C'),
        _buildInfoRow('Relay', data.relayState ? 'ON' : 'OFF'),
        _buildInfoRow('Signal Strength', '${data.rssi} dBm'),
        _buildInfoRow('Last Updated', '$formattedDate $formattedTime'),
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
} 