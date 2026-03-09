import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:audio_session/audio_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/session.dart';

enum LiveVivaState {
  idle,
  connecting,
  ready, // Connected, waiting for Gemini to greet
  instructorSpeaking, // Gemini is talking
  studentSpeaking, // Student mic is active
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
  AudioPlayer? _player;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _recordStreamSub;
  WebSocketChannel? _channel;
  bool _isStreaming = false;

  // Audio buffer for incoming Gemini audio (24kHz, 16-bit, mono PCM)
  final List<int> _audioBuffer = [];
  bool _isPlayingBack = false;

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

  void _setState(LiveVivaState newState) {
    debugPrint('$_tag State: $_state => $newState');
    _state = newState;
    notifyListeners();
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
      // Binary = PCM audio from Gemini
      _audioBuffer.addAll(data is Uint8List ? data : Uint8List.fromList(data));
      if (_state != LiveVivaState.instructorSpeaking) {
        _setState(LiveVivaState.instructorSpeaking);
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
          _setState(LiveVivaState.ready);
          // Start streaming mic audio after a brief delay
          Future.delayed(const Duration(milliseconds: 500), () {
            _startStreaming();
          });
          break;

        case 'turn_end':
          // Gemini finished speaking — play buffered audio
          debugPrint('$_tag Turn end, buffer=${_audioBuffer.length} bytes');
          _playBufferedAudio();
          break;

        case 'thinking':
          debugPrint('$_tag Instructor thinking...');
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
          // Don't set complete state yet — let the last audio finish playing
          // The state will transition after playback
          _stopStreaming();
          // Small delay to let any final audio play
          Future.delayed(const Duration(seconds: 2), () {
            _setState(LiveVivaState.complete);
          });
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

  /// Start streaming mic audio to the server
  Future<void> _startStreaming() async {
    if (_isStreaming) return;
    // Don't start streaming if we've already errored or completed
    if (_state == LiveVivaState.error || _state == LiveVivaState.complete) {
      debugPrint('$_tag Skipping mic stream — state is $_state');
      return;
    }
    debugPrint('$_tag Starting mic stream...');

    try {
      // Configure audio session for simultaneous play + record
      final audioSession = await AudioSession.instance;
      await audioSession.setActive(false);
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
      _setState(LiveVivaState.studentSpeaking);

      _recordStreamSub = stream.listen(
        (chunk) {
          // Send raw PCM bytes to server (only when not playing back)
          if (_channel != null && !_isPlayingBack) {
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

  /// Play buffered Gemini audio (24kHz, 16-bit, mono PCM)
  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) {
      debugPrint('$_tag No audio to play');
      // Resume student speaking state
      if (_state != LiveVivaState.complete && _state != LiveVivaState.error) {
        _setState(LiveVivaState.studentSpeaking);
      }
      return;
    }

    debugPrint('$_tag Playing ${_audioBuffer.length} bytes of audio');
    _isPlayingBack = true;
    _setState(LiveVivaState.instructorSpeaking);

    try {
      // Wrap PCM in WAV header (24kHz, 16-bit, mono)
      final pcmBytes = Uint8List.fromList(_audioBuffer);
      _audioBuffer.clear();

      final wavBytes = _wrapInWav(pcmBytes, 24000, 1, 16);

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/gemini_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(wavBytes);

      // Play
      _player?.dispose();
      _player = AudioPlayer();

      final completer = Completer<void>();
      _playerCompleteSub?.cancel();
      _playerCompleteSub = _player!.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await _player!.play(DeviceFileSource(file.path));
      await completer.future;

      debugPrint('$_tag Playback finished');

      // Clean up
      _playerCompleteSub?.cancel();
      _playerCompleteSub = null;
      await _player?.dispose();
      _player = null;

      // Delete temp file
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('$_tag Playback error: $e');
    }

    _isPlayingBack = false;

    // Resume mic state (reconfigure audio session for recording)
    if (_state != LiveVivaState.complete && _state != LiveVivaState.error) {
      try {
        final audioSession = await AudioSession.instance;
        await audioSession.setActive(false);
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
      } catch (e) {
        debugPrint('$_tag Audio session reconfigure error: $e');
      }
      _setState(LiveVivaState.studentSpeaking);
    }
  }

  /// Wrap raw PCM bytes in a WAV header
  Uint8List _wrapInWav(
      Uint8List pcmData, int sampleRate, int channels, int bitsPerSample) {
    final dataSize = pcmData.length;
    final header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, dataSize + 36, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
        28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    // Combine header + PCM data
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmData);
    return result;
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
    _playerCompleteSub?.cancel();
    _player?.dispose();
    _channel?.sink.close();
    super.dispose();
  }
}
