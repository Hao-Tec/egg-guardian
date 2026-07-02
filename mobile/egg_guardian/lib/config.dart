import 'dart:io' show Platform;

/// App configuration and constants.
class AppConfig {
  // ============== Server Configuration ==============
  
  /// Override this via command line: --dart-define=API_HOST=192.168.1.100
  /// Set to null to use automatic detection (emulator vs web).
  static const String? physicalDeviceServerIp = String.fromEnvironment('API_HOST', defaultValue: '');
  
  /// Server port (matches docker-compose API port)
  static const int serverPort = int.fromEnvironment('API_PORT', defaultValue: 8000);

  /// API Base URL — auto-detects platform.
  /// - Android emulator: 10.0.2.2 (maps to host machine's localhost)
  /// - Android physical device: uses [physicalDeviceServerIp]
  /// - Web/desktop: localhost
  static String get apiBaseUrl => 'http://$_serverHost:$serverPort';

  /// WebSocket Base URL — auto-detects platform.
  static String get wsBaseUrl => 'ws://$_serverHost:$serverPort';

  /// Resolved server host based on platform.
  static String get _serverHost {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // If a physical device IP is configured via dart-define, use it
        if (physicalDeviceServerIp != null && physicalDeviceServerIp!.isNotEmpty) {
          return physicalDeviceServerIp!;
        }
        // Default: Android emulator loopback to host machine
        return Platform.isAndroid ? '10.0.2.2' : 'localhost';
      }
    } catch (_) {
      // Platform not available (e.g., web) — fall through to localhost
    }
    return 'localhost';
  }

  // ============== API Endpoints ==============

  static const String healthEndpoint = '/healthz';
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String registerEndpoint = '/api/v1/auth/register';
  static const String meEndpoint = '/api/v1/auth/me';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String devicesEndpoint = '/api/v1/devices';
  static const String usersEndpoint = '/api/v1/users';
  static const String alertsEndpoint = '/api/v1/alerts';

  /// WebSocket endpoint pattern
  static String wsEndpoint(String deviceId) => '/api/v1/ws/$deviceId';

  /// Telemetry endpoint
  static String telemetryEndpoint(int deviceId, {int hours = 24}) =>
      '/api/v1/devices/$deviceId/telemetry?hours=$hours';

  /// Alert rules endpoint
  static String rulesEndpoint(int deviceId) =>
      '/api/v1/devices/$deviceId/rules';

  // ============== Timeouts ==============

  /// HTTP request timeout
  static const Duration httpTimeout = Duration(seconds: 15);

  /// WebSocket reconnect delay
  static const Duration wsReconnectDelay = Duration(seconds: 3);

  /// Device list auto-refresh interval
  static const Duration deviceRefreshInterval = Duration(seconds: 5);

  /// Device detail polling interval (fallback when WebSocket is down)
  static const Duration telemetryPollInterval = Duration(seconds: 5);
}
