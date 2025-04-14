import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/smart_plug_service.dart';
import '../widgets/smart_plug_card.dart';
import 'device_detail_screen.dart';
import 'settings_screen.dart';
import '../models/smart_plug_data.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize the smart plug service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final smartPlugService = Provider.of<SmartPlugService>(context, listen: false);
      smartPlugService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final isMediumScreen = screenWidth > 600 && screenWidth <= 900;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Plugs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: Consumer<SmartPlugService>(
        builder: (context, smartPlugService, child) {
          if (smartPlugService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (smartPlugService.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.electrical_services_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Smart Plugs Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect a Smart Plug to get started',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // In a real app, this would open a flow to add a new device
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Device setup would start here'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Smart Plug'),
                  ),
                ],
              ),
            );
          }

          // Determine the number of columns based on screen width
          int crossAxisCount;
          if (isLargeScreen) {
            crossAxisCount = 3;
          } else if (isMediumScreen) {
            crossAxisCount = 2;
          } else {
            crossAxisCount = 1;
          }

          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 1200 : isMediumScreen ? 800 : 600,
              ),
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: smartPlugService.devices.length,
                itemBuilder: (context, index) {
                  final deviceId = smartPlugService.devices[index];
                  final deviceData = smartPlugService.getDeviceData(deviceId);
                  final isOnline = smartPlugService.isDeviceOnline(deviceId);
                  
                  return SmartPlugCard(
                    deviceId: deviceId,
                    deviceData: deviceData,
                    isOnline: isOnline,
                    onToggle: () {
                      smartPlugService.toggleRelay(deviceId);
                    },
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceDetailScreen(
                            deviceId: deviceId,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
} 