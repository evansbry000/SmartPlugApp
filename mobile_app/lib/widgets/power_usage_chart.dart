import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';

class PowerUsageChart extends StatefulWidget {
  const PowerUsageChart({super.key});

  @override
  State<PowerUsageChart> createState() => _PowerUsageChartState();
}

class _PowerUsageChartState extends State<PowerUsageChart> {
  List<SmartPlugData> _historicalData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
  }

  Future<void> _loadHistoricalData() async {
    setState(() => _isLoading = true);
    
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 24));
      
      final data = await context.read<SmartPlugService>().getHistoricalData(
        start: start,
        end: end,
      );
      
      setState(() {
        _historicalData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load historical data')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Power Usage (24h)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadHistoricalData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_historicalData.isEmpty)
              const Center(child: Text('No historical data available'))
            else
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Power usage data: ${_historicalData.length} points available',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 