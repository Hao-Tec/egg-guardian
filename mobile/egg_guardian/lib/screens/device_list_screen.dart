import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/websocket_service.dart';
import 'package:egg_guardian/theme.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen>
    with WidgetsBindingObserver {
  final WebSocketService _wsService = WebSocketService();
  List<Device> _devices = [];
  final Map<String, double> _liveTemps = {};
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;
  Timer? _refreshTimer;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAdminStatus();
    _loadDevices();
    _startAutoRefresh();
    _connectWebSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _wsSub?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = await ApiService().getCurrentUser();
      if (mounted) setState(() => _isAdmin = user.isSuperuser);
    } catch (_) {}
  }

  Future<void> _connectWebSocket() async {
    await _wsService.connect('all');
    if (!mounted) return;
    _wsSub?.cancel();
    _wsSub = _wsService.messageStream.listen((msg) {
      if (msg.type == 'telemetry' && mounted && msg.tempC != null) {
        setState(() => _liveTemps[msg.deviceId] = msg.tempC!);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadDevices();
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(AppConfig.deviceRefreshInterval, (_) {
      _loadDevices(silent: true);
    });
  }

  Future<void> _loadDevices({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final devices = await ApiService().getDevices();
      if (mounted) setState(() { _devices = devices; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to load devices.'; _isLoading = false; });
    }
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1627), Color(0xFF111D35)],
        ),
        border: Border(bottom: BorderSide(color: EgTheme.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
          child: Row(
            children: [
              // Logo + title
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: EgTheme.accentGradient,
                  borderRadius: EgTheme.r8,
                ),
                child: const Icon(Icons.egg_outlined, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Egg Guardian', style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w700, color: EgTheme.textPrimary,
                    )),
                    Text('Incubator monitoring', style: EgTheme.body(12, color: EgTheme.textSecondary)),
                  ],
                ),
              ),
              // Actions
              Row(
                children: [
                  if (_isAdmin)
                    _headerIconBtn(Icons.admin_panel_settings_outlined,
                        tooltip: 'Admin Panel',
                        onTap: () => Navigator.pushReplacementNamed(context, '/admin')),
                  _headerIconBtn(Icons.refresh_rounded,
                      tooltip: 'Refresh', onTap: _loadDevices),
                  _headerIconBtn(Icons.logout_rounded,
                      tooltip: 'Logout',
                      onTap: () async {
                        await ApiService().logout();
                        if (mounted) Navigator.pushReplacementNamed(context, '/login');
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, {required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: EgTheme.r8,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: EgTheme.textSecondary, size: 22),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      color: EgTheme.warning.withOpacity(0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: EgTheme.warning, size: 14),
          const SizedBox(width: 8),
          Text('Offline — showing cached data',
              style: EgTheme.body(12, color: EgTheme.warning, weight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: EgTheme.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EgTheme.danger.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.signal_wifi_off_rounded, color: EgTheme.danger, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Connection Error', style: EgTheme.heading(18)),
              const SizedBox(height: 8),
              Text(_error!, style: EgTheme.body(14, color: EgTheme.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadDevices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EgTheme.bgCard,
                  foregroundColor: EgTheme.textPrimary,
                  side: const BorderSide(color: EgTheme.border),
                  shape: const RoundedRectangleBorder(borderRadius: EgTheme.r12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry', style: EgTheme.body(14, weight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: EgTheme.bgCard,
                  borderRadius: EgTheme.r24,
                  border: Border.all(color: EgTheme.border),
                ),
                child: const Icon(Icons.devices_other_rounded, color: EgTheme.textMuted, size: 48),
              ),
              const SizedBox(height: 20),
              Text('No devices yet', style: EgTheme.heading(18)),
              const SizedBox(height: 8),
              Text('Register a device from the admin panel\nor run the device simulator.',
                  style: EgTheme.body(14, color: EgTheme.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: EgTheme.accent,
      backgroundColor: EgTheme.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        itemCount: _devices.length,
        itemBuilder: (ctx, i) => _buildDeviceCard(_devices[i]),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final temp = _liveTemps[device.deviceId] ?? device.lastTemp;
    final tColor = tempColor(temp, minTemp: device.tempMin, maxTemp: device.tempMax);
    final isLive = _liveTemps.containsKey(device.deviceId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/device', arguments: device),
          borderRadius: EgTheme.r16,
          child: Container(
            decoration: EgTheme.card(),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Status indicator container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tColor.withOpacity(0.1),
                    borderRadius: EgTheme.r12,
                    border: Border.all(color: tColor.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.device_thermostat_rounded, color: tColor, size: 26),
                ),
                const SizedBox(width: 16),
                // Name + ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name,
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w600, color: EgTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: device.isActive
                                  ? (isLive ? EgTheme.success : EgTheme.textMuted)
                                  : EgTheme.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLive ? 'Live' : (device.isActive ? 'Active' : 'Offline'),
                            style: EgTheme.body(12, color: device.isActive
                                ? (isLive ? EgTheme.success : EgTheme.textMuted)
                                : EgTheme.danger),
                          ),
                          Text(' · ', style: EgTheme.body(12, color: EgTheme.textMuted)),
                          Text(device.deviceId,
                              style: EgTheme.body(12, color: EgTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Temperature
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (temp != null) ...[
                      Text(
                        '${temp.toStringAsFixed(1)}°C',
                        style: GoogleFonts.outfit(
                            fontSize: 22, fontWeight: FontWeight.w700, color: tColor),
                      ),
                      Text(tempStatus(temp, minTemp: device.tempMin, maxTemp: device.tempMax),
                          style: EgTheme.body(11, color: tColor.withOpacity(0.8))),
                    ] else
                      Text('— °C',
                          style: GoogleFonts.outfit(
                              fontSize: 22, fontWeight: FontWeight.w700, color: EgTheme.textMuted)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: EgTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
