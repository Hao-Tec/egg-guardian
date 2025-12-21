import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';

/// API service for communicating with the Egg Guardian backend.
class ApiService {
  String? _accessToken;
  String? _refreshToken;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Initialize tokens from storage.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  /// Save tokens to storage.
  Future<void> _saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', tokens.accessToken);
    await prefs.setString('refresh_token', tokens.refreshToken);
  }

  /// Clear tokens (logout).
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  /// Check if user is logged in.
  bool get isLoggedIn => _accessToken != null;

  /// Get authorization headers.
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// Make HTTP request with auto-refresh.
  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = requiresAuth
        ? _authHeaders
        : {'Content-Type': 'application/json'};

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // Auto-refresh on 401
    if (response.statusCode == 401 && _refreshToken != null && requiresAuth) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return _request(
          method,
          endpoint,
          body: body,
          requiresAuth: requiresAuth,
        );
      }
    }

    return response;
  }

  /// Refresh access token.
  Future<bool> _refreshTokens() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.refreshEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _saveTokens(tokens);
        return true;
      }
    } catch (_) {}

    await logout();
    return false;
  }

  // ============== Auth ==============

  /// Register a new user.
  Future<User> register(
    String email,
    String password, {
    String? fullName,
  }) async {
    final response = await _request(
      'POST',
      AppConfig.registerEndpoint,
      body: {
        'email': email,
        'password': password,
        if (fullName != null) 'full_name': fullName,
      },
    );

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Login user.
  Future<AuthTokens> login(String email, String password) async {
    final response = await _request(
      'POST',
      AppConfig.loginEndpoint,
      body: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final tokens = AuthTokens.fromJson(jsonDecode(response.body));
      await _saveTokens(tokens);
      return tokens;
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  // ============== Devices ==============

  /// Get all devices.
  Future<List<Device>> getDevices() async {
    final response = await _request('GET', AppConfig.devicesEndpoint);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((d) => Device.fromJson(d)).toList();
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Create a new device.
  Future<Device> createDevice(
    String deviceId,
    String name, {
    String? description,
  }) async {
    final response = await _request(
      'POST',
      AppConfig.devicesEndpoint,
      body: {
        'device_id': deviceId,
        'name': name,
        if (description != null) 'description': description,
      },
    );

    if (response.statusCode == 201) {
      return Device.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Get device telemetry history.
  Future<TelemetryHistory> getTelemetry(int deviceId, {int hours = 24}) async {
    final response = await _request(
      'GET',
      AppConfig.telemetryEndpoint(deviceId, hours: hours),
    );

    if (response.statusCode == 200) {
      return TelemetryHistory.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Get device alert rules.
  Future<List<AlertRule>> getAlertRules(int deviceId) async {
    final response = await _request('GET', AppConfig.rulesEndpoint(deviceId));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((r) => AlertRule.fromJson(r)).toList();
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Create alert rule.
  Future<AlertRule> createAlertRule(
    int deviceId,
    double tempMin,
    double tempMax,
  ) async {
    final response = await _request(
      'POST',
      AppConfig.rulesEndpoint(deviceId),
      body: {'temp_min': tempMin, 'temp_max': tempMax},
    );

    if (response.statusCode == 201) {
      return AlertRule.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Parse error message from response body.
  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data['detail'] is String) return data['detail'];
      if (data['detail'] is List) {
        return (data['detail'] as List)
            .map((e) => e['msg'] ?? e.toString())
            .join(', ');
      }
      return 'Unknown error';
    } catch (_) {
      return 'Unknown error';
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
