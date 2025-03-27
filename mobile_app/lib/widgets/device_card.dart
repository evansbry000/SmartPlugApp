import 'package:flutter/material.dart';
import '../services/smart_plug_service.dart';

class DeviceCard extends StatelessWidget {
  final String deviceName;
  final DeviceState deviceState;
  final double current;
  final double power;
  final double temperature;
  final bool relayState;
  final Function(bool) onToggle;

  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.deviceState,
    required this.current,
    required this.power,
    required this.temperature,
    required this.relayState,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  deviceName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _buildStateChip(),
              ],
            ),
            const SizedBox(height: 16),
            _buildReadingsGrid(),
            const SizedBox(height: 16),
            _buildTemperatureWarning(),
            const SizedBox(height: 16),
            _buildToggleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateChip() {
    Color color;
    String text;

    switch (deviceState) {
      case DeviceState.off:
        color = Colors.grey;
        text = 'Off';
        break;
      case DeviceState.idle:
        color = Colors.orange;
        text = 'Idle';
        break;
      case DeviceState.running:
        color = Colors.green;
        text = 'Running';
        break;
    }

    return Chip(
      label: Text(text),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _buildReadingsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildReadingCard(
          'Current',
          '${current.toStringAsFixed(2)} A',
          Icons.electrical_services,
        ),
        _buildReadingCard(
          'Power',
          '${power.toStringAsFixed(2)} W',
          Icons.power,
        ),
        _buildReadingCard(
          'Temperature',
          '${temperature.toStringAsFixed(1)}°C',
          Icons.thermostat,
        ),
        _buildReadingCard(
          'Status',
          relayState ? 'On' : 'Off',
          Icons.power_settings_new,
        ),
      ],
    );
  }

  Widget _buildReadingCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureWarning() {
    if (temperature >= 35) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: temperature >= 45
              ? Colors.red.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              temperature >= 45 ? Icons.warning : Icons.warning_amber,
              color: temperature >= 45 ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                temperature >= 45
                    ? 'Critical temperature! Device will shut off.'
                    : 'High temperature warning!',
                style: TextStyle(
                  color: temperature >= 45 ? Colors.red : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildToggleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => onToggle(!relayState),
        style: ElevatedButton.styleFrom(
          backgroundColor: relayState ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
        ),
        child: Text(relayState ? 'Turn Off' : 'Turn On'),
      ),
    );
  }
} 