import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/websocket_service.dart';

/// Device detail screen with live temperature chart.
class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final WebSocketService _wsService = WebSocketService();
  final List<FlSpot> _chartData = [];
  StreamSubscription? _wsSub;
  Timer? _pollTimer;

  double? _currentTemp;
  double _minTemp = double.infinity;
  double _maxTemp = double.negativeInfinity;
  bool _isLoading = true;
  String? _lastAlert;
  int _lastReadingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectWebSocket();
    // Polling fallback - refresh every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollLatestData();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsService.disconnect();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService().getTelemetry(
        widget.device.id,
        hours: 24,
      );

      setState(() {
        _chartData.clear();
        for (var i = 0; i < history.readings.length; i++) {
          final reading = history.readings[history.readings.length - 1 - i];
          _chartData.add(FlSpot(i.toDouble(), reading.tempC));
          _updateStats(reading.tempC);
        }
        if (_chartData.isNotEmpty) {
          _currentTemp = _chartData.last.y;
        }
        _lastReadingCount = _chartData.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pollLatestData() async {
    if (_isLoading) return;

    try {
      final history = await ApiService().getTelemetry(
        widget.device.id,
        hours: 24,
      );

      if (!mounted) return;

      // Only update if we have new readings
      if (history.readings.isNotEmpty) {
        final latestReading = history.readings.first;

        // Check if this is a new reading by comparing count or temp
        if (history.count > _lastReadingCount ||
            (history.count == _lastReadingCount &&
                latestReading.tempC != _currentTemp)) {
          setState(() {
            _currentTemp = latestReading.tempC;
            _updateStats(latestReading.tempC);
            _chartData.add(
              FlSpot(_chartData.length.toDouble(), latestReading.tempC),
            );

            // Keep last 100 points
            if (_chartData.length > 100) {
              _chartData.removeAt(0);
              for (var i = 0; i < _chartData.length; i++) {
                _chartData[i] = FlSpot(i.toDouble(), _chartData[i].y);
              }
            }
            _lastReadingCount = history.count;
          });
        }
      }
    } catch (e) {
      // Silently fail on poll errors
    }
  }

  void _connectWebSocket() {
    _wsService.connect(widget.device.deviceId);
    _wsSub = _wsService.messageStream?.listen((message) {
      if (message.type == 'telemetry' && mounted) {
        final temp = message.tempC;
        if (temp != null) {
          setState(() {
            _currentTemp = temp;
            _updateStats(temp);
            _chartData.add(FlSpot(_chartData.length.toDouble(), temp));
            // Keep last 100 points
            if (_chartData.length > 100) {
              _chartData.removeAt(0);
              // Reindex
              for (var i = 0; i < _chartData.length; i++) {
                _chartData[i] = FlSpot(i.toDouble(), _chartData[i].y);
              }
            }
          });
        }
      } else if (message.type == 'alert' && mounted) {
        setState(() {
          _lastAlert = message.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message.message ?? 'Alert triggered')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _updateStats(double temp) {
    if (temp < _minTemp) _minTemp = temp;
    if (temp > _maxTemp) _maxTemp = temp;
  }

  Color _getTempColor(double? temp) {
    if (temp == null) return Colors.grey;
    if (temp < AppConfig.tempMin) return Colors.blue;
    if (temp > AppConfig.tempMax) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.device.name,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentTempCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildChart(),
                  if (_lastAlert != null) ...[
                    const SizedBox(height: 16),
                    _buildAlertCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentTempCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTempColor(_currentTemp).withOpacity(0.3),
            _getTempColor(_currentTemp).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getTempColor(_currentTemp).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            'Current Temperature',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTemp?.toStringAsFixed(1) ?? '--',
                style: TextStyle(
                  color: _getTempColor(_currentTemp),
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '°C',
                  style: TextStyle(
                    color: _getTempColor(_currentTemp),
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getTempColor(_currentTemp).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _wsService.isConnected
                        ? Colors.green
                        : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _wsService.isConnected ? 'Live' : 'Connecting...',
                  style: TextStyle(
                    color: _wsService.isConnected
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Min', _minTemp, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Max', _maxTemp, Colors.red)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Optimal', AppConfig.tempOptimal, Colors.green),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    final displayValue = value.isFinite ? value.toStringAsFixed(1) : '--';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '$displayValue°C',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temperature History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _chartData.isEmpty
                ? Center(
                    child: Text(
                      'No data yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}°',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 33,
                      maxY: 42,
                      lineBarsData: [
                        // Optimal range band
                        LineChartBarData(
                          spots: [
                            FlSpot(0, AppConfig.tempMin),
                            FlSpot(
                              _chartData.length.toDouble(),
                              AppConfig.tempMin,
                            ),
                          ],
                          isCurved: false,
                          color: Colors.green.withOpacity(0.3),
                          barWidth: 0,
                          belowBarData: BarAreaData(show: false),
                          dotData: const FlDotData(show: false),
                        ),
                        // Main temperature line
                        LineChartBarData(
                          spots: _chartData,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: Colors.amber,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.amber.withOpacity(0.3),
                                Colors.amber.withOpacity(0.0),
                              ],
                            ),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)}°C',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Alert',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _lastAlert ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
