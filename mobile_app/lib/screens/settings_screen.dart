import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _powerWarning = true;
  bool _connectionAlert = true;
  double _powerThreshold = 1000.0;
  bool _temperatureWarning = true;
  double _temperatureThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    // For now, just use default values
    // In a real app, this would load from the SmartPlugService
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, this would save to the SmartPlugService
      // For now, just simulate a save
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Power Usage Alerts'),
                          subtitle: const Text(
                              'Notify when power usage exceeds threshold'),
                          value: _powerWarning,
                          onChanged: (value) {
                            setState(() {
                              _powerWarning = value;
                            });
                          },
                        ),
                        if (_powerWarning)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Power threshold: ${_powerThreshold.toInt()} W',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Slider(
                                  value: _powerThreshold,
                                  min: 100,
                                  max: 3000,
                                  divisions: 29,
                                  label: '${_powerThreshold.toInt()} W',
                                  onChanged: (value) {
                                    setState(() {
                                      _powerThreshold = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        SwitchListTile(
                          title: const Text('Connection Alerts'),
                          subtitle: const Text(
                              'Notify when device connects or disconnects'),
                          value: _connectionAlert,
                          onChanged: (value) {
                            setState(() {
                              _connectionAlert = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Temperature Alerts'),
                          subtitle: const Text(
                              'Notify when temperature exceeds threshold'),
                          value: _temperatureWarning,
                          onChanged: (value) {
                            setState(() {
                              _temperatureWarning = value;
                            });
                          },
                        ),
                        if (_temperatureWarning)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Temperature threshold: ${_temperatureThreshold.toInt()}°C',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Slider(
                                  value: _temperatureThreshold,
                                  min: 30,
                                  max: 80,
                                  divisions: 50,
                                  label: '${_temperatureThreshold.toInt()}°C',
                                  onChanged: (value) {
                                    setState(() {
                                      _temperatureThreshold = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Consumer<AuthService>(
                          builder: (context, auth, child) {
                            final user = auth.currentUser;
                            return ListTile(
                              title: Text(user?.email ?? 'Not signed in'),
                              subtitle: const Text('Email'),
                              leading: const Icon(Icons.email),
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('Sign Out'),
                          leading: const Icon(Icons.logout),
                          onTap: () async {
                            final authService = Provider.of<AuthService>(
                              context,
                              listen: false,
                            );
                            await authService.signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _savePreferences,
                  child: const Text('Save Settings'),
                ),
              ],
            ),
    );
  }
} 