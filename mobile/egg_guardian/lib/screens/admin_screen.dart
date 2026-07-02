import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/websocket_service.dart';
import 'package:egg_guardian/models.dart';
import 'package:egg_guardian/theme.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final api = ApiService();
  final _wsService = WebSocketService();

  int _selectedTab = 0;
  Timer? _refreshTimer;
  StreamSubscription? _wsSub;

  // Live chart data
  final List<FlSpot> _liveSpots = [];
  double? _liveTemp;

  // Form controllers
  final _deviceIdController   = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _minTempController    = TextEditingController(text: '35.0');
  final _maxTempController    = TextEditingController(text: '39.0');

  // Data
  List<Device> _devices = [];
  List<User>   _users   = [];
  List<dynamic> _alerts = [];
  Device? _selectedRuleDevice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadAllData(isAutoRefresh: true));
    _setupWebSocket();
  }

  Future<void> _setupWebSocket() async {
    if (_selectedRuleDevice == null) return;
    final deviceId = _selectedRuleDevice!.deviceId;
    await _wsService.connect(deviceId);
    if (!mounted || _selectedRuleDevice?.deviceId != deviceId) return;
    _wsSub?.cancel();
    _wsSub = _wsService.messageStream.listen(_handleWsMessage);
  }

  void _handleWsMessage(WsMessage msg) {
    if (!mounted) return;
    if (msg.type == 'telemetry' && msg.deviceId == _selectedRuleDevice?.deviceId && msg.tempC != null) {
      setState(() {
        _liveTemp = msg.tempC!;
        _liveSpots.add(FlSpot(_liveSpots.length.toDouble(), msg.tempC!));
        if (_liveSpots.length > 50) _liveSpots.removeAt(0);
      });
    } else if (msg.type == 'alert') {
      _loadAllData(isAutoRefresh: true);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _wsSub?.cancel();
    _wsService.disconnect();
    _tabControllers();
    super.dispose();
  }

  void _tabControllers() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
  }

  Future<void> _loadAllData({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        api.getDevices(),
        api.getUsers(),
        api.getTriggeredAlerts(),
      ]);
      if (!mounted) return;
      final oldId = _selectedRuleDevice?.deviceId;
      setState(() {
        _devices = results[0] as List<Device>;
        _users   = results[1] as List<User>;
        _alerts  = results[2] as List<dynamic>;

        if (_selectedRuleDevice != null) {
          try { _selectedRuleDevice = (_devices as List<Device>).firstWhere((d) => d.id == _selectedRuleDevice!.id); }
          catch (_) { _selectedRuleDevice = _devices.isNotEmpty ? _devices.first : null; }
        } else if (_devices.isNotEmpty) {
          _selectedRuleDevice = _devices.first;
        }
      });
      if (_selectedRuleDevice?.deviceId != oldId) {
        _liveSpots.clear();
        _liveTemp = null;
        _setupWebSocket();
      }
    } catch (e) {
      if (!isAutoRefresh) _snack('Failed to load data: $e', isError: true);
    } finally {
      if (mounted && !isAutoRefresh) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: EgTheme.body(14)),
      backgroundColor: isError ? EgTheme.danger : EgTheme.success,
    ));
  }

  // ── Device actions ────────────────────────────────────────────────────

  Future<void> _registerDevice() async {
    if (_deviceIdController.text.isEmpty || _deviceNameController.text.isEmpty) return;
    try {
      await api.createDevice(_deviceIdController.text.trim(), _deviceNameController.text.trim());
      _deviceIdController.clear();
      _deviceNameController.clear();
      await _loadAllData();
      _snack('Device registered successfully!');
    } catch (e) {
      _snack('Registration failed: $e', isError: true);
    }
  }

  Future<void> _deleteDevice(Device d) async {
    final ok = await _confirm('Delete Device', 'Delete "${d.name}"? All data will be removed.');
    if (ok == true) {
      try {
        await api.deleteDevice(d.id);
        await _loadAllData();
        _snack('Device deleted.');
      } catch (e) {
        _snack('Error: $e', isError: true);
      }
    }
  }

  // ── Alert actions ─────────────────────────────────────────────────────

  Future<void> _createAlertRule() async {
    if (_selectedRuleDevice == null) return;
    try {
      await api.createAlertRule(
        _selectedRuleDevice!.id,
        double.tryParse(_minTempController.text) ?? 35.0,
        double.tryParse(_maxTempController.text) ?? 39.0,
      );
      _snack('Alert rule saved!');
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _acknowledgeAlert(int id) async {
    try {
      await api.acknowledgeAlert(id);
      await _loadAllData();
      _snack('Alert acknowledged.');
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  // ── User actions ──────────────────────────────────────────────────────

  Future<void> _approveUser(User u) async {
    try {
      await api.approveUser(u.id);
      await _loadAllData();
      _snack('${u.email} approved.');
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _toggleAdmin(User u) async {
    try {
      await api.toggleAdminStatus(u.id);
      await _loadAllData();
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _deleteUser(User u) async {
    final ok = await _confirm('Delete User', 'Delete "${u.email}"? This cannot be undone.');
    if (ok == true) {
      try {
        await api.deleteUser(u.id);
        await _loadAllData();
        _snack('User deleted.');
      } catch (e) {
        _snack('Error: $e', isError: true);
      }
    }
  }

  // ── Confirm dialog ────────────────────────────────────────────────────

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: EgTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: EgTheme.r16),
      title: Text(title, style: EgTheme.heading(17)),
      content: Text(body, style: EgTheme.body(14, color: EgTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: EgTheme.body(14, color: EgTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm', style: EgTheme.body(14, color: EgTheme.danger, weight: FontWeight.w600)),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════

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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: EgTheme.accent))
                : IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildDevicesTab(),
                      _buildAlertsTab(),
                      _buildUsersTab(),
                    ],
                  ),
          ),
          _buildBottomNav(),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(gradient: EgTheme.accentGradient, borderRadius: EgTheme.r8),
                child: const Icon(Icons.egg_outlined, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Panel', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: EgTheme.textPrimary)),
                    Text('Egg Guardian', style: EgTheme.body(11, color: EgTheme.textMuted)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/devices'),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: EgTheme.textSecondary),
                label: Text('User View', style: EgTheme.body(12, color: EgTheme.textSecondary)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              ),
              InkWell(
                onTap: () async {
                  await api.logout();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
                borderRadius: EgTheme.r8,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.logout_rounded, color: EgTheme.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final unreadAlerts = _alerts.where((a) => !(a['is_acknowledged'] as bool)).length;
    final pendingUsers = _users.where((u) => !u.isActive).length;

    return Container(
      decoration: BoxDecoration(
        color: EgTheme.bgCard,
        border: Border(top: BorderSide(color: EgTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _navItem(0, Icons.devices_rounded, Icons.devices_outlined, 'Devices'),
              _navItem(1, Icons.notifications_rounded, Icons.notifications_outlined, 'Alerts', badge: unreadAlerts),
              _navItem(2, Icons.people_rounded, Icons.people_outlined, 'Users', badge: pendingUsers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label, {int badge = 0}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? active : inactive,
                    color: isSelected ? EgTheme.accent : EgTheme.textMuted,
                    size: 24,
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: EgTheme.danger,
                          borderRadius: EgTheme.r32,
                        ),
                        child: Text('$badge',
                            style: EgTheme.body(9, color: Colors.white, weight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: EgTheme.body(11,
                  color: isSelected ? EgTheme.accent : EgTheme.textMuted,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TAB: DEVICES
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildDevicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Register Device'),
        const SizedBox(height: 12),
        _buildCard(child: Column(
          children: [
            _buildTextField(_deviceIdController, 'Device ID', Icons.vpn_key_outlined, hint: 'e.g. eggpod-01'),
            const SizedBox(height: 12),
            _buildTextField(_deviceNameController, 'Display Name', Icons.badge_outlined, hint: 'e.g. Incubator A'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _registerDevice,
                style: EgTheme.primaryButton(),
                icon: const Icon(Icons.add_rounded, color: Colors.black, size: 18),
                label: Text('Register Device', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ),
          ],
        )),
        const SizedBox(height: 24),
        _sectionLabel('Registered Devices (${_devices.length})'),
        const SizedBox(height: 12),
        if (_devices.isEmpty)
          _emptyState(Icons.device_hub_rounded, 'No devices registered yet.')
        else
          ..._devices.map(_buildDeviceRow),
      ],
    );
  }

  Widget _buildDeviceRow(Device d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: EgTheme.card(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: d.isActive ? EgTheme.success.withOpacity(0.1) : EgTheme.textMuted.withOpacity(0.1),
                borderRadius: EgTheme.r10,
              ),
              child: Icon(Icons.device_thermostat_rounded,
                  color: d.isActive ? EgTheme.success : EgTheme.textMuted, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: EgTheme.body(14, weight: FontWeight.w600)),
                  Text(d.deviceId, style: EgTheme.body(12, color: EgTheme.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: d.isActive ? EgTheme.success.withOpacity(0.1) : EgTheme.textMuted.withOpacity(0.1),
                borderRadius: EgTheme.r32,
              ),
              child: Text(
                d.isActive ? 'Active' : 'Offline',
                style: EgTheme.body(11, color: d.isActive ? EgTheme.success : EgTheme.textMuted, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _deleteDevice(d),
              borderRadius: EgTheme.r8,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.delete_outline_rounded, color: EgTheme.danger, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TAB: ALERTS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildAlertsTab() {
    final unread = _alerts.where((a) => !(a['is_acknowledged'] as bool)).toList();
    final read   = _alerts.where((a) =>  (a['is_acknowledged'] as bool)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Temperature Thresholds'),
        const SizedBox(height: 12),
        _buildCard(child: Column(
          children: [
            DropdownButtonFormField<Device>(
              value: _selectedRuleDevice,
              items: _devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name, style: EgTheme.body(14)))).toList(),
              onChanged: (v) {
                setState(() { _selectedRuleDevice = v; _liveSpots.clear(); _liveTemp = null; });
                _setupWebSocket();
              },
              decoration: EgTheme.inputDecoration('Target Device', icon: Icons.device_thermostat_outlined),
              dropdownColor: EgTheme.bgElevated,
              style: EgTheme.body(14),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildTextField(_minTempController, 'Min °C', Icons.arrow_downward_rounded,
                  keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_maxTempController, 'Max °C', Icons.arrow_upward_rounded,
                  keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createAlertRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EgTheme.warning,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  shape: const RoundedRectangleBorder(borderRadius: EgTheme.r12),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text('Save Thresholds', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        )),
        const SizedBox(height: 12),
        _buildLiveMonitor(),
        const SizedBox(height: 24),
        // Active alerts
        if (unread.isNotEmpty) ...[
          Row(children: [
            _sectionLabel('Active Alerts'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: EgTheme.danger.withOpacity(0.15), borderRadius: EgTheme.r32),
              child: Text('${unread.length}', style: EgTheme.body(11, color: EgTheme.danger, weight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          ...unread.map((a) => _buildAlertCard(a)),
          const SizedBox(height: 16),
        ],
        if (read.isNotEmpty) ...[
          _sectionLabel('Acknowledged'),
          const SizedBox(height: 10),
          ...read.map((a) => _buildAlertCard(a, dimmed: true)),
        ],
        if (_alerts.isEmpty)
          _emptyState(Icons.check_circle_outline_rounded, 'No alerts triggered yet.'),
      ],
    );
  }

  Widget _buildLiveMonitor() {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Live Monitor', style: EgTheme.body(14, weight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (_wsService.isConnected ? EgTheme.success : EgTheme.warning).withOpacity(0.1),
                borderRadius: EgTheme.r32,
              ),
              child: Text(
                _wsService.isConnected ? 'Connected' : 'Syncing...',
                style: EgTheme.body(11, color: _wsService.isConnected ? EgTheme.success : EgTheme.warning, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _liveTemp != null ? '${_liveTemp!.toStringAsFixed(1)}°C' : '--.-°C',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: tempColor(_liveTemp),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: _liveSpots.isEmpty
              ? Center(child: Text('Waiting for data...', style: EgTheme.body(12, color: EgTheme.textMuted)))
              : LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [LineChartBarData(
                    spots: _liveSpots,
                    isCurved: true,
                    color: EgTheme.accent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [EgTheme.accent.withOpacity(0.15), Colors.transparent],
                      ),
                    ),
                  )],
                )),
        ),
      ],
    ));
  }

  Widget _buildAlertCard(dynamic a, {bool dimmed = false}) {
    final isHigh = a['alert_type'] == 'high';
    final color  = isHigh ? EgTheme.danger : EgTheme.info;
    final time   = DateFormat('MMM d, HH:mm').format(DateTime.parse(a['triggered_at']));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: EgTheme.bgCard,
            borderRadius: EgTheme.r12,
            border: Border.all(color: dimmed ? EgTheme.border : color.withOpacity(0.4)),
            ...(dimmed ? {} : {'boxShadow': [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8)]}),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: EgTheme.r8),
                child: Icon(isHigh ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['message'] ?? '', style: EgTheme.body(13, weight: FontWeight.w500), maxLines: 2),
                    const SizedBox(height: 3),
                    Text(time, style: EgTheme.body(11, color: EgTheme.textMuted)),
                  ],
                ),
              ),
              if (!dimmed)
                TextButton(
                  onPressed: () => _acknowledgeAlert(a['id']),
                  style: TextButton.styleFrom(
                    foregroundColor: EgTheme.success,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: EgTheme.success),
                    shape: const RoundedRectangleBorder(borderRadius: EgTheme.r8),
                  ),
                  child: Text('ACK', style: EgTheme.body(12, color: EgTheme.success, weight: FontWeight.w600)),
                ),
              if (dimmed)
                const Icon(Icons.check_circle_rounded, color: EgTheme.success, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TAB: USERS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildUsersTab() {
    final pending = _users.where((u) => !u.isActive).toList();
    final active  = _users.where((u) =>  u.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          Row(children: [
            _sectionLabel('Pending Approval'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: EgTheme.accent.withOpacity(0.15),
                borderRadius: EgTheme.r32,
                border: Border.all(color: EgTheme.accent.withOpacity(0.4)),
              ),
              child: Text('${pending.length}',
                  style: EgTheme.body(11, color: EgTheme.accent, weight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          ...pending.map(_buildPendingUserRow),
          const SizedBox(height: 20),
        ],
        _sectionLabel('Active Users (${active.length})'),
        const SizedBox(height: 10),
        if (active.isEmpty)
          _emptyState(Icons.people_outline_rounded, 'No active users.')
        else
          ...active.map(_buildActiveUserRow),
      ],
    );
  }

  Widget _buildPendingUserRow(User u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: EgTheme.bgCard,
          borderRadius: EgTheme.r12,
          border: Border.all(color: EgTheme.accent.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _avatar(u.email, EgTheme.accent.withOpacity(0.15), EgTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.email, style: EgTheme.body(13, weight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  if (u.fullName != null)
                    Text(u.fullName!, style: EgTheme.body(12, color: EgTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _approveUser(u),
              style: ElevatedButton.styleFrom(
                backgroundColor: EgTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const RoundedRectangleBorder(borderRadius: EgTheme.r8),
                elevation: 0,
              ),
              child: Text('Approve', style: EgTheme.body(12, color: Colors.white, weight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _deleteUser(u),
              borderRadius: EgTheme.r8,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline_rounded, color: EgTheme.danger, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveUserRow(User u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: EgTheme.card(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _avatar(
              u.email,
              u.isSuperuser ? EgTheme.accent.withOpacity(0.15) : EgTheme.bgElevated,
              u.isSuperuser ? EgTheme.accent : EgTheme.textSecondary,
              icon: u.isSuperuser ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(u.email, style: EgTheme.body(13, weight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    if (u.isSuperuser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: EgTheme.accent.withOpacity(0.12),
                          borderRadius: EgTheme.r32,
                        ),
                        child: Text('Admin', style: EgTheme.body(10, color: EgTheme.accent, weight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  if (u.fullName != null)
                    Text(u.fullName!, style: EgTheme.body(12, color: EgTheme.textMuted)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: EgTheme.textMuted, size: 20),
              color: EgTheme.bgElevated,
              shape: const RoundedRectangleBorder(borderRadius: EgTheme.r12),
              onSelected: (v) {
                if (v == 'toggle') _toggleAdmin(u);
                if (v == 'delete') _deleteUser(u);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(u.isSuperuser ? Icons.person_remove_outlined : Icons.admin_panel_settings_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(u.isSuperuser ? 'Revoke Admin' : 'Make Admin', style: EgTheme.body(13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline_rounded, color: EgTheme.danger, size: 18),
                    const SizedBox(width: 10),
                    Text('Delete', style: EgTheme.body(13, color: EgTheme.danger)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  Widget _avatar(String email, Color bg, Color fg, {IconData? icon}) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: bg, borderRadius: EgTheme.r10),
      child: icon != null
          ? Icon(icon, color: fg, size: 18)
          : Center(
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {String? hint, TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      style: EgTheme.body(14),
      decoration: EgTheme.inputDecoration(label, icon: icon).copyWith(hintText: hint),
    );
  }

  Widget _buildCard({required Widget child}) => Container(
    decoration: EgTheme.card(),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  Widget _sectionLabel(String text) => Text(text, style: GoogleFonts.outfit(
    fontSize: 14, fontWeight: FontWeight.w600, color: EgTheme.textSecondary, letterSpacing: 0.5,
  ));

  Widget _emptyState(IconData icon, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: EgTheme.textMuted, size: 40),
        const SizedBox(height: 12),
        Text(msg, style: EgTheme.body(14, color: EgTheme.textMuted), textAlign: TextAlign.center),
      ],
    ),
  );
}

// Missing BorderRadius extension
extension on BorderRadius {
  static const BorderRadius r10 = BorderRadius.all(Radius.circular(10));
}
