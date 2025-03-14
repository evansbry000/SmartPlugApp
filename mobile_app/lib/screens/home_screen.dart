import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/smart_plug_service.dart';
import '../widgets/power_usage_chart.dart';
import '../widgets/relay_control.dart';
import '../widgets/current_readings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Plug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<SmartPlugService>(
        builder: (context, smartPlugService, child) {
          if (smartPlugService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = smartPlugService.currentData;
          if (data == null) {
            return const Center(child: Text('No data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RelayControl(),
                const SizedBox(height: 24),
                const CurrentReadings(),
                const SizedBox(height: 24),
                const PowerUsageChart(),
              ],
            ),
          );
        },
      ),
    );
  }
} 