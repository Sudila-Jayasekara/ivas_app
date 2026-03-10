import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/live_viva_viewmodel.dart';
import '../widgets/glass_card.dart';

/// Immersive live viva screen — student talks naturally to an AI instructor.
/// Includes manual mic control so students can explicitly start/stop speaking.
class LiveVivaScreen extends StatefulWidget {
  const LiveVivaScreen({super.key});

  @override
  State<LiveVivaScreen> createState() => _LiveVivaScreenState();
}

class _LiveVivaScreenState extends State<LiveVivaScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startViva();
      });
    }
  }

  Future<void> _startViva() async {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final assignmentId = args['assignmentId'] as String;
    final studentName = args['studentName'] as String? ?? 'Student';
    final auth = context.read<AuthViewModel>();
    final vm = context.read<LiveVivaViewModel>();

    await vm.startLiveViva(
      assignmentId: assignmentId,
      studentId: auth.studentId,
      studentName: studentName,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LiveVivaViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  _buildTopBar(vm),
                  if (vm.totalQuestions > 0) _buildProgressBar(vm),
                  Expanded(child: _buildMainContent(vm)),
                  _buildBottomInfo(vm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(LiveVivaViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          // Leave button
          IconButton(
            icon:
                const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
            onPressed: () => _showLeaveDialog(vm),
          ),
          const Expanded(
            child: Text(
              'Live Viva',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Score counter
          if (vm.questionsScored > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${vm.questionsScored}/${vm.totalQuestions}',
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar(LiveVivaViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: vm.progress,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildMainContent(LiveVivaViewModel vm) {
    switch (vm.state) {
      case LiveVivaState.idle:
      case LiveVivaState.connecting:
        return _buildConnectingView();

      case LiveVivaState.active:
        // During active conversation, show instructor or student visual
        // depending on who is speaking
        if (vm.geminiSpeaking) {
          return _buildInstructorSpeakingView();
        }
        // Student's turn — show mic visualization
        return _buildStudentSpeakingView();

      case LiveVivaState.evaluating:
        return _buildEvaluatingView();

      case LiveVivaState.complete:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/results');
        });
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.success),
        );

      case LiveVivaState.error:
        return _buildErrorView(vm);
    }
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 24),
          Text(
            'Connecting to your instructor...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildInstructorSpeakingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInstructorAvatar(isActive: true),
          const SizedBox(height: 32),
          Text(
            'Instructor is speaking...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryLight,
                ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                color: AppTheme.primary.withValues(alpha: 0.3),
                duration: 2000.ms,
              ),
          const SizedBox(height: 16),
          const Text(
            'Listen carefully',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStudentSpeakingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMicVisualization(),
          const SizedBox(height: 32),
          Text(
            'Your turn — speak now',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.accent,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap the mic button below, then answer naturally',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEvaluatingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Evaluating your responses...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your instructor is reviewing your answers',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildErrorView(LiveVivaViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 56),
            const SizedBox(height: 16),
            Text(
              vm.error ?? 'Something went wrong',
              style: const TextStyle(color: AppTheme.error, fontSize: 15),
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

  /// Animated instructor avatar — pulsing circles when speaking
  Widget _buildInstructorAvatar({required bool isActive}) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          if (isActive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 180 + (_pulseController.value * 20),
                  height: 180 + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(
                          alpha: 0.2 * (1 - _pulseController.value)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          // Middle ring
          if (isActive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 150 + (_pulseController.value * 15),
                  height: 150 + (_pulseController.value * 15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(
                        alpha: 0.05 + (0.05 * _pulseController.value)),
                  ),
                );
              },
            ),
          // Avatar circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [AppTheme.primary, AppTheme.primaryLight]
                    : [AppTheme.surfaceLight, AppTheme.surface],
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              Icons.school_rounded,
              size: 48,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Mic visualization — ripple effect for student speaking
  Widget _buildMicVisualization() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final delay = i * 0.33;
                final progress = ((_waveController.value + delay) % 1.0);
                return Container(
                  width: 100 + (progress * 80),
                  height: 100 + (progress * 80),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent
                          .withValues(alpha: 0.3 * (1 - progress)),
                      width: 2,
                    ),
                  ),
                );
              },
            );
          }),
          // Mic circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.accentLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo(LiveVivaViewModel vm) {
    if (vm.state != LiveVivaState.active) {
      return const SizedBox(height: 20);
    }

    final statusText = vm.geminiSpeaking
        ? 'Instructor is speaking...'
        : vm.isMicEnabled
            ? 'Mic is ON — speak now'
            : 'Mic is OFF — tap to start';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        vm.geminiSpeaking ? AppTheme.primary : AppTheme.accent,
                  ),
                )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                    )
                    .fadeIn()
                    .then()
                    .fadeOut(duration: 800.ms),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (vm.questionsScored > 0)
                  Text(
                    '${vm.questionsScored}/${vm.totalQuestions} scored',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: vm.geminiSpeaking
                      ? null
                      : () async {
                          await vm.toggleMic();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: vm.isMicEnabled
                        ? AppTheme.error.withValues(alpha: 0.9)
                        : AppTheme.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.surfaceLight.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(
                    vm.geminiSpeaking
                        ? Icons.hearing_rounded
                        : vm.isMicEnabled
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                  ),
                  label: Text(
                    vm.geminiSpeaking
                        ? 'Wait for instructor to finish'
                        : vm.isMicEnabled
                            ? 'Stop Mic'
                            : 'Start Mic and Talk',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().slideY(begin: 0.3).fadeIn();
  }

  void _showLeaveDialog(LiveVivaViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Viva?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will end your assessment. Your progress so far will be saved.',
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
              vm.endViva();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
