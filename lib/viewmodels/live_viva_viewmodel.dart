import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import '../models/session.dart';

enum LiveVivaState {
  idle,
  connecting,
  instructorSpeaking, // Gemini is talking (greeting or response)
  studentSpeaking, // Student's turn
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

  // Completion
  double? _finalScore;
  double? _maxScore;
  List<CompetencySummary>? _competencySummary;

  // Audio
  AudioRecorder? _recorder;
  StreamSubscription? _recordStreamSub;
  WebSocketChannel? _channel;
  bool _isStreaming = false;
  bool _pcmPlayerReady = false;
  bool _textMode = false;
  static const _platform = MethodChannel('com.gradeloop.ivas/platform');

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
  bool get isInstructorSpeaking => _state == LiveVivaState.instructorSpeaking;
  bool get isStudentSpeaking => _state == LiveVivaState.studentSpeaking;
  bool get isTextMode => _textMode;

  void _setState(LiveVivaState newState) {
    debugPrint('$_tag State: $_state => $newState');
    _state = newState;
    notifyListeners();
  }

  /// Initialize the PCM streaming player (24kHz, 16-bit, mono — Gemini output)
  Future<void> _initPcmPlayer() async {
    if (_pcmPlayerReady) return;
    try {
      FlutterPcmSound.setLogLevel(LogLevel.none);
      // Feed callback — called when player needs more data. We push data
      // directly on receive so we don't need this, but set a small buffer.
      FlutterPcmSound.setFeedCallback((int remainingFrames) {
        // No-op: we feed audio proactively when chunks arrive
      });
      await FlutterPcmSound.setup(
        sampleRate: 24000,
        channelCount: 1,
      );
      // Keep feed threshold low for low-latency playback
      FlutterPcmSound.setFeedThreshold(8000);
      _pcmPlayerReady = true;
      debugPrint('$_tag PCM player initialized (24kHz mono)');
    } catch (e) {
      debugPrint('$_tag PCM player init error: $e');
    }
  }

  /// Start a live viva session
  Future<void> startLiveViva({
    required String assignmentId,
    required String studentId,
    required String studentName,
    String host = 'localhost:9999',
  }) async {
    debugPrint(
        '$_tag startLiveViva(assignment=$assignmentId, student=$studentId)');
    _setState(LiveVivaState.connecting);
    _error = null;
    _questionsScored = 0;
    _totalScore = 0;
    _finalScore = null;
    _maxScore = null;
    _competencySummary = null;

    try {
      // Check if running on iOS Simulator (no real audio hardware)
      try {
        _textMode = await _platform.invokeMethod<bool>('isSimulator') ?? false;
      } catch (_) {
        _textMode = false;
      }
      if (_textMode) {
        debugPrint('$_tag Running on simulator — using text input mode');
      }

      // Init streaming PCM player
      await _initPcmPlayer();

      // Configure audio session for simultaneous play + record
      if (!_textMode) {
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
      }

      // Connect WebSocket
      final uri = Uri.parse('ws://$host/api/v1/assessments/sessions/live');
      debugPrint('$_tag Connecting to $uri');
      _channel = WebSocketChannel.connect(uri);

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('$_tag WebSocket error: $error');
          _error = 'Connection lost';
          _setState(LiveVivaState.error);
        },
        onDone: () {
          debugPrint('$_tag WebSocket closed');
          if (_state != LiveVivaState.complete &&
              _state != LiveVivaState.error) {
            _stopStreaming();
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

      debugPrint('$_tag Start message sent, waiting for ready...');
    } catch (e) {
      debugPrint('$_tag Failed to connect: $e');
      _error = 'Failed to connect: $e';
      _setState(LiveVivaState.error);
    }
  }

  void _handleMessage(dynamic data) {
    if (data is List<int> || data is Uint8List) {
      // Binary = PCM audio chunk from Gemini — feed directly to speaker
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      if (bytes.isEmpty) return;

      // Switch to instructor speaking on first audio chunk
      if (_state != LiveVivaState.instructorSpeaking) {
        _setState(LiveVivaState.instructorSpeaking);
      }

      // Feed PCM directly to the hardware — real-time playback, no buffering
      try {
        FlutterPcmSound.feed(PcmArrayInt16.fromList(
          bytes.buffer.asInt16List(),
        ));
      } catch (e) {
        debugPrint('$_tag PCM feed error: $e');
      }
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
          debugPrint(
              '$_tag Ready! session=$_sessionId, questions=$_totalQuestions');
          // Stay in connecting (will move to instructorSpeaking when audio arrives)
          // Start mic streaming — backend drops audio until greeting is done
          _startStreaming();
          break;

        case 'turn_end':
          // Gemini finished speaking — switch to student's turn
          debugPrint('$_tag Turn end — student\'s turn now');
          if (_state != LiveVivaState.complete &&
              _state != LiveVivaState.error &&
              _state != LiveVivaState.evaluating) {
            _setState(LiveVivaState.studentSpeaking);
          }
          break;

        case 'thinking':
          debugPrint('$_tag Instructor thinking...');
          break;

        case 'evaluating':
          debugPrint('$_tag Evaluating responses...');
          _stopStreaming();
          _setState(LiveVivaState.evaluating);
          break;

        case 'score':
          final qNum = msg['question_number'] as int? ?? 0;
          final score = (msg['score'] as num?)?.toDouble() ?? 0;
          _questionsScored =
              msg['total_scored'] as int? ?? _questionsScored + 1;
          _totalScore += score;
          debugPrint(
              '$_tag Score: Q$qNum = $score (total scored: $_questionsScored/$_totalQuestions)');
          notifyListeners();
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
          _setState(LiveVivaState.error);
          break;
      }
    } catch (e) {
      debugPrint('$_tag Message parse error: $e');
    }
  }

  /// Send a typed text message (text mode fallback for simulator)
  void sendTextMessage(String text) {
    if (text.trim().isEmpty || _channel == null) return;
    debugPrint('$_tag Sending text message: ${text.length} chars');
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'text': text.trim(),
    }));
    // After sending, Gemini will respond → state goes to instructorSpeaking
    _setState(LiveVivaState.instructorSpeaking);
  }

  /// Start streaming mic audio to the server
  Future<void> _startStreaming() async {
    if (_isStreaming) return;
    if (_textMode) {
      debugPrint('$_tag Text mode — skipping mic stream');
      return;
    }
    if (_state == LiveVivaState.error || _state == LiveVivaState.complete) {
      return;
    }
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

      // Start recording as a stream (PCM 16kHz mono)
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
          if (chunkCount <= 3 || chunkCount % 100 == 0) {
            debugPrint('$_tag Mic chunk #$chunkCount: ${chunk.length} bytes');
          }
          // Always send mic audio — server handles gating (drops before greeting)
          if (_channel != null && chunk.isNotEmpty) {
            _channel!.sink.add(chunk);
          }
        },
        onError: (e) {
          debugPrint('$_tag Record stream error: $e');
        },
      );

      debugPrint('$_tag Mic streaming started');
    } catch (e) {
      debugPrint('$_tag Failed to start streaming: $e');
      _error = 'Failed to start microphone: $e';
      _setState(LiveVivaState.error);
    }
  }

  /// Stop mic streaming
  Future<void> _stopStreaming() async {
    if (!_isStreaming) return;
    debugPrint('$_tag Stopping mic stream...');

    _isStreaming = false;
    await _recordStreamSub?.cancel();
    _recordStreamSub = null;

    try {
      await _recorder?.stop();
      await _recorder?.dispose();
    } catch (e) {
      debugPrint('$_tag Recorder cleanup error: $e');
    }
    _recorder = null;
  }

  /// End the viva session
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
      FlutterPcmSound.release();
    } catch (_) {}
    _channel?.sink.close();
    super.dispose();
  }
}
