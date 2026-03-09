import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/instructor_viewmodel.dart';
import '../widgets/glass_card.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  String? _sessionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final id = args?['sessionId'] as String?;
    if (id != null && id != _sessionId) {
      _sessionId = id;
      context.read<InstructorViewModel>().loadTranscript(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InstructorViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Session Transcript',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontSize: 18)),
                          Text(
                            _sessionId != null
                                ? 'ID: ${_sessionId!.length > 12 ? '${_sessionId!.substring(0, 12)}...' : _sessionId}'
                                : '',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Content ──
              Expanded(
                child: vm.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : vm.error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.error, size: 40),
                                const SizedBox(height: 12),
                                Text(vm.error!,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : _buildTranscript(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscript(BuildContext context, InstructorViewModel vm) {
    final transcript = vm.transcript;
    if (transcript == null) {
      return const Center(
        child: Text('No transcript data',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    // Extract session info from transcript
    final session = transcript['session'] as Map<String, dynamic>? ?? {};
    final responses = transcript['responses'] as List? ??
        transcript['transcript'] as List? ??
        [];
    final status =
        session['status'] as String? ?? transcript['status'] as String? ?? '';
    final finalScore = (session['final_score'] as num?)?.toDouble() ??
        (transcript['final_score'] as num?)?.toDouble();
    final maxScore = (session['max_score'] as num?)?.toDouble() ??
        (transcript['max_score'] as num?)?.toDouble();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Session summary card
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: AppTheme.primary.withValues(alpha: 0.2),
          child: Row(
            children: [
              _InfoChip(label: 'Status', value: status),
              if (finalScore != null) ...[
                const SizedBox(width: 16),
                _InfoChip(
                  label: 'Score',
                  value:
                      '${finalScore.toStringAsFixed(1)}${maxScore != null ? ' / ${maxScore.toStringAsFixed(0)}' : ''}',
                ),
              ],
              const SizedBox(width: 16),
              _InfoChip(label: 'Responses', value: '${responses.length}'),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Responses
        ...List.generate(responses.length, (i) {
          final r = responses[i] as Map<String, dynamic>;
          final question = r['question_text'] as String? ??
              r['question'] as String? ??
              'Question ${i + 1}';
          final answer = r['response_text'] as String? ??
              r['answer'] as String? ??
              r['response'] as String? ??
              '';
          final score = r['evaluation_score'] as num?;
          final feedback = r['evaluation_feedback'] as String? ??
              r['feedback'] as String? ??
              '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('Q${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(question,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (score != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${score.toStringAsFixed(1)} pts',
                              style: const TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Answer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(answer.isEmpty ? '(no response)' : answer,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  // Feedback
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.15)),
                      ),
                      child: Text(feedback,
                          style: const TextStyle(
                              color: AppTheme.accentLight, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(delay: (80 * i).ms).slideY(begin: 0.03);
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
