import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class QuestionCard extends StatelessWidget {
  final String questionText;
  final String competency;
  final int difficulty;
  final bool isFollowUp;
  final int questionNumber;
  final int totalQuestions;

  const QuestionCard({
    super.key,
    required this.questionText,
    required this.competency,
    required this.difficulty,
    this.isFollowUp = false,
    required this.questionNumber,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Q$questionNumber/$totalQuestions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  competency.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.accentLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (isFollowUp)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FOLLOW-UP',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              // Difficulty dots
              ...List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < difficulty
                          ? AppTheme.accent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          // Question text
          Text(
            questionText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  height: 1.5,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
