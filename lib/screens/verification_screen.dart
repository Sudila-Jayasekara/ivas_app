import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/verification_viewmodel.dart';
import '../widgets/glass_card.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late String _assignmentId;
  late String _assignmentTitle;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _assignmentId = args['assignmentId'] as String;
    _assignmentTitle = args['assignmentTitle'] as String;

    if (!_initialized) {
      _initialized = true;
      // Defer to avoid notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthViewModel>();
        final vm = context.read<VerificationViewModel>();
        if (vm.state == VerificationState.checking) {
          vm.checkEnrollment(auth.studentId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<VerificationViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Voice Verification',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Assignment info
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.quiz_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Starting Viva For',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11)),
                                  Text(_assignmentTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 48),

                      // Microphone visualization
                      _buildMicVisualization(vm)
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .scale(begin: const Offset(0.8, 0.8)),

                      const SizedBox(height: 32),

                      // Status
                      Text(
                        vm.statusMessage,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _getStatusColor(vm.state),
                                ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 12),

                      // Progress indicator
                      if (vm.state != VerificationState.enrolled &&
                          vm.state != VerificationState.checking)
                        _buildProgressDots(vm),

                      const SizedBox(height: 40),

                      // Action buttons
                      _buildActionButton(vm, auth.studentId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicVisualization(VerificationViewModel vm) {
    final isRecording = vm.state == VerificationState.recording;
    final isEnrolled = vm.state == VerificationState.enrolled;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isRecording ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isEnrolled
                ? const LinearGradient(
                    colors: [AppTheme.success, Color(0xFF059669)])
                : isRecording
                    ? const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                    : AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: (isEnrolled
                        ? AppTheme.success
                        : isRecording
                            ? const Color(0xFFEF4444)
                            : AppTheme.primary)
                    .withValues(alpha: 0.3 + value * 0.2),
                blurRadius: 30 + value * 20,
                spreadRadius: value * 8,
              ),
            ],
          ),
          child: Icon(
            isEnrolled
                ? Icons.check_rounded
                : isRecording
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
            color: Colors.white,
            size: 56,
          ),
        );
      },
    );
  }

  Widget _buildProgressDots(VerificationViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(vm.requiredSamples, (i) {
        final isComplete = i < vm.sampleCount;
        final isCurrent = i == vm.sampleCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isCurrent ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isComplete
                ? AppTheme.success
                : isCurrent
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton(VerificationViewModel vm, String studentId) {
    switch (vm.state) {
      case VerificationState.checking:
      case VerificationState.processing:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primary,
          ),
        );

      case VerificationState.enrolled:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(
                '/viva',
                arguments: {
                  'assignmentId': _assignmentId,
                  'assignmentTitle': _assignmentTitle,
                },
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Viva'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.9, 0.9));

      case VerificationState.recording:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => vm.stopRecordingAndEnroll(studentId),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop Recording'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
          ),
        );

      case VerificationState.error:
        return Column(
          children: [
            Text(vm.error ?? 'An error occurred',
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => vm.reset(),
              child: const Text('Try Again'),
            ),
          ],
        );

      default:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => vm.startRecording(),
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  vm.sampleCount > 0
                      ? 'Record Sample ${vm.sampleCount + 1}/${vm.requiredSamples}'
                      : 'Record Voice Sample',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Skip verification and go directly to viva
                Navigator.of(context).pushReplacementNamed(
                  '/viva',
                  arguments: {
                    'assignmentId': _assignmentId,
                    'assignmentTitle': _assignmentTitle,
                  },
                );
              },
              child: const Text(
                'Skip for now',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        );
    }
  }

  Color _getStatusColor(VerificationState state) {
    switch (state) {
      case VerificationState.enrolled:
        return AppTheme.success;
      case VerificationState.recording:
        return const Color(0xFFEF4444);
      case VerificationState.error:
        return AppTheme.error;
      default:
        return AppTheme.textPrimary;
    }
  }
}
