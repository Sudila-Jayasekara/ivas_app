import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import '../models/session.dart';

/// States for the live viva — simplified for bidirectional streaming.
/// Gemini's VAD handles turn-taking automatically.
enum LiveVivaState {
  idle,
  connecting,
  active, // Conversation is live — audio flows both ways
  evaluating, // Viva done, AI is evaluating responses
  complete, // Assessment done
  error,
}

class LiveVivaViewModel extends ChangeNotifier {
  static const String _tag = '[LiveVivaVM]';

  LiveVivaState _state = LiveVivaState.idle;
  String? _sessionId;
  int _totalQuestions = 0;
  int _questionsScored = 0;
  double _totalScore = 0;
  String? _error;
  bool _geminiSpeaking = false;
  String? _lastTranscript;

  // Completion
  double? _finalScore;
  double? _maxScore;
  List<CompetencySummary>? _competencySummary;

  // Audio
  AudioRecorder? _recorder;
  StreamSubscription? _recordStreamSub;
  WebSocketChannel? _channel;
  bool _isStreaming = false;

  // PCM playback via flutter_sound
  FlutterSoundPlayer? _player;
  bool _playerReady = false;
  bool _streamStarting = false; // lock to prevent concurrent stream starts
  final List<Uint8List> _audioQueue = [];
  bool _drainingAudio = false;

  // Getters
  LiveVivaState get state => _state;
  String? get sessionId => _sessionId;
  int get totalQuestions => _totalQuestions;
  int get questionsScored => _questionsScored;
  double get totalScore => _totalScore;
  String? get error => _error;
  double? get finalScore => _finalScore;
  double? get maxScore => _maxScore;
  List<CompetencySummary>? get competencySummary => _competencySummary;
  double get progress =>
      _totalQuestions > 0 ? _questionsScored / _totalQuestions : 0;
  bool get geminiSpeaking => _geminiSpeaking;
  String? get lastTranscript => _lastTranscript;
  bool get isMicEnabled => _isStreaming;

  void _setState(LiveVivaState newState) {
    debugPrint('$_tag State: $_state => $newState');
    _state = newState;
    notifyListeners();
  }

  /// Initialize the PCM streaming player (24kHz, 16-bit, mono — Gemini output)
  /// Only opens the player — the stream is started lazily when audio arrives.
  Future<void> _initPcmPlayer() async {
    if (_playerReady) return;
    try {
      _player = FlutterSoundPlayer(logLevel: Level.warning);
      await _player!.openPlayer();
      _playerReady = true;
      debugPrint('$_tag PCM player opened (flutter_sound)');
    } catch (e) {
      debugPrint('$_tag PCM player init error: $e');
    }
  }

  /// Ensure the player stream is active (start or restart as needed).
  Future<void> _ensurePlayerStream() async {
    if (_player == null || !_playerReady) return;
    if (_player!.isPlaying || _streamStarting) return;
    _streamStarting = true;
    try {
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        sampleRate: 24000,
        numChannels: 1,
        interleaved: true,
        bufferSize: 8192,
      );
      debugPrint('$_tag PCM player stream started (24kHz mono)');
    } catch (e) {
      debugPrint('$_tag PCM player stream start error: $e');
    } finally {
      _streamStarting = false;
    }
  }

  /// Flush playback buffer (used for interrupts/barge-in)
  Future<void> _flushPlayerBuffer() async {
    _audioQueue.clear();
    try {
      if (_player != null && _player!.isPlaying) {
        await _player!.stopPlayer();
      }
      // Stream will restart lazily on next audio data
    } catch (e) {
      debugPrint('$_tag PCM player flush error: $e');
    }
  }

  /// Queue audio for sequential playback — prevents chunk interleaving.
  void _queueAudio(Uint8List chunk) {
    _audioQueue.add(chunk);
    _drainAudioQueue();
  }

  /// Single consumer: feeds queued audio chunks one at a time, in order.
  Future<void> _drainAudioQueue() async {
    if (_drainingAudio) return; // already draining
    _drainingAudio = true;
    try {
      await _ensurePlayerStream();
      while (_audioQueue.isNotEmpty) {
        final chunk = _audioQueue.removeAt(0);
        if (_player != null && _player!.isPlaying) {
          await _player!.feedFromStream(chunk);
        }
      }
    } catch (e) {
      debugPrint('$_tag PCM feed error: $e');
    } finally {
      _drainingAudio = false;
    }
  }

  /// Start a live viva session
  Future<void> startLiveViva({
    required String assignmentId,
    required String studentId,
    required String studentName,
    String host = 'localhost:9999',
  }) async {
    debugPrint('$_tag startLiveViva(assignment=$assignmentId)');
    _setState(LiveVivaState.connecting);
    _error = null;
    _questionsScored = 0;
    _totalScore = 0;
    _finalScore = null;
    _maxScore = null;
    _competencySummary = null;
    _geminiSpeaking = false;
    _lastTranscript = null;

    try {
      await _initPcmPlayer();

      // Configure audio session for simultaneous play + record
      final audioSession = await AudioSession.instance;
      await audioSession.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      await audioSession.setActive(true);
      debugPrint('$_tag Audio session configured');

      // Connect WebSocket
      final uri = Uri.parse('ws://$host/api/v1/assessments/sessions/live');
      debugPrint('$_tag Connecting to $uri');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('$_tag WebSocket error: $error');
          _error = 'Connection lost: $error';
          _stopStreaming(sendMicOff: false);
          _setState(LiveVivaState.error);
        },
        onDone: () {
          debugPrint('$_tag WebSocket closed (state=$_state)');
          if (_state != LiveVivaState.complete &&
              _state != LiveVivaState.error) {
            _stopStreaming(sendMicOff: false);
            _error = 'Connection closed unexpectedly';
            _setState(LiveVivaState.error);
          }
        },
      );

      // Send start message
      _channel!.sink.add(jsonEncode({
        'type': 'start',
        'assignment_id': assignmentId,
        'student_id': studentId,
        'student_name': studentName,
      }));

      debugPrint('$_tag Start message sent');
    } catch (e) {
      debugPrint('$_tag Failed to connect: $e');
      _error = 'Failed to connect: $e';
      _setState(LiveVivaState.error);
    }
  }

  void _handleMessage(dynamic data) async {
    // Binary = PCM audio chunk from Gemini → queue for sequential playback
    if (data is List<int> || data is Uint8List) {
      if (!_playerReady || _state != LiveVivaState.active) return;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      if (bytes.length < 2) return;

      // Ensure even byte count (Int16 = 2 bytes per sample)
      final usableLen = bytes.length - (bytes.length % 2);
      final chunk = Uint8List.fromList(bytes.sublist(0, usableLen));
      _queueAudio(chunk);
      return;
    }

    if (data is! String) return;

    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      debugPrint('$_tag Received: $type');

      switch (type) {
        case 'ready':
          _sessionId = msg['session_id'] as String?;
          _totalQuestions = msg['total_questions'] as int? ?? 0;
          debugPrint('$_tag Session ready: $_sessionId');
          // Go active and wait for student to enable mic from UI.
          _geminiSpeaking = true; // Gemini will speak the greeting first
          _setState(LiveVivaState.active);
          debugPrint('$_tag Ready for manual mic start');
          break;

        case 'gemini_speaking':
          _geminiSpeaking = true;
          notifyListeners();
          break;

        case 'turn_end':
          // Gemini finished speaking — student's turn detected by VAD
          debugPrint('$_tag Gemini turn ended');
          _geminiSpeaking = false;
          notifyListeners();
          break;

        case 'interrupted':
          // Student interrupted Gemini (barge-in) — flush playback buffer
          debugPrint('$_tag Gemini interrupted by student');
          _geminiSpeaking = false;
          await _flushPlayerBuffer();
          notifyListeners();
          break;

        case 'transcript':
          // What Gemini heard the student say
          _lastTranscript = msg['text'] as String?;
          debugPrint('$_tag Transcript: $_lastTranscript');
          notifyListeners();
          break;

        case 'output_transcription':
          // What Gemini is saying (text version of audio)
          final oText = msg['text'] as String?;
          if (oText != null) {
            debugPrint('$_tag Output transcription: $oText');
          }
          break;

        case 'evaluating':
          debugPrint('$_tag Evaluating...');
          _stopStreaming();
          _setState(LiveVivaState.evaluating);
          break;

        case 'complete':
          _finalScore = (msg['final_score'] as num?)?.toDouble();
          _maxScore = (msg['max_score'] as num?)?.toDouble();
          if (msg['competency_summary'] != null) {
            _competencySummary = (msg['competency_summary'] as List)
                .map((e) =>
                    CompetencySummary.fromJson(e as Map<String, dynamic>))
                .toList();
          }
          debugPrint('$_tag Complete! score=$_finalScore/$_maxScore');
          _stopStreaming();
          _setState(LiveVivaState.complete);
          break;

        case 'error':
          _error = msg['message'] as String? ?? 'Unknown error';
          debugPrint('$_tag Error: $_error');
          _stopStreaming();
          _setState(LiveVivaState.error);
          break;
      }
    } catch (e) {
      debugPrint('$_tag Message parse error: $e');
    }
  }

  /// Start streaming mic audio to the server — runs continuously
  Future<void> _startStreaming() async {
    if (_isStreaming) return;
    debugPrint('$_tag Starting mic stream...');

    try {
      _recorder = AudioRecorder();
      final hasPerms = await _recorder!.hasPermission();
      if (!hasPerms) {
        debugPrint('$_tag Mic permission denied');
        _error = 'Microphone permission required';
        _setState(LiveVivaState.error);
        return;
      }

      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _isStreaming = true;
      int chunkCount = 0;

      _recordStreamSub = stream.listen(
        (chunk) {
          chunkCount++;
          if (chunkCount <= 3 || chunkCount % 200 == 0) {
            debugPrint('$_tag Mic #$chunkCount: ${chunk.length}B');
          }
          if (_channel != null && chunk.isNotEmpty) {
            _channel!.sink.add(chunk);
          }
        },
        onError: (e) {
          debugPrint('$_tag Mic stream error: $e');
        },
      );

      debugPrint('$_tag Mic streaming started');
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag Failed to start mic: $e');
      _error = 'Failed to start microphone: $e';
      _setState(LiveVivaState.error);
    }
  }

  Future<void> _stopStreaming({bool sendMicOff = true}) async {
    if (!_isStreaming) return;
    debugPrint('$_tag Stopping mic...');
    _isStreaming = false;
    // Signal server that mic input has ended so Gemini can process the answer
    if (sendMicOff && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'mic_off'}));
      } catch (_) {}
    }
    await _recordStreamSub?.cancel();
    _recordStreamSub = null;
    try {
      await _recorder?.stop();
      await _recorder?.dispose();
    } catch (e) {
      debugPrint('$_tag Recorder cleanup error: $e');
    }
    _recorder = null;
    notifyListeners();
  }

  Future<void> startMic() async {
    if (_state != LiveVivaState.active || _isStreaming) return;
    await _startStreaming();
  }

  Future<void> stopMic() async {
    await _stopStreaming();
  }

  Future<void> toggleMic() async {
    if (_isStreaming) {
      await stopMic();
    } else {
      await startMic();
    }
  }

  /// Send a typed text message (simulator fallback)
  void sendTextMessage(String text) {
    if (text.trim().isEmpty || _channel == null) return;
    debugPrint('$_tag Sending text: ${text.length} chars');
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'text': text.trim(),
    }));
  }

  Future<void> endViva() async {
    debugPrint('$_tag endViva()');
    _channel?.sink.add(jsonEncode({'type': 'end'}));
    await _stopStreaming();
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    debugPrint('$_tag dispose()');
    _stopStreaming();
    try {
      _player?.stopPlayer();
      _player?.closePlayer();
    } catch (_) {}
    _player = null;
    _channel?.sink.close();
    super.dispose();
  }
}
