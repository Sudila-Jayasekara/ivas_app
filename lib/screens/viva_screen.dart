import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/viva_viewmodel.dart';
import '../widgets/animated_mic_button.dart';
import '../widgets/question_card.dart';
import '../widgets/glass_card.dart';

class VivaScreen extends StatefulWidget {
  const VivaScreen({super.key});

  @override
  State<VivaScreen> createState() => _VivaScreenState();
}

class _VivaScreenState extends State<VivaScreen> with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _speechAvailable = false;
  bool _isSpeaking = false;
  late String? _sessionId;
  late String _assignmentId;
  late String _assignmentTitle;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) => debugPrint('STT error: $error'),
      );
    } catch (e) {
      _speechAvailable = false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _assignmentId = args['assignmentId'] as String;
      _assignmentTitle = args['assignmentTitle'] as String;
      _sessionId = args['sessionId'] as String?;
      _initialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startOrResumeViva();
      });
    }
  }

  Future<void> _startOrResumeViva() async {
    final auth = context.read<AuthViewModel>();
    final viva = context.read<VivaViewModel>();

    if (_sessionId != null) {
      await viva.resumeViva(
        sessionId: _sessionId!,
      );
    } else {
      await viva.startViva(
        studentId: auth.studentId,
        assignmentId: _assignmentId,
      );
    }

    // Speak the current question
    if (viva.currentQuestion != null) {
      _speakQuestion(viva.currentQuestion!.questionText);
    }
  }

  Future<void> _speakQuestion(String text) async {
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _toggleListening() async {
    final viva = context.read<VivaViewModel>();

    if (viva.state == VivaState.listening) {
      // Stop listening and submit
      await _speech.stop();
      if (viva.transcribedText.isNotEmpty) {
        await viva.submitAnswer(viva.transcribedText);
      } else {
        viva.proceedToNextQuestion();
      }
      return;
    }

    if (!_speechAvailable) {
      // Fallback: show text input dialog
      _showTextInputDialog();
      return;
    }

    viva.setListening();

    await _speech.listen(
      onResult: (result) {
        viva.updateTranscription(result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          viva.submitAnswer(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(cancelOnError: true),
    );
  }

  void _showTextInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Type Your Answer',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter your answer...',
            fillColor: AppTheme.surface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (controller.text.isNotEmpty) {
                context.read<VivaViewModel>().submitAnswer(controller.text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viva = context.watch<VivaViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(viva),

              // Progress
              _buildProgressBar(viva),

              // Main content
              Expanded(
                child: _buildContent(viva),
              ),

              // Bottom controls
              _buildBottomControls(viva),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(VivaViewModel viva) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _showAbandonDialog(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _assignmentTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (viva.state != VivaState.loading)
                  Text(
                    '${viva.answeredQuestions}/${viva.totalQuestions} Questions',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Hint button
          if (viva.state == VivaState.questionDisplayed ||
              viva.state == VivaState.listening)
            IconButton(
              icon: Icon(
                Icons.lightbulb_outline_rounded,
                color:
                    viva.hintUsed ? AppTheme.warning : AppTheme.textSecondary,
              ),
              onPressed: viva.hintUsed ? null : () => _requestHint(viva),
              tooltip: 'Get Hint',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VivaViewModel viva) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: viva.progress,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildContent(VivaViewModel viva) {
    switch (viva.state) {
      case VivaState.loading:
      case VivaState.idle:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 20),
              Text(
                'Preparing your viva...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ).animate().fadeIn();

      case VivaState.questionDisplayed:
        if (viva.currentQuestion == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.quiz_rounded,
                      color: AppTheme.warning, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'No questions available for this assignment yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The instructor may not have added questions. Try another assignment.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildQuestionView(viva)
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.03);

      case VivaState.listening:
        return _buildListeningView(viva);

      case VivaState.processing:
        return _buildProcessingView(viva);

      case VivaState.showingFeedback:
        return _buildFeedbackView(viva)
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.95, 0.95));

      case VivaState.complete:
        // Navigate to results
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/results');
        });
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.success),
        );

      case VivaState.error:
        return _buildErrorView(viva);
    }
  }

  Widget _buildQuestionView(VivaViewModel viva) {
    final q = viva.currentQuestion!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Speaking indicator
          if (_isSpeaking)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_rounded,
                      color: AppTheme.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Reading question...',
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  duration: 1500.ms,
                ),

          QuestionCard(
            questionText: q.questionText,
            competency: q.competency,
            difficulty: q.difficulty,
            isFollowUp: q.isFollowUp,
            questionNumber: viva.answeredQuestions + 1,
            totalQuestions: viva.totalQuestions,
          ),

          // Hint
          if (viva.hintText != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded,
                      color: AppTheme.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      viva.hintText!,
                      style: const TextStyle(
                          color: AppTheme.warning, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 24),
          Text(
            'Tap the microphone to answer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningView(VivaViewModel viva) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Listening...',
            style: TextStyle(
              color: AppTheme.accentLight,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn()
              .then()
              .shimmer(
                color: AppTheme.accent.withValues(alpha: 0.5),
                duration: 1200.ms,
              ),
          const SizedBox(height: 24),
          // Real-time transcript
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80, maxHeight: 160),
              child: Center(
                child: Text(
                  viva.transcribedText.isEmpty
                      ? 'Start speaking...'
                      : viva.transcribedText,
                  style: TextStyle(
                    color: viva.transcribedText.isEmpty
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView(VivaViewModel viva) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Show what was transcribed
          if (viva.transcribedText.isNotEmpty)
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Your Answer',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    viva.transcribedText,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppTheme.accent),
          const SizedBox(height: 16),
          const Text(
            'Evaluating your answer...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFeedbackView(VivaViewModel viva) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Score badge
            if (viva.lastScore != null)
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _getScoreColor(viva.lastScore! / 10),
                      _getScoreColor(viva.lastScore! / 10)
                          .withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getScoreColor(viva.lastScore! / 10)
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    viva.lastScore!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ).animate().scale(
                    begin: const Offset(0.3, 0.3),
                    curve: Curves.elasticOut,
                    duration: 800.ms,
                  ),

            const SizedBox(height: 20),

            // Feedback text
            if (viva.lastFeedback != null)
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rate_review_rounded,
                            color: AppTheme.accent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      viva.lastFeedback!,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

            // Misconceptions
            if (viva.lastMisconceptions != null &&
                viva.lastMisconceptions!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppTheme.warning, size: 16),
                        SizedBox(width: 6),
                        Text('Misconceptions',
                            style: TextStyle(
                                color: AppTheme.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...viva.lastMisconceptions!.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $m',
                              style: const TextStyle(
                                  color: AppTheme.warning, fontSize: 13)),
                        )),
                  ],
                ),
              ),

            const SizedBox(height: 28),

            // Next button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final viva = context.read<VivaViewModel>();
                  viva.proceedToNextQuestion();
                  // Speak next question
                  if (viva.currentQuestion != null &&
                      viva.state != VivaState.complete) {
                    _speakQuestion(viva.currentQuestion!.questionText);
                  }
                },
                child: Text(
                  viva.finalScore != null ? 'View Results' : 'Next Question →',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(VivaViewModel viva) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 56),
            const SizedBox(height: 16),
            Text(viva.error ?? 'Something went wrong',
                style: const TextStyle(color: AppTheme.error, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(VivaViewModel viva) {
    if (viva.state == VivaState.loading ||
        viva.state == VivaState.complete ||
        viva.state == VivaState.error ||
        viva.state == VivaState.showingFeedback) {
      return const SizedBox(height: 20);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          AnimatedMicButton(
            isListening: viva.state == VivaState.listening,
            isProcessing: viva.state == VivaState.processing,
            onTap: _toggleListening,
          ),
          const SizedBox(height: 8),
          // Type answer fallback
          if (viva.state == VivaState.questionDisplayed)
            TextButton.icon(
              onPressed: _showTextInputDialog,
              icon: const Icon(Icons.keyboard_rounded,
                  size: 16, color: AppTheme.textSecondary),
              label: const Text(
                'Type instead',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showAbandonDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Viva?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Your progress will be lost if you leave now.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<VivaViewModel>().abandonViva();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestHint(VivaViewModel viva) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Hint?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'A scoring penalty may be applied.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Get Hint'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viva.requestHint();
    }
  }

  Color _getScoreColor(double ratio) {
    if (ratio >= 0.8) return AppTheme.success;
    if (ratio >= 0.6) return AppTheme.accent;
    if (ratio >= 0.4) return AppTheme.warning;
    return AppTheme.error;
  }
}
