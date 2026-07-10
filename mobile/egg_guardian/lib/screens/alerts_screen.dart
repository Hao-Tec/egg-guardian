import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadAlerts(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!silent && mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final alerts = await ApiService().getTriggeredAlerts();
      if (mounted) setState(() { _alerts = alerts; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Unable to load alerts.'; _isLoading = false; });
    }
  }

  Future<void> _acknowledge(int alertId) async {
    try {
      await ApiService().acknowledgeAlert(alertId);
      _loadAlerts(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to acknowledge alert', style: EgTheme.body(13))),
        );
      }
    }
  }

  Future<void> _acknowledgeAll() async {
    final unread = _alerts.where((a) => a['is_acknowledged'] == false).toList();
    if (unread.isEmpty) return;
    try {
      for (final a in unread) {
        await ApiService().acknowledgeAlert(a['id'] as int);
      }
      _loadAlerts(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All alerts acknowledged', style: EgTheme.body(13)),
            backgroundColor: EgTheme.success,
          ),
        );
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final unreadCount = _alerts.where((a) => a['is_acknowledged'] == false).length;

    return Scaffold(
      backgroundColor: EgTheme.bgBase,
      body: Column(
        children: [
          _buildHeader(unreadCount),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
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
              const Icon(Icons.notifications_rounded, color: EgTheme.accent, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alerts', style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w700, color: EgTheme.textPrimary,
                    )),
                    Text(
                      unreadCount > 0 ? '$unreadCount unacknowledged' : 'All clear',
                      style: EgTheme.body(12, color: unreadCount > 0 ? EgTheme.danger : EgTheme.success),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: _acknowledgeAll,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: EgTheme.accent),
                  label: Text('Ack All', style: EgTheme.body(13, color: EgTheme.accent, weight: FontWeight.w600)),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: EgTheme.textSecondary, size: 22),
                onPressed: _loadAlerts,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: EgTheme.accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off_rounded, color: EgTheme.danger, size: 40),
            const SizedBox(height: 16),
            Text(_error!, style: EgTheme.body(14, color: EgTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAlerts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: EgTheme.success.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: EgTheme.success, size: 52),
            ),
            const SizedBox(height: 20),
            Text('No alerts triggered', style: EgTheme.heading(18)),
            const SizedBox(height: 8),
            Text('All incubators are operating within safe limits.',
                style: EgTheme.body(14, color: EgTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      color: EgTheme.accent,
      backgroundColor: EgTheme.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _alerts.length,
        itemBuilder: (ctx, i) => _buildAlertCard(_alerts[i]),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isHigh = alert['alert_type'] == 'high';
    final isAcked = alert['is_acknowledged'] == true;
    final temp = (alert['temp_c'] as num?)?.toDouble();
    final triggeredAt = DateTime.tryParse(alert['triggered_at'] ?? '');
    final timeStr = triggeredAt != null
        ? _formatTime(triggeredAt)
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: EgTheme.bgCard,
          borderRadius: EgTheme.r16,
          border: Border.all(
            color: isAcked
                ? EgTheme.border
                : (isHigh ? EgTheme.danger.withOpacity(0.4) : EgTheme.warning.withOpacity(0.4)),
            width: isAcked ? 1 : 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isAcked
                      ? EgTheme.bgElevated
                      : (isHigh ? EgTheme.danger.withOpacity(0.12) : EgTheme.warning.withOpacity(0.12)),
                  borderRadius: EgTheme.r10,
                ),
                child: Icon(
                  isAcked
                      ? Icons.check_circle_rounded
                      : (isHigh ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                  color: isAcked
                      ? EgTheme.textMuted
                      : (isHigh ? EgTheme.danger : EgTheme.warning),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert['message'] ?? 'Temperature alert',
                            style: EgTheme.body(14,
                                weight: FontWeight.w600,
                                color: isAcked ? EgTheme.textSecondary : EgTheme.textPrimary),
                          ),
                        ),
                        if (temp != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isHigh
                                  ? EgTheme.danger.withOpacity(0.1)
                                  : EgTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${temp.toStringAsFixed(1)}°C',
                              style: EgTheme.body(12,
                                  weight: FontWeight.w700,
                                  color: isHigh ? EgTheme.danger : EgTheme.warning),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(timeStr,
                        style: EgTheme.body(11, color: EgTheme.textMuted)),
                    if (isAcked) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_rounded, size: 12, color: EgTheme.success),
                          const SizedBox(width: 4),
                          Text('Acknowledged', style: EgTheme.body(11, color: EgTheme.success)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // ACK button
              if (!isAcked) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _acknowledge(alert['id'] as int),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: EgTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EgTheme.success.withOpacity(0.3)),
                    ),
                    child: Text('ACK',
                        style: EgTheme.body(11,
                            weight: FontWeight.w700, color: EgTheme.success)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
