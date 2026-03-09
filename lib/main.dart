import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_session/audio_session.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/audio_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/verification_viewmodel.dart';
import 'viewmodels/viva_viewmodel.dart';
import 'viewmodels/instructor_viewmodel.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/live_viva_viewmodel.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/viva_screen.dart';
import 'screens/results_screen.dart';
import 'screens/instructor_home_screen.dart';
import 'screens/assignment_detail_screen.dart';
import 'screens/transcript_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/live_viva_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure the global audio session for playAndRecord so both
    // TTS playback and microphone input work without conflicts.
    try {
      final session = await AudioSession.instance;
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
      debugPrint('[AudioSession] Configured for playAndRecord');
    } catch (e) {
      debugPrint('[AudioSession] Configuration failed (simulator?): $e');
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
    };
    runApp(const IvasApp());
  }, (error, stack) {
    debugPrint('Unhandled error: $error');
    debugPrint('$stack');
  });
}

class IvasApp extends StatefulWidget {
  const IvasApp({super.key});

  @override
  State<IvasApp> createState() => _IvasAppState();
}

class _IvasAppState extends State<IvasApp> {
  // Create services once, not on every build
  final _apiService = ApiService();
  final _wsService = WebSocketService();
  final _audioService = AudioService();

  @override
  void dispose() {
    _audioService.dispose();
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<AudioService>.value(value: _audioService),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(_apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(_apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => VerificationViewModel(_apiService, _audioService),
        ),
        ChangeNotifierProvider(
          create: (_) => VivaViewModel(_apiService, _wsService, _audioService),
        ),
        ChangeNotifierProvider(
          create: (_) => InstructorViewModel(_apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminViewModel(_apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => LiveVivaViewModel(),
        ),
      ],
      child: MaterialApp(
        title: 'IVAS — Viva Assessment',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/verification': (context) => const VerificationScreen(),
          '/viva': (context) => const VivaScreen(),
          '/results': (context) => const ResultsScreen(),
          '/instructor/home': (context) => const InstructorHomeScreen(),
          '/instructor/assignment': (context) => const AssignmentDetailScreen(),
          '/instructor/transcript': (context) => const TranscriptScreen(),
          '/admin/home': (context) => const AdminHomeScreen(),
          '/live-viva': (context) => const LiveVivaScreen(),
        },
      ),
    );
  }
}
