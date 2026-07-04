import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/websocket_service.dart';
import 'package:egg_guardian/theme.dart';
import 'package:intl/intl.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with WidgetsBindingObserver {
  final WebSocketService _wsService = WebSocketService();
  final List<FlSpot> _chartData = [];
  final List<DateTime> _chartTimes = [];
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
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _connectWebSocket();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSub?.cancel();
    _wsService.disconnect();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadHistory();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConfig.telemetryPollInterval, (_) {
      if (!_wsService.isConnected) _pollLatestData();
    });
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService().getTelemetry(widget.device.id, hours: 24);
      if (!mounted) return;
      setState(() {
        _chartData.clear();
        _chartTimes.clear();
        _minTemp = double.infinity;
        _maxTemp = double.negativeInfinity;
        for (var i = 0; i < history.readings.length; i++) {
          final r = history.readings[history.readings.length - 1 - i];
          _chartData.add(FlSpot(i.toDouble(), r.tempC));
          _chartTimes.add(r.recordedAt);
          _updateStats(r.tempC);
        }
        if (_chartData.isNotEmpty) _currentTemp = _chartData.last.y;
        _lastReadingCount = _chartData.length;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pollLatestData() async {
    if (_isLoading || !mounted) return;
    try {
      final history = await ApiService().getTelemetry(widget.device.id, hours: 24);
      if (!mounted || history.readings.isEmpty) return;
      final latest = history.readings.first;
      if (history.count > _lastReadingCount || latest.tempC != _currentTemp) {
        setState(() {
          _currentTemp = latest.tempC;
          _updateStats(latest.tempC);
          _chartData.add(FlSpot(_chartData.length.toDouble(), latest.tempC));
          _chartTimes.add(latest.recordedAt);
          if (_chartData.length > 100) {
            _chartData.removeAt(0);
            _chartTimes.removeAt(0);
            for (var i = 0; i < _chartData.length; i++) {
              _chartData[i] = FlSpot(i.toDouble(), _chartData[i].y);
            }
          }
          _lastReadingCount = history.count;
        });
      }
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    await _wsService.connect(widget.device.deviceId);
    if (!mounted) return;
    _wsSub?.cancel();
    _wsSub = _wsService.messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.type == 'telemetry' && msg.tempC != null) {
        setState(() {
          _currentTemp = msg.tempC!;
          _updateStats(msg.tempC!);
          _chartData.add(FlSpot(_chartData.length.toDouble(), msg.tempC!));
          _chartTimes.add(DateTime.now());
          if (_chartData.length > 100) {
            _chartData.removeAt(0);
            _chartTimes.removeAt(0);
            for (var i = 0; i < _chartData.length; i++) {
              _chartData[i] = FlSpot(i.toDouble(), _chartData[i].y);
            }
          }
        });
      } else if (msg.type == 'alert') {
        setState(() => _lastAlert = msg.message);
      }
    });
  }

  void _updateStats(double t) {
    if (t < _minTemp) _minTemp = t;
    if (t > _maxTemp) _maxTemp = t;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: EgTheme.bgBase,
      body: Column(
        children: [
          _buildHeader(),
          if (ApiService().isOfflineMode) _buildOfflineBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: EgTheme.accent))
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: EgTheme.bgCard,
        border: Border(bottom: BorderSide(color: EgTheme.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: EgTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.device.name, style: GoogleFonts.outfit(
                      fontSize: 17, fontWeight: FontWeight.w600, color: EgTheme.textPrimary,
                    )),
                    Text(widget.device.deviceId, style: EgTheme.body(12, color: EgTheme.textMuted)),
                  ],
                ),
              ),
              // WS status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_wsService.isConnected ? EgTheme.success : EgTheme.warning).withOpacity(0.1),
                  borderRadius: EgTheme.r32,
                  border: Border.all(
                    color: (_wsService.isConnected ? EgTheme.success : EgTheme.warning).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _wsService.isConnected ? EgTheme.success : EgTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _wsService.isConnected ? 'Live' : 'Syncing',
                      style: EgTheme.body(11,
                          color: _wsService.isConnected ? EgTheme.success : EgTheme.warning,
                          weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: EgTheme.textSecondary),
                onPressed: _loadHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
      color: EgTheme.warning.withOpacity(0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: EgTheme.warning, size: 13),
          const SizedBox(width: 7),
          Text('Offline — cached data', style: EgTheme.body(12, color: EgTheme.warning, weight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTempHero(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildChartCard(),
          if (_lastAlert != null) ...[
            const SizedBox(height: 16),
            _buildAlertCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTempHero() {
    final tc = tempColor(_currentTemp, minTemp: widget.device.tempMin, maxTemp: widget.device.tempMax);
    final status = tempStatus(_currentTemp, minTemp: widget.device.tempMin, maxTemp: widget.device.tempMax);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tc.withOpacity(0.15), EgTheme.bgCard],
        ),
        borderRadius: EgTheme.r16,
        border: Border.all(color: tc.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: tc.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text('Current Temperature', style: EgTheme.body(13, color: EgTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTemp?.toStringAsFixed(1) ?? '--.-',
                style: GoogleFonts.outfit(
                  fontSize: 72, fontWeight: FontWeight.w700, color: tc,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('°C', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w500, color: tc)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: tc.withOpacity(0.12),
              borderRadius: EgTheme.r32,
              border: Border.all(color: tc.withOpacity(0.25)),
            ),
            child: Text(status, style: EgTheme.body(13, color: tc, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text('Safe range: ${widget.device.tempMin}°C – ${widget.device.tempMax}°C',
              style: EgTheme.body(12, color: EgTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Session Min', _minTemp, EgTheme.info, Icons.arrow_downward_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Session Max', _maxTemp, EgTheme.danger, Icons.arrow_upward_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Optimal', (widget.device.tempMin + widget.device.tempMax) / 2, EgTheme.success, Icons.check_circle_outline)),
      ],
    );
  }

  Widget _statCard(String label, double value, Color color, IconData icon) {
    final display = value.isFinite ? '${value.toStringAsFixed(1)}°C' : '--';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: EgTheme.bgCard,
        borderRadius: EgTheme.r12,
        border: Border.all(color: EgTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(display, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: EgTheme.body(11, color: EgTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      decoration: EgTheme.card(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Temperature History', style: GoogleFonts.outfit(
                fontSize: 15, fontWeight: FontWeight.w600, color: EgTheme.textPrimary,
              )),
              Text('Last 24 hours', style: EgTheme.body(12, color: EgTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _chartData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.show_chart_rounded, color: EgTheme.textMuted, size: 36),
                        const SizedBox(height: 8),
                        Text('Waiting for data', style: EgTheme.body(13, color: EgTheme.textMuted)),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: EgTheme.border.withOpacity(0.6),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (val, _) => Text(
                              '${val.toInt()}°',
                              style: EgTheme.body(10, color: EgTheme.textMuted),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 33,
                      maxY: 42,
                      // Safe zone reference lines
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: widget.device.tempMin,
                          color: EgTheme.success.withOpacity(0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (_) => '${widget.device.tempMin}°',
                            style: EgTheme.body(9, color: EgTheme.success),
                            alignment: Alignment.topRight,
                          ),
                        ),
                        HorizontalLine(
                          y: widget.device.tempMax,
                          color: EgTheme.success.withOpacity(0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (_) => '${widget.device.tempMax}°',
                            style: EgTheme.body(9, color: EgTheme.success),
                            alignment: Alignment.topRight,
                          ),
                        ),
                      ]),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartData,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: EgTheme.accent,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [EgTheme.accent.withOpacity(0.2), Colors.transparent],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: EgTheme.bgElevated,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(1)}°C',
                            GoogleFonts.outfit(color: EgTheme.accent, fontWeight: FontWeight.w600, fontSize: 13),
                          )).toList(),
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
        color: EgTheme.danger.withOpacity(0.08),
        borderRadius: EgTheme.r12,
        border: Border.all(color: EgTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: EgTheme.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Alert', style: EgTheme.body(13, color: EgTheme.danger, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_lastAlert ?? '', style: EgTheme.body(13, color: EgTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
