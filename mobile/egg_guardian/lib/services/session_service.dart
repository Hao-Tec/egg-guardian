import 'dart:async';
import 'package:flutter/material.dart';

/// Session service for managing user activity and auto-logout.
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // Inactivity timeout (15 minutes)
  static const Duration inactivityTimeout = Duration(minutes: 15);
  
  Timer? _inactivityTimer;
  VoidCallback? _onSessionExpired;
  bool _isActive = false;

  /// Initialize session tracking with callback for session expiry.
  void init({required VoidCallback onSessionExpired}) {
    _onSessionExpired = onSessionExpired;
  }

  /// Start session tracking.
  void startSession() {
    _isActive = true;
    _resetInactivityTimer();
  }

  /// Stop session tracking.
  void stopSession() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Record user activity (resets inactivity timer).
  void recordActivity() {
    if (_isActive) {
      _resetInactivityTimer();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      if (_isActive) {
        _isActive = false;
        _onSessionExpired?.call();
      }
    });
  }

  /// Dispose resources.
  void dispose() {
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
