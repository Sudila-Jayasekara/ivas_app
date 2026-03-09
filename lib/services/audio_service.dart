import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:audio_session/audio_session.dart';

class AudioService {
  static const String _tag = '[AudioService]';
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  StreamSubscription? _playerCompleteSub;
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  AudioRecorder get recorder {
    if (_recorder == null) {
      debugPrint('$_tag Lazy-creating AudioRecorder');
      _recorder = AudioRecorder();
    }
    return _recorder!;
  }

  AudioPlayer get player {
    if (_player == null) {
      debugPrint('$_tag Lazy-creating AudioPlayer');
      _player = AudioPlayer();
    }
    return _player!;
  }

  Future<bool> hasPermission() async {
    debugPrint('$_tag hasPermission() checking...');
    try {
      final result = await recorder.hasPermission();
      debugPrint('$_tag hasPermission() => $result');
      return result;
    } catch (e) {
      debugPrint('$_tag ✗ hasPermission() error: $e');
      return false;
    }
  }

  Future<void> startRecording() async {
    debugPrint('$_tag startRecording() called (isRecording=$_isRecording)');
    if (_isRecording) {
      debugPrint('$_tag   Already recording, skipping');
      return;
    }

    final hasPerms = await recorder.hasPermission();
    debugPrint('$_tag   Mic permission: $hasPerms');
    if (!hasPerms) {
      debugPrint('$_tag ✗ Microphone permission denied!');
      throw Exception('Microphone permission not granted');
    }

    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.wav';
    debugPrint('$_tag   Recording to: $_currentPath');

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentPath!,
    );
    _isRecording = true;
    debugPrint('$_tag ✓ Recording started');
  }

  Future<String?> stopRecording() async {
    debugPrint('$_tag stopRecording() called (isRecording=$_isRecording)');
    if (!_isRecording) {
      debugPrint('$_tag   Not recording, returning null');
      return null;
    }

    try {
      final path = await recorder.stop();
      _isRecording = false;
      debugPrint('$_tag ✓ Recording stopped, path=$path');
      return path;
    } catch (e) {
      debugPrint('$_tag ✗ stopRecording() error: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<String?> stopRecordingAsBase64() async {
    debugPrint('$_tag stopRecordingAsBase64() called');
    final path = await stopRecording();
    if (path == null) {
      debugPrint('$_tag   No path returned from stopRecording');
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      debugPrint('$_tag ✗ File does not exist: $path');
      return null;
    }

    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    debugPrint(
        '$_tag ✓ Encoded to base64: ${bytes.length} bytes => ${base64.length} chars');
    return base64;
  }

  Future<void> playBase64Audio(String base64Audio) async {
    debugPrint('$_tag playBase64Audio() — ${base64Audio.length} chars');
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/tts_playback_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      debugPrint('$_tag   Playing: ${file.path}');

      final completer = Completer<void>();
      // Cancel any previous subscription to avoid leaks
      await _playerCompleteSub?.cancel();
      _playerCompleteSub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await player.play(DeviceFileSource(file.path));
      await completer.future;
      debugPrint('$_tag ✓ Playback finished');
    } catch (e) {
      debugPrint('$_tag ✗ playBase64Audio error: $e');
    }
  }

  Future<void> stopPlayback() async {
    debugPrint('$_tag stopPlayback() called');
    try {
      await _player?.stop();
      debugPrint('$_tag ✓ Playback stopped');
    } catch (e) {
      debugPrint('$_tag ✗ stopPlayback error: $e');
    }
  }

  /// Release the audio player completely and re-activate the audio session
  /// for recording. Call this BEFORE starting speech recognition so the
  /// iOS audio session is not stuck in playback-only mode.
  Future<void> prepareForRecording() async {
    debugPrint(
        '$_tag prepareForRecording() — releasing player, activating record session');
    try {
      // Fully release the player so it doesn't hold the audio session
      await _playerCompleteSub?.cancel();
      _playerCompleteSub = null;
      await _player?.stop();
      await _player?.dispose();
      _player = null;

      // Re-activate session with playAndRecord to ensure mic input works
      final session = await AudioSession.instance;
      await session.setActive(false);
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      await session.setActive(true);
      debugPrint('$_tag ✓ Audio session re-activated for recording');
    } catch (e) {
      debugPrint('$_tag ✗ prepareForRecording error: $e');
    }
  }

  void dispose() {
    debugPrint('$_tag dispose() called');
    _playerCompleteSub?.cancel();
    _recorder?.dispose();
    _player?.dispose();
    _recorder = null;
    _player = null;
  }
}
