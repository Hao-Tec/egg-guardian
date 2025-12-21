/// Data models for the Egg Guardian app.
library;

class Device {
  final int id;
  final String deviceId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      deviceId: json['device_id'],
      name: json['name'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class Telemetry {
  final int id;
  final double tempC;
  final DateTime recordedAt;
  final DateTime receivedAt;

  Telemetry({
    required this.id,
    required this.tempC,
    required this.recordedAt,
    required this.receivedAt,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      id: json['id'],
      tempC: (json['temp_c'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at']),
      receivedAt: DateTime.parse(json['received_at']),
    );
  }
}

class TelemetryHistory {
  final String deviceId;
  final String deviceName;
  final List<Telemetry> readings;
  final int count;

  TelemetryHistory({
    required this.deviceId,
    required this.deviceName,
    required this.readings,
    required this.count,
  });

  factory TelemetryHistory.fromJson(Map<String, dynamic> json) {
    return TelemetryHistory(
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      readings: (json['readings'] as List)
          .map((r) => Telemetry.fromJson(r))
          .toList(),
      count: json['count'],
    );
  }
}

class AlertRule {
  final int id;
  final int deviceId;
  final double tempMin;
  final double tempMax;
  final bool isActive;
  final DateTime createdAt;

  AlertRule({
    required this.id,
    required this.deviceId,
    required this.tempMin,
    required this.tempMax,
    required this.isActive,
    required this.createdAt,
  });

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id'],
      deviceId: json['device_id'],
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}

class User {
  final int id;
  final String email;
  final String? fullName;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      isActive: json['is_active'] ?? true,
    );
  }
}

/// WebSocket message types
class WsMessage {
  final String type;
  final String deviceId;
  final Map<String, dynamic> data;

  WsMessage({required this.type, required this.deviceId, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: json['type'],
      deviceId: json['device_id'] ?? '',
      data: json['data'] ?? {},
    );
  }

  double? get tempC => data['temp_c'] as double?;
  String? get alertType => data['alert_type'] as String?;
  String? get message => data['message'] as String?;
}
