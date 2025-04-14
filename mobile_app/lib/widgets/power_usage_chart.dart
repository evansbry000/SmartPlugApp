import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smart_plug_service.dart';
import 'dart:math' as math;

class PowerUsageChart extends StatefulWidget {
  const PowerUsageChart({super.key});

  @override
  State<PowerUsageChart> createState() => _PowerUsageChartState();
}

class _PowerUsageChartState extends State<PowerUsageChart> {
  bool _isLoading = false;
  final List<double> _powerData = [];
  
  @override
  void initState() {
    super.initState();
    _generateDummyData(); // Generate dummy data for now
  }
  
  void _generateDummyData() {
    // Generate some dummy power data points for demonstration
    _powerData.clear();
    
    // Generate 24 data points representing hourly readings
    final random = math.Random();
    for (int i = 0; i < 24; i++) {
      // Create a wave pattern with some randomness
      final value = 100 + 50 * math.sin(i * 0.5) + (20 * random.nextDouble());
      _powerData.add(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Usage (Last 24 Hours)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Hourly power consumption in watts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: _buildSimpleChart(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _SimpleChartPainter(_powerData),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0h', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Text('6h', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Text('12h', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Text('18h', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Text('24h', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _SimpleChartPainter extends CustomPainter {
  final List<double> dataPoints;
  
  _SimpleChartPainter(this.dataPoints);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final maxY = dataPoints.reduce(math.max);
    final minY = dataPoints.reduce(math.min).clamp(0, double.infinity);
    
    final path = Path();
    final fillPath = Path();
    
    // Calculate points
    final points = <Offset>[];
    
    for (int i = 0; i < dataPoints.length; i++) {
      final x = size.width * i / (dataPoints.length - 1);
      final normalizedY = (dataPoints[i] - minY) / (maxY - minY);
      final y = size.height - (normalizedY * size.height);
      points.add(Offset(x, y));
    }
    
    // Create curved path
    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      final p0 = i > 0 ? points[i - 1] : points[0];
      final p1 = points[i];
      
      final controlPointX1 = p0.dx + (p1.dx - p0.dx) / 3;
      final controlPointX2 = p0.dx + (p1.dx - p0.dx) * 2 / 3;
      
      path.cubicTo(
        controlPointX1, p0.dy,
        controlPointX2, p1.dy,
        p1.dx, p1.dy,
      );
      
      fillPath.cubicTo(
        controlPointX1, p0.dy,
        controlPointX2, p1.dy,
        p1.dx, p1.dy,
      );
    }
    
    // Complete the fill path
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    
    // Draw the fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw the line
    canvas.drawPath(path, paint);
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    
    // Horizontal grid lines
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Vertical grid lines
    for (int i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 