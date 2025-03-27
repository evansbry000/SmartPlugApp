import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _useCelsius = true;
  bool _temperatureWarning = true;
  bool _temperatureShutoff = true;
  bool _deviceStateChange = true;
  bool _connectionLost = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCelsius = prefs.getBool('useCelsius') ?? true;
      _temperatureWarning = prefs.getBool('temperatureWarning') ?? true;
      _temperatureShutoff = prefs.getBool('temperatureShutoff') ?? true;
      _deviceStateChange = prefs.getBool('deviceStateChange') ?? true;
      _connectionLost = prefs.getBool('connectionLost') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useCelsius', _useCelsius);
    await prefs.setBool('temperatureWarning', _temperatureWarning);
    await prefs.setBool('temperatureShutoff', _temperatureShutoff);
    await prefs.setBool('deviceStateChange', _deviceStateChange);
    await prefs.setBool('connectionLost', _connectionLost);

    // Update Firebase notification preferences
    final service = Provider.of<SmartPlugService>(context, listen: false);
    await service.updateNotificationPreferences(
      temperatureWarning: _temperatureWarning,
      temperatureShutoff: _temperatureShutoff,
      deviceStateChange: _deviceStateChange,
      connectionLost: _connectionLost,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Temperature Units',
            [
              SwitchListTile(
                title: const Text('Use Celsius'),
                value: _useCelsius,
                onChanged: (value) {
                  setState(() {
                    _useCelsius = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Notifications',
            [
              SwitchListTile(
                title: const Text('Temperature Warning (35°C)'),
                subtitle: const Text('Get notified when temperature is high'),
                value: _temperatureWarning,
                onChanged: (value) {
                  setState(() {
                    _temperatureWarning = value;
                  });
                  _saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Temperature Shutoff (45°C)'),
                subtitle: const Text('Get notified when device shuts off due to high temperature'),
                value: _temperatureShutoff,
                onChanged: (value) {
                  setState(() {
                    _temperatureShutoff = value;
                  });
                  _saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Device State Changes'),
                subtitle: const Text('Get notified when device state changes'),
                value: _deviceStateChange,
                onChanged: (value) {
                  setState(() {
                    _deviceStateChange = value;
                  });
                  _saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Connection Lost'),
                subtitle: const Text('Get notified when connection to device is lost'),
                value: _connectionLost,
                onChanged: (value) {
                  setState(() {
                    _connectionLost = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
} 