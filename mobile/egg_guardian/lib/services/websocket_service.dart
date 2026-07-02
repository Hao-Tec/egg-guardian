import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';

/// WebSocket service for real-time telemetry updates.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<WsMessage> _controller = StreamController<WsMessage>.broadcast();
  String? _currentDeviceId;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isConnected = false;

  /// Stream of WebSocket messages.
  Stream<WsMessage> get messageStream => _controller.stream;

  /// Check if connected.
  bool get isConnected => _isConnected;

  /// Connect to a device's telemetry stream.
  Future<void> connect(String deviceId) async {
    if (_currentDeviceId == deviceId && _isConnected) {
      return; // Already connected to this device
    }

    // Prevent concurrent connection attempts
    if (_isConnecting) return;

    await disconnect();

    _currentDeviceId = deviceId;
    _isConnecting = true;

    try {
      final wsUrl = '${AppConfig.wsBaseUrl}${AppConfig.wsEndpoint(deviceId)}';
      debugPrint('WebSocket connecting to: $wsUrl');
      
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;
      _isConnected = true;
      _isConnecting = false;

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            final message = WsMessage.fromJson(json);
            _controller.add(message);
          } catch (e) {
            debugPrint('WS parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WS error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      debugPrint('WebSocket connected to $deviceId');
    } catch (e) {
      debugPrint('WS connect error: $e');
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection attempt.
  void _scheduleReconnect() {
    if (_reconnectTimer != null || _currentDeviceId == null) return;

    _reconnectTimer = Timer(AppConfig.wsReconnectDelay, () {
      _reconnectTimer = null;
      if (_currentDeviceId != null) {
        connect(_currentDeviceId!);
      }
    });
  }

  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentDeviceId = null;
    _isConnected = false;
    _isConnecting = false;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    // We never close the broadcast controller so global listeners stay active
  }

  /// Send ping to keep connection alive.
  void ping() {
    if (_isConnected) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        _isConnected = false;
      }
    }
  }
}
