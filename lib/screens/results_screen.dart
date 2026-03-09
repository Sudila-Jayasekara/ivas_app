import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/viva_viewmodel.dart';
import '../models/session.dart';
import '../widgets/score_gauge.dart';
import '../widgets/glass_card.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viva = context.watch<VivaViewModel>();

    final score = viva.finalScore ?? 0;
    final maxScore = viva.maxScore ?? 1;
    final competencies = viva.competencySummary ?? [];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Header
                Text(
                  'Viva Complete! 🎉',
                  style: Theme.of(context).textTheme.headlineMedium,
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 8),
                Text(
                  viva.completionMessage ?? 'Your assessment has been graded.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 40),

                // Score gauge
                ScoreGauge(
                  score: score,
                  maxScore: maxScore,
                  size: 200,
                ).animate().fadeIn(delay: 400.ms).scale(
                      begin: const Offset(0.6, 0.6),
                      curve: Curves.elasticOut,
                      duration: 1000.ms,
                    ),
                const SizedBox(height: 12),
                Text(
                  _getScoreLabel(score / maxScore),
                  style: TextStyle(
                    color: _getScoreColor(score / maxScore),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 1200.ms),
                const SizedBox(height: 36),

                // Competency breakdown
                if (competencies.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'COMPETENCY BREAKDOWN',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                  const SizedBox(height: 14),
                  ...competencies.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    return _CompetencyCard(competency: c)
                        .animate()
                        .fadeIn(delay: (900 + i * 100).ms)
                        .slideX(begin: 0.05);
                  }),
                ],

                const SizedBox(height: 32),

                // Session summary
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SummaryRow(
                          label: 'Questions Answered',
                          value:
                              '${viva.answeredQuestions}/${viva.totalQuestions}'),
                      const Divider(color: AppTheme.surfaceLight, height: 24),
                      _SummaryRow(
                          label: 'Final Score',
                          value:
                              '${score.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}'),
                      const Divider(color: AppTheme.surfaceLight, height: 24),
                      _SummaryRow(
                          label: 'Percentage',
                          value:
                              '${(score / maxScore * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                ).animate().fadeIn(delay: 1400.ms),

                const SizedBox(height: 32),

                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/home', (route) => false);
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Back to Home'),
                  ),
                ).animate().fadeIn(delay: 1600.ms).slideY(begin: 0.1),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getScoreLabel(double ratio) {
    if (ratio >= 0.9) return 'Outstanding!';
    if (ratio >= 0.8) return 'Excellent!';
    if (ratio >= 0.7) return 'Very Good';
    if (ratio >= 0.6) return 'Good';
    if (ratio >= 0.5) return 'Fair';
    return 'Needs Improvement';
  }

  Color _getScoreColor(double ratio) {
    if (ratio >= 0.8) return AppTheme.success;
    if (ratio >= 0.6) return AppTheme.accent;
    if (ratio >= 0.4) return AppTheme.warning;
    return AppTheme.error;
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────

class _CompetencyCard extends StatelessWidget {
  final CompetencySummary competency;

  const _CompetencyCard({required this.competency});

  @override
  Widget build(BuildContext context) {
    final ratio = competency.max > 0 ? competency.score / competency.max : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                competency.competency.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${competency.score.toStringAsFixed(1)}/${competency.max.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _getColor(ratio),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(_getColor(ratio)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(double ratio) {
    if (ratio >= 0.8) return AppTheme.success;
    if (ratio >= 0.6) return AppTheme.accent;
    if (ratio >= 0.4) return AppTheme.warning;
    return AppTheme.error;
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
