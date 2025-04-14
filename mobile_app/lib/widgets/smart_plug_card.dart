import 'package:flutter/material.dart';
import '../models/smart_plug_data.dart';

class SmartPlugCard extends StatelessWidget {
  final String deviceId;
  final SmartPlugData? deviceData;
  final bool isOnline;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const SmartPlugCard({
    super.key,
    required this.deviceId,
    required this.deviceData,
    required this.isOnline,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOnline ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32, // Subtract padding
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Smart Plug ${deviceId.toUpperCase()}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildConnectionStatus(),
                        ],
                      ),
                      if (deviceData != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120, // Fixed height for the readings grid
                          child: _buildReadingsGrid(context),
                        ),
                        const SizedBox(height: 12),
                        _buildPowerControl(),
                      ] else ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: Text('No data available'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: isOnline ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.0, // Wider tiles (less height)
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildReadingTile(
          context,
          'Power',
          '${deviceData?.power.toStringAsFixed(1) ?? "0.0"} W',
          Icons.electric_bolt,
          Colors.amber,
        ),
        _buildReadingTile(
          context,
          'Current',
          '${deviceData?.current.toStringAsFixed(2) ?? "0.00"} A',
          Icons.electric_meter,
          Colors.blue,
        ),
        _buildReadingTile(
          context,
          'Voltage',
          '${deviceData?.voltage.toStringAsFixed(1) ?? "0.0"} V',
          Icons.bolt,
          Colors.purple,
        ),
        _buildReadingTile(
          context,
          'Temperature',
          '${deviceData?.temperature.toString() ?? "0"}°C',
          Icons.thermostat,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildReadingTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color), // Smaller icon
          const SizedBox(width: 4), // Less spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // More compact
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10, // Smaller font
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // Smaller font
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerControl() {
    final bool isOn = deviceData?.relayState ?? false;
    
    return SizedBox(
      width: double.infinity,
      height: 36, // Fixed height button
      child: ElevatedButton.icon(
        onPressed: isOnline ? onToggle : null,
        icon: Icon(
          isOn ? Icons.power_settings_new : Icons.power_off_outlined,
          color: isOn ? Colors.white : null,
          size: 16, // Smaller icon
        ),
        label: Text(
          isOn ? 'Turn Off' : 'Turn On',
          style: const TextStyle(fontSize: 12), // Smaller font
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOn ? Colors.red : Colors.green,
          foregroundColor: isOn ? Colors.white : Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // Less padding
        ),
      ),
    );
  }
} 