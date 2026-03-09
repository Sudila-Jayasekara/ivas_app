import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String _tag = '[WebSocket]';
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  void connect(String sessionId, {String host = 'localhost:9999'}) {
    final uri =
        Uri.parse('ws://$host/api/v1/assessments/sessions/$sessionId/voice');
    debugPrint('$_tag Connecting to $uri');
    _channel = WebSocketChannel.connect(uri);
    _isConnected = true;
    debugPrint('$_tag Connected ✓');

    _channel!.stream.listen(
      (data) {
        debugPrint('$_tag ◀ Received: $data');
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          debugPrint('$_tag   Parsed message type: ${message['type']}');
          _messageController.add(message);
        } catch (e) {
          debugPrint('$_tag ✗ Parse error: $e');
          _messageController.addError('Failed to parse message: $e');
        }
      },
      onError: (error) {
        debugPrint('$_tag ✗ Stream error: $error');
        _isConnected = false;
        _messageController.addError(error);
      },
      onDone: () {
        debugPrint('$_tag Stream closed (onDone)');
        _isConnected = false;
      },
    );
  }

  void sendStartSession({
    required String questionInstanceId,
    required String questionText,
  }) {
    debugPrint(
        '$_tag ▶ sendStartSession(qid=$questionInstanceId, q="${questionText.length > 50 ? '${questionText.substring(0, 50)}...' : questionText}")');
    _send({
      'type': 'start_session',
      'question_instance_id': questionInstanceId,
      'question_text': questionText,
    });
  }

  void sendMessage({
    required String text,
    String? questionInstanceId,
    String? audioData,
  }) {
    debugPrint(
        '$_tag ▶ sendMessage(text="${text.length > 80 ? '${text.substring(0, 80)}...' : text}", qid=$questionInstanceId, hasAudio=${audioData != null})');
    _send({
      'type': 'message',
      'text': text,
      if (questionInstanceId != null)
        'question_instance_id': questionInstanceId,
      if (audioData != null) 'audio_data': audioData,
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      final encoded = jsonEncode(data);
      debugPrint('$_tag ▶ Sending ${encoded.length} chars');
      _channel!.sink.add(encoded);
    } else {
      debugPrint(
          '$_tag ⚠ Cannot send — not connected (channel=${_channel != null}, connected=$_isConnected)');
    }
  }

  void disconnect() {
    debugPrint('$_tag Disconnecting...');
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    debugPrint('$_tag Disconnected');
  }

  void dispose() {
    debugPrint('$_tag dispose() called');
    disconnect();
    _messageController.close();
  }
}
