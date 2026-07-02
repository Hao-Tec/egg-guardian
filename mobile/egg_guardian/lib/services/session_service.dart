import 'dart:async';
import 'package:flutter/material.dart';

/// Session service for managing user activity and auto-logout.
class SessionService with WidgetsBindingObserver {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // Inactivity timeout (15 minutes)
  static const Duration inactivityTimeout = Duration(minutes: 15);
  
  Timer? _inactivityTimer;
  VoidCallback? _onSessionExpired;
  bool _isActive = false;
  DateTime _lastActivity = DateTime.now();

  /// Initialize session tracking with callback for session expiry.
  void init({required VoidCallback onSessionExpired}) {
    _onSessionExpired = onSessionExpired;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Start session tracking.
  void startSession() {
    _isActive = true;
    recordActivity();
  }

  /// Stop session tracking.
  void stopSession() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Record user activity (resets inactivity timer).
  void recordActivity() {
    _lastActivity = DateTime.now();
    if (_isActive) {
      _resetInactivityTimer();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      triggerSessionExpiry();
    });
  }

  /// Manually trigger session expiry (e.g., on token refresh failure).
  void triggerSessionExpiry() {
    if (_isActive) {
      _isActive = false;
      _onSessionExpired?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isActive) {
      // Check if timeout occurred while in background
      final now = DateTime.now();
      if (now.difference(_lastActivity) >= inactivityTimeout) {
        triggerSessionExpiry();
      } else {
        // Resume timer with remaining time
        _resetInactivityTimer();
      }
    }
  }

  /// Dispose resources.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopSession();
    _onSessionExpired = null;
  }
}

/// Widget that wraps the app and tracks user activity.
class ActivityDetector extends StatelessWidget {
  final Widget child;

  const ActivityDetector({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => SessionService().recordActivity(),
      onPointerMove: (_) => SessionService().recordActivity(),
      child: child,
    );
  }
}
