/// App configuration and constants.
class AppConfig {
  // API Base URL - change for production
  static const String apiBaseUrl = 'http://localhost:8000';
  
  // WebSocket URL
  static const String wsBaseUrl = 'ws://localhost:8000';
  
  // API Endpoints
  static const String healthEndpoint = '/healthz';
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String registerEndpoint = '/api/v1/auth/register';
  static const String refreshEndpoint = '/api/v1/auth/refresh';
  static const String devicesEndpoint = '/api/v1/devices';
  
  // WebSocket endpoint pattern
  static String wsEndpoint(String deviceId) => '/api/v1/ws/$deviceId';
  
  // Telemetry endpoint
  static String telemetryEndpoint(int deviceId, {int hours = 24}) =>
      '/api/v1/devices/$deviceId/telemetry?hours=$hours';
  
  // Alert rules endpoint
  static String rulesEndpoint(int deviceId) =>
      '/api/v1/devices/$deviceId/rules';
  
  // Temperature thresholds for display
  static const double tempMin = 35.0;
  static const double tempMax = 39.0;
  static const double tempOptimal = 37.5;
}
