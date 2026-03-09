import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/audio_service.dart';

enum VivaState {
  idle,
  loading,
  questionDisplayed,
  listening,
  processing,
  showingFeedback,
  complete,
  error,
}

class VivaViewModel extends ChangeNotifier {
  static const String _tag = '[VivaVM]';
  final ApiService _api;
  final WebSocketService _ws;
  final AudioService _audio;

  VivaViewModel(this._api, this._ws, this._audio) {
    debugPrint('$_tag Initialized');
  }

  // Session state
  String? _sessionId;
  VivaState _state = VivaState.idle;
  QuestionWithContext? _currentQuestion;
  int _totalQuestions = 0;
  int _answeredQuestions = 0;
  String _transcribedText = '';
  bool _useWebSocket = false;

  // Feedback state
  double? _lastScore;
  String? _lastFeedback;
  List<String>? _lastMisconceptions;

  // Completion state
  double? _finalScore;
  double? _maxScore;
  List<CompetencySummary>? _competencySummary;
  String? _completionMessage;

  // Hint state
  String? _hintText;
  bool _hintUsed = false;

  bool _isSpeaking = false;
  double _soundLevel = 0.0;
  String? _error;
  StreamSubscription? _wsSub;

  // Getters
  String? get sessionId => _sessionId;
  VivaState get state => _state;
  QuestionWithContext? get currentQuestion => _currentQuestion;
  bool get isSpeaking => _isSpeaking;
  double get soundLevel => _soundLevel;
  int get totalQuestions => _totalQuestions;
  int get answeredQuestions => _answeredQuestions;
  String get transcribedText => _transcribedText;
  double? get lastScore => _lastScore;
  String? get lastFeedback => _lastFeedback;
  List<String>? get lastMisconceptions => _lastMisconceptions;
  double? get finalScore => _finalScore;
  double? get maxScore => _maxScore;
  List<CompetencySummary>? get competencySummary => _competencySummary;
  String? get completionMessage => _completionMessage;
  String? get hintText => _hintText;
  bool get hintUsed => _hintUsed;
  String? get error => _error;
  double get progress =>
      _totalQuestions > 0 ? _answeredQuestions / _totalQuestions : 0;

  void _setState(VivaState newState) {
    debugPrint('$_tag State: $_state => $newState');
    _state = newState;
  }

  /// Start a new viva — triggers assessment and gets first question
  Future<void> startViva({
    required String studentId,
    required String assignmentId,
    bool useWebSocket = false,
  }) async {
    debugPrint('$_tag ════════════════════════════════════════');
    debugPrint(
        '$_tag startViva(studentId=$studentId, assignmentId=$assignmentId, ws=$useWebSocket)');
    _setState(VivaState.loading);
    _error = null;
    _useWebSocket = useWebSocket;
    _answeredQuestions = 0;
    _hintText = null;
    _hintUsed = false;
    notifyListeners();

    try {
      debugPrint('$_tag   Triggering assessment...');
      final session = await _api.triggerAssessment(
        studentId: studentId,
        assignmentId: assignmentId,
      );

      _sessionId = session.sessionId;
      _totalQuestions = session.totalQuestions;
      _currentQuestion = session.firstQuestion;
      debugPrint(
          '$_tag ✓ Session started: id=$_sessionId, totalQ=$_totalQuestions');
      debugPrint(
          '$_tag   First question: ${_currentQuestion?.questionText ?? 'null'}');

      if (_useWebSocket && _currentQuestion != null) {
        debugPrint('$_tag   Connecting WebSocket...');
        _connectWebSocket();
      }

      _setState(VivaState.questionDisplayed);
    } catch (e) {
      debugPrint('$_tag ✗ startViva failed: $e');
      _setState(VivaState.error);
      _error = 'Failed to start viva: $e';
    }
    notifyListeners();
  }

  /// Resume an existing viva
  Future<void> resumeViva({
    required String sessionId,
    bool useWebSocket = false,
  }) async {
    debugPrint('$_tag ════════════════════════════════════════');
    debugPrint('$_tag resumeViva(sessionId=$sessionId, ws=$useWebSocket)');
    _setState(VivaState.loading);
    _error = null;
    _useWebSocket = useWebSocket;
    _sessionId = sessionId;
    _hintText = null;
    _hintUsed = false;
    notifyListeners();

    try {
      debugPrint('$_tag   Resuming session...');
      final session = await _api.resumeAssessment(sessionId);

      _totalQuestions = session.totalQuestions;
      _currentQuestion = session.firstQuestion;

      // We need to know how many were answered.
      // Since firstQuestion from resume is the *current* unanswered one,
      // we can't easily get answered count from trigger response.
      // Let's fetch session details to be sure.
      try {
        final sessions =
            await _api.getStudentSessions(ApiService.hardcodedStudentId);
        final thisSession =
            sessions.firstWhere((s) => s.sessionId == sessionId);
        _answeredQuestions = thisSession.responsesGiven;
      } catch (e) {
        debugPrint('$_tag   Could not fetch exact answered count: $e');
        _answeredQuestions = 0; // Fallback
      }

      debugPrint(
          '$_tag ✓ Session resumed: id=$_sessionId, totalQ=$_totalQuestions, answered=$_answeredQuestions');
      debugPrint(
          '$_tag   Current question: ${_currentQuestion?.questionText ?? 'null'}');

      if (_useWebSocket && _currentQuestion != null) {
        debugPrint('$_tag   Connecting WebSocket...');
        _connectWebSocket();
      }

      _setState(VivaState.questionDisplayed);
    } catch (e) {
      debugPrint('$_tag ✗ resumeViva failed: $e');
      _setState(VivaState.error);
      _error = 'Failed to resume viva: $e';
    }
    notifyListeners();
  }

  void _connectWebSocket() {
    debugPrint('$_tag _connectWebSocket(sessionId=$_sessionId)');
    _ws.connect(_sessionId!);
    _wsSub = _ws.messages.listen(_handleWsMessage);

    if (_currentQuestion != null) {
      _ws.sendStartSession(
        questionInstanceId: _currentQuestion!.questionInstanceId,
        questionText: _currentQuestion!.questionText,
      );
    }
  }

  Future<void> _handleWsMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    debugPrint('$_tag ◀ WS message type=$type');
    debugPrint('$_tag   Full msg: $msg');

    switch (type) {
      case 'evaluation':
        _lastScore = (msg['score'] as num?)?.toDouble();
        _lastFeedback = msg['feedback'] as String?;
        _lastMisconceptions = msg['misconceptions'] != null
            ? List<String>.from(msg['misconceptions'])
            : null;
        _setState(VivaState.showingFeedback);
        _answeredQuestions++;
        debugPrint(
            '$_tag   Evaluation: score=$_lastScore, feedback=${_lastFeedback?.substring(0, (_lastFeedback!.length > 50 ? 50 : _lastFeedback!.length))}..., answered=$_answeredQuestions');

        // Automatic flow: Play feedback audio, then next event will likely be next_question
        await _playAudioIfAvailable(msg);
        break;

      case 'next_question':
        _currentQuestion = QuestionWithContext(
          questionId: '',
          questionInstanceId: msg['question_instance_id'] as String? ?? '',
          questionText: msg['question_text'] as String? ?? '',
          competency: msg['competency'] as String? ?? '',
          difficulty: msg['difficulty'] as int? ?? 1,
          isFollowUp: msg['is_follow_up'] as bool? ?? false,
        );
        _hintText = null;
        _hintUsed = false;
        _setState(VivaState.questionDisplayed);
        debugPrint('$_tag   Next question: ${_currentQuestion!.questionText}');
        await _playAudioIfAvailable(msg);
        break;

      case 'session_complete':
        _finalScore = (msg['final_score'] as num?)?.toDouble();
        _maxScore = (msg['max_score'] as num?)?.toDouble();
        _completionMessage = msg['message'] as String?;
        if (msg['competency_summary'] != null) {
          _competencySummary = (msg['competency_summary'] as List)
              .map((e) => CompetencySummary.fromJson(e))
              .toList();
        }
        _setState(VivaState.complete);
        debugPrint(
            '$_tag ✓ Session complete! finalScore=$_finalScore/$_maxScore');
        await _playAudioIfAvailable(msg);
        break;

      case 'instructor_response':
        _lastFeedback = msg['message'] as String?;
        debugPrint('$_tag   Instructor response: $_lastFeedback');
        await _playAudioIfAvailable(msg);
        break;

      case 'voice_verification':
        debugPrint('$_tag   Voice verification event received');
        break;

      case 'voice_verification_warning':
        _error = msg['message'] as String?;
        debugPrint('$_tag ⚠ Voice verification warning: $_error');
        break;

      case 'error':
        _error = msg['message'] as String?;
        debugPrint('$_tag ✗ WS error: $_error');
        break;

      default:
        debugPrint('$_tag ⚠ Unknown WS message type: $type');
    }
    notifyListeners();
  }

  Future<void> _playAudioIfAvailable(Map<String, dynamic> msg) async {
    final audioB64 = msg['audio_b64'] as String?;
    if (audioB64 != null && audioB64.isNotEmpty) {
      debugPrint('$_tag   Playing audio (${audioB64.length} chars)...');
      _isSpeaking = true;
      notifyListeners();

      await _audio.playBase64Audio(audioB64);

      _isSpeaking = false;
      notifyListeners();
    } else {
      debugPrint('$_tag   No audio in message');
    }
  }

  /// Request TTS from backend and play it
  Future<void> generateAndPlaySpeech(String text) async {
    if (text.isEmpty) return;

    debugPrint('$_tag generateAndPlaySpeech("$text")');
    try {
      final audioB64 = await _api.generateSpeech(text);
      if (audioB64 != null && audioB64.isNotEmpty) {
        _isSpeaking = true;
        notifyListeners();

        await _audio.playBase64Audio(audioB64);

        _isSpeaking = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('$_tag ✗ generateAndPlaySpeech error: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// For REST mode: submit a text answer
  Future<void> submitAnswer(String answerText) async {
    debugPrint(
        '$_tag submitAnswer("${answerText.length > 80 ? '${answerText.substring(0, 80)}...' : answerText}")');
    if (_sessionId == null || _currentQuestion == null) {
      debugPrint(
          '$_tag ⚠ Cannot submit — sessionId=$_sessionId, currentQuestion=${_currentQuestion != null}');
      return;
    }

    _setState(VivaState.processing);
    _transcribedText = answerText;
    notifyListeners();

    if (_useWebSocket) {
      debugPrint('$_tag   Sending via WebSocket...');
      _ws.sendMessage(
        text: answerText,
        questionInstanceId: _currentQuestion!.questionInstanceId,
      );
      return; // WebSocket handler will update state
    }

    // REST mode
    debugPrint('$_tag   Sending via REST...');
    try {
      final result = await _api.submitResponse(
        sessionId: _sessionId!,
        questionInstanceId: _currentQuestion!.questionInstanceId,
        responseText: answerText,
      );

      _lastScore = result.evaluationScore;
      _lastFeedback = result.feedbackText;
      _lastMisconceptions = result.detectedMisconceptions;
      _answeredQuestions++;
      _setState(VivaState.showingFeedback);
      debugPrint(
          '$_tag ✓ Response: score=$_lastScore, isComplete=${result.isComplete}, answered=$_answeredQuestions/$_totalQuestions');

      if (result.isComplete) {
        _finalScore = result.finalScore;
        _maxScore = result.maxScore;
        _competencySummary = result.competencySummary;
        _completionMessage = result.message;
        debugPrint('$_tag ✓ Viva complete! finalScore=$_finalScore/$_maxScore');
      } else {
        _currentQuestion = result.nextQuestion;
        debugPrint(
            '$_tag   Next question: ${_currentQuestion?.questionText ?? 'null'}');
      }
    } catch (e) {
      debugPrint('$_tag ✗ submitAnswer failed: $e');
      _setState(VivaState.error);
      _error = 'Failed to submit: $e';
    }
    notifyListeners();
  }

  /// Move to next question after viewing feedback
  void proceedToNextQuestion() {
    debugPrint(
        '$_tag proceedToNextQuestion() — finalScore=$_finalScore, hasNextQ=${_currentQuestion != null}');
    if (_finalScore != null) {
      _setState(VivaState.complete);
    } else if (_currentQuestion != null) {
      _hintText = null;
      _hintUsed = false;
      _transcribedText = '';
      _setState(VivaState.questionDisplayed);
    }
    notifyListeners();
  }

  /// Update transcribed text from STT
  void updateTranscription(String text) {
    _transcribedText = text;
    debugPrint('$_tag updateTranscription: "$text"');
    notifyListeners();
  }

  void updateSoundLevel(double level) {
    _soundLevel = level;
    notifyListeners();
  }

  /// Set listening state
  void setListening() {
    debugPrint('$_tag setListening()');
    _setState(VivaState.listening);
    _transcribedText = '';
    notifyListeners();
  }

  /// Request a hint
  Future<void> requestHint() async {
    debugPrint(
        '$_tag requestHint(sessionId=$_sessionId, qid=${_currentQuestion?.questionInstanceId})');
    if (_sessionId == null || _currentQuestion == null) {
      debugPrint('$_tag ⚠ Cannot request hint — no session/question');
      return;
    }

    try {
      final result = await _api.requestHint(
        sessionId: _sessionId!,
        questionInstanceId: _currentQuestion!.questionInstanceId,
      );
      _hintText = result['hint_text'] as String?;
      _hintUsed = true;
      debugPrint('$_tag ✓ Hint received: $_hintText');
    } catch (e) {
      debugPrint('$_tag ✗ requestHint failed: $e');
      _hintText = 'Unable to get hint';
    }
    notifyListeners();
  }

  /// Abandon session
  Future<void> abandonViva() async {
    debugPrint('$_tag abandonViva(sessionId=$_sessionId)');
    if (_sessionId != null) {
      try {
        await _api.abandonSession(_sessionId!);
        debugPrint('$_tag ✓ Session abandoned');
      } catch (e) {
        debugPrint('$_tag ⚠ abandonSession error (ignoring): $e');
      }
    }
    _ws.disconnect();
    _wsSub?.cancel();
    _setState(VivaState.idle);
    notifyListeners();
    debugPrint('$_tag ✓ Viva abandoned, state reset');
  }

  @override
  void dispose() {
    debugPrint('$_tag dispose()');
    _wsSub?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}
