import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

enum VerificationState {
  checking,
  notEnrolled,
  enrolling,
  recording,
  processing,
  enrolled,
  error,
}

class VerificationViewModel extends ChangeNotifier {
  static const String _tag = '[VerifyVM]';
  final ApiService _api;
  final AudioService _audio;

  VerificationViewModel(this._api, this._audio) {
    debugPrint('$_tag Initialized');
  }

  VerificationState _state = VerificationState.checking;
  int _sampleCount = 0;
  final int _requiredSamples = 3;
  String? _error;
  String _statusMessage = 'Checking enrollment status...';

  VerificationState get state => _state;
  int get sampleCount => _sampleCount;
  int get requiredSamples => _requiredSamples;
  String? get error => _error;
  String get statusMessage => _statusMessage;
  bool get isEnrolled => _state == VerificationState.enrolled;
  double get progress => _sampleCount / _requiredSamples;

  void _setState(VerificationState newState) {
    debugPrint('$_tag State: $_state => $newState');
    _state = newState;
  }

  Future<void> checkEnrollment(String studentId) async {
    debugPrint('$_tag checkEnrollment(studentId=$studentId)');
    _setState(VerificationState.checking);
    notifyListeners();

    try {
      final result = await _api.getEnrollmentStatus(studentId);
      final enrolled = result['is_enrolled'] as bool? ?? false;
      _sampleCount = result['sample_count'] as int? ?? 0;
      debugPrint(
          '$_tag   API result: enrolled=$enrolled, sampleCount=$_sampleCount');

      if (enrolled && _sampleCount >= _requiredSamples) {
        _setState(VerificationState.enrolled);
        _statusMessage = 'Voice enrolled ✓';
      } else {
        _setState(VerificationState.notEnrolled);
        _statusMessage = _sampleCount > 0
            ? 'Need ${_requiredSamples - _sampleCount} more sample(s)'
            : 'Voice enrollment needed';
      }
    } catch (e) {
      debugPrint(
          '$_tag ⚠ checkEnrollment failed: $e (defaulting to notEnrolled)');
      _setState(VerificationState.notEnrolled);
      _statusMessage = 'Voice enrollment needed';
    }
    debugPrint('$_tag   statusMessage: $_statusMessage');
    notifyListeners();
  }

  Future<void> startRecording() async {
    debugPrint('$_tag startRecording()');
    try {
      _setState(VerificationState.recording);
      _statusMessage = 'Speak clearly for 3-5 seconds...';
      notifyListeners();
      await _audio.startRecording();
      debugPrint('$_tag ✓ Recording started');
    } catch (e) {
      debugPrint('$_tag ✗ startRecording failed: $e');
      _setState(VerificationState.error);
      _error = 'Microphone access denied';
      _statusMessage = 'Error: $_error';
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndEnroll(String studentId) async {
    debugPrint('$_tag stopRecordingAndEnroll(studentId=$studentId)');
    _setState(VerificationState.processing);
    _statusMessage = 'Processing voice sample...';
    notifyListeners();

    try {
      final base64Audio = await _audio.stopRecordingAsBase64();
      if (base64Audio == null) {
        debugPrint('$_tag ✗ No audio data received');
        throw Exception('No audio recorded');
      }
      debugPrint('$_tag   Audio base64 length: ${base64Audio.length}');

      final result = await _api.enrollVoiceSample(
        studentId: studentId,
        audioBase64: base64Audio,
      );
      debugPrint('$_tag   Enroll result: $result');

      _sampleCount = result['sample_count'] as int? ?? _sampleCount + 1;
      final status = result['status'] as String? ?? '';
      debugPrint('$_tag   sampleCount=$_sampleCount, status=$status');

      if (status == 'enrolled' || _sampleCount >= _requiredSamples) {
        _setState(VerificationState.enrolled);
        _statusMessage = 'Voice enrolled successfully! ✓';
        debugPrint('$_tag ✓ Enrollment complete!');
      } else {
        _setState(VerificationState.enrolling);
        _statusMessage = 'Sample $_sampleCount/$_requiredSamples recorded';
        debugPrint(
            '$_tag   Need more samples: $_sampleCount/$_requiredSamples');
      }
    } catch (e) {
      debugPrint('$_tag ✗ stopRecordingAndEnroll failed: $e');
      _setState(VerificationState.error);
      _error = e.toString();
      _statusMessage = 'Failed to process sample';
    }
    notifyListeners();
  }

  void reset() {
    debugPrint('$_tag reset()');
    _setState(VerificationState.notEnrolled);
    _sampleCount = 0;
    _error = null;
    _statusMessage = 'Voice enrollment needed';
    notifyListeners();
  }
}
