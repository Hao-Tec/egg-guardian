import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';

import 'package:egg_guardian/services/session_service.dart';

/// API service for communicating with the Egg Guardian backend.
class ApiService {
  String? _accessToken;
  String? _refreshToken;
  bool _isAdmin = false;
  bool _isRefreshing = false; // Prevents infinite refresh loops
  bool _shouldPersist = false;
  bool isOfflineMode = false; // Tracks if the last request used cached data

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Initialize tokens from storage.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _shouldPersist = prefs.getBool('should_persist') ?? false;
    
    if (_shouldPersist) {
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      _isAdmin = prefs.getBool('is_admin') ?? false;
    }
  }

  /// Save tokens and role to storage.
  Future<void> _saveTokens(AuthTokens tokens, {bool? isAdmin, bool persist = true}) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _shouldPersist = persist;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('should_persist', persist);
    
    if (persist) {
      await prefs.setString('access_token', tokens.accessToken);
      await prefs.setString('refresh_token', tokens.refreshToken);
      if (isAdmin != null) {
        _isAdmin = isAdmin;
        await prefs.setBool('is_admin', isAdmin);
      } else {
        // If isAdmin is null, preserve current _isAdmin status in storage
        await prefs.setBool('is_admin', _isAdmin);
      }
    } else {
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('is_admin');
    }
  }

  /// Clear tokens and role (logout).
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _isAdmin = false;
    _shouldPersist = false;
    
    SessionService().stopSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('is_admin');
    await prefs.setBool('should_persist', false);
  }

  /// Check if user is logged in.
  bool get isLoggedIn => _accessToken != null;

  /// Check if user is admin.
  bool get isAdmin => _isAdmin;

  /// Check if the session should be persisted (Remember Me).
  bool get shouldPersist => _shouldPersist;

  /// Update FCM token on the backend
  Future<bool> updateFcmToken(String token) async {
    try {
      final response = await _request(
        'POST',
        '/auth/fcm-token',
        body: {'token': token},
        requiresAuth: true,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
      return false;
    }
  }

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
    try {
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers)
              .timeout(AppConfig.httpTimeout);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(AppConfig.httpTimeout);
          break;
        case 'PATCH':
          response = await http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(AppConfig.httpTimeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers)
              .timeout(AppConfig.httpTimeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your network connection.');
    }

    // Auto-refresh on 401 (with guard against infinite loop)
    if (response.statusCode == 401 &&
        _refreshToken != null &&
        requiresAuth &&
        !_isRefreshing) {
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

  /// Refresh access token (guarded against concurrent calls).
  Future<bool> _refreshTokens() async {
    if (_refreshToken == null || _isRefreshing) return false;

    _isRefreshing = true;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.refreshEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(jsonDecode(response.body));
        await _saveTokens(tokens, persist: _shouldPersist);
        return true;
      }

      await logout();
      SessionService().triggerSessionExpiry();
      return false;
    } catch (_) {
      await logout();
      SessionService().triggerSessionExpiry();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ============== Auth ==============

  /// Register a new user.
  Future<User> register(
    String email,
    String password, {
    String? fullName,
    String? jobRole,
  }) async {
    final response = await _request(
      'POST',
      AppConfig.registerEndpoint,
      body: {
        'email': email,
        'password': password,
        if (fullName != null) 'full_name': fullName,
        if (jobRole != null) 'job_role': jobRole,
      },
    );

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Login user.
  Future<AuthTokens> login(String email, String password, {bool rememberMe = true}) async {
    final response = await _request(
      'POST',
      AppConfig.loginEndpoint,
      body: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final tokens = AuthTokens.fromJson(jsonDecode(response.body));
      await _saveTokens(tokens, persist: rememberMe);
      return tokens;
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Request a password reset email.
  Future<void> forgotPassword(String email) async {
    await _request(
      'POST',
      '/api/v1/auth/forgot-password',
      body: {'email': email},
    );
    // Always succeeds (server never reveals if email exists)
  }

  /// Reset password using the token from email.
  Future<void> resetPassword(String token, String newPassword) async {
    final response = await _request(
      'POST',
      '/api/v1/auth/reset-password',
      body: {'token': token, 'new_password': newPassword},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  /// Update the stored admin status.
  Future<void> setAdminStatus(bool isAdmin) async {
    _isAdmin = isAdmin;
    if (_shouldPersist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin', isAdmin);
    }
  }

  /// Get current user profile.
  Future<User> getCurrentUser() async {
    final response = await _request('GET', AppConfig.meEndpoint, requiresAuth: true);

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  // ============== Devices ==============

  /// Get all devices.
  Future<List<Device>> getDevices() async {
    try {
      final response = await _request('GET', AppConfig.devicesEndpoint, requiresAuth: true);

      if (response.statusCode == 200) {
        isOfflineMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_devices', response.body);
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((d) => Device.fromJson(d)).toList();
      }
      throw ApiException(response.statusCode, _parseError(response.body));
    } catch (e) {
      // Fallback to cache on network failure
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_devices');
      if (cached != null && (e is! ApiException || e.statusCode == 0)) {
        isOfflineMode = true;
        final List<dynamic> data = jsonDecode(cached);
        return data.map((d) => Device.fromJson(d)).toList();
      }
      rethrow;
    }
  }

  /// Create a new device.
  Future<Device> createDevice(String deviceId, String name) async {
    final response = await _request(
      'POST',
      AppConfig.devicesEndpoint,
      requiresAuth: true,
      body: {'device_id': deviceId, 'name': name},
    );
    if (response.statusCode == 201) {
      return Device.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Delete a device.
  Future<void> deleteDevice(int deviceId) async {
    final response = await _request('DELETE', '${AppConfig.devicesEndpoint}/$deviceId', requiresAuth: true);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  // ============== Users (Admin Only) ==============

  /// Get all registered users.
  Future<List<User>> getUsers() async {
    final response = await _request('GET', AppConfig.usersEndpoint, requiresAuth: true);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((u) => User.fromJson(u)).toList();
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Toggle admin status for a user.
  Future<User> toggleAdminStatus(int userId) async {
    final response = await _request('PATCH', '${AppConfig.usersEndpoint}/$userId/toggle-admin', requiresAuth: true);
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Delete a user.
  Future<void> deleteUser(int userId) async {
    final response = await _request('DELETE', '${AppConfig.usersEndpoint}/$userId', requiresAuth: true);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  /// Approve a pending user account.
  Future<User> approveUser(int userId) async {
    final response = await _request('PATCH', '${AppConfig.usersEndpoint}/$userId/approve', requiresAuth: true);
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  // ============== Alerts ==============

  /// Get triggered alerts.
  Future<List<dynamic>> getTriggeredAlerts({bool unacknowledgedOnly = false}) async {
    final endpoint = unacknowledgedOnly
        ? '${AppConfig.alertsEndpoint}?unacknowledged_only=true'
        : AppConfig.alertsEndpoint;
    final response = await _request('GET', endpoint, requiresAuth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException(response.statusCode, _parseError(response.body));
  }

  /// Acknowledge an alert.
  Future<void> acknowledgeAlert(int alertId) async {
    final response = await _request('PATCH', '${AppConfig.alertsEndpoint}/$alertId/acknowledge', requiresAuth: true);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }
  }

  /// Get device telemetry history.
  Future<TelemetryHistory> getTelemetry(int deviceId, {int hours = 24, int? limit}) async {
    try {
      final response = await _request(
        'GET',
        AppConfig.telemetryEndpoint(deviceId, hours: hours, limit: limit),
        requiresAuth: true,
      );

      if (response.statusCode == 200) {
        isOfflineMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_telemetry_$deviceId', response.body);
        return TelemetryHistory.fromJson(jsonDecode(response.body));
      }
      throw ApiException(response.statusCode, _parseError(response.body));
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_telemetry_$deviceId');
      if (cached != null && (e is! ApiException || e.statusCode == 0)) {
        isOfflineMode = true;
        return TelemetryHistory.fromJson(jsonDecode(cached));
      }
      rethrow;
    }
  }

  /// Get device alert rules.
  Future<List<AlertRule>> getAlertRules(int deviceId) async {
    final response = await _request('GET', AppConfig.rulesEndpoint(deviceId), requiresAuth: true);

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
      requiresAuth: true,
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
