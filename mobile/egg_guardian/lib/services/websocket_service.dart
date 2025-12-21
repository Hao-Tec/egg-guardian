import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:egg_guardian/config.dart';
import 'package:egg_guardian/models.dart';

/// WebSocket service for real-time telemetry updates.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WsMessage>? _controller;
  String? _currentDeviceId;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  /// Stream of WebSocket messages.
  Stream<WsMessage>? get messageStream => _controller?.stream;

  /// Check if connected.
  bool get isConnected => _channel != null;

  /// Connect to a device's telemetry stream.
  Future<void> connect(String deviceId) async {
    if (_currentDeviceId == deviceId && _channel != null) {
      return; // Already connected
    }

    await disconnect();

    _currentDeviceId = deviceId;
    _isConnecting = true;
    _controller = StreamController<WsMessage>.broadcast();

    try {
      final uri = Uri.parse(
        '${AppConfig.wsBaseUrl}${AppConfig.wsEndpoint(deviceId)}',
      );
      _channel = WebSocketChannel.connect(uri);

      await _channel!.ready;

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            final message = WsMessage.fromJson(json);
            _controller?.add(message);
          } catch (e) {
            debugPrint('WS parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WS error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS connection closed');
          _scheduleReconnect();
        },
      );

      _isConnecting = false;
      debugPrint('WebSocket connected to $deviceId');
    } catch (e) {
      debugPrint('WS connect error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection attempt.
  void _scheduleReconnect() {
    if (_reconnectTimer != null || _currentDeviceId == null) return;

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
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

    await _channel?.sink.close();
    _channel = null;

    await _controller?.close();
    _controller = null;
  }

  /// Send ping to keep connection alive.
  void ping() {
    _channel?.sink.add(jsonEncode({'type': 'ping'}));
  }
}
