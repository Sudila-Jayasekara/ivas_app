import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/glass_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      context.read<HomeViewModel>().loadData(auth.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final home = context.watch<HomeViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: home.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : CustomScrollView(
                  slivers: [
                    // Greeting header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back,',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        auth.student?.name ?? 'Student',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    auth.logout();
                                    Navigator.of(context)
                                        .pushReplacementNamed('/login');
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (auth.student?.name ?? 'S')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms),
                    ),

                    // Active sessions
                    if (home.activeSessions.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Text(
                            'IN PROGRESS',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppTheme.accent,
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final session = home.activeSessions[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 6),
                              child: _ActiveSessionCard(
                                title: home
                                    .getAssignmentTitle(session.assignmentId),
                                status: session.status,
                                questionsAnswered: session.responsesGiven,
                                totalQuestions: session.questionsAsked,
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    '/viva',
                                    arguments: {
                                      'assignmentId': session.assignmentId,
                                      'assignmentTitle':
                                          home.getAssignmentTitle(
                                              session.assignmentId),
                                      'sessionId': session.sessionId,
                                    },
                                  );
                                },
                              ),
                            )
                                .animate()
                                .fadeIn(delay: (100 * index).ms)
                                .slideX(begin: 0.05);
                          },
                          childCount: home.activeSessions.length,
                        ),
                      ),
                    ],

                    // Available Vivas section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                        child: Text(
                          'AVAILABLE VIVAS',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 1.5,
                                    fontSize: 12,
                                  ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final assignment = home.assignments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 6),
                            child: _AssignmentCard(
                              assignment: assignment,
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/verification',
                                  arguments: {
                                    'assignmentId': assignment.assignmentId,
                                    'assignmentTitle': assignment.title,
                                  },
                                );
                              },
                            ),
                          )
                              .animate()
                              .fadeIn(delay: (200 + 100 * index).ms)
                              .slideY(begin: 0.05);
                        },
                        childCount: home.assignments.length,
                      ),
                    ),

                    // Past sessions
                    if (home.completedSessions.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                          child: Text(
                            'PAST SESSIONS',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final session = home.completedSessions[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 4),
                              child: _PastSessionTile(
                                title: home
                                    .getAssignmentTitle(session.assignmentId),
                                date: session.completedAt,
                                questionsAnswered: session.responsesGiven,
                              ),
                            ).animate().fadeIn(delay: (300 + 80 * index).ms);
                          },
                          childCount: home.completedSessions.length,
                        ),
                      ),
                    ],

                    // Bottom spacing
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final dynamic assignment;
  final VoidCallback onTap;

  const _AssignmentCard({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final competencies = (assignment.competencies as List<String>);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: AppTheme.primary.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Difficulty: ${assignment.difficultyMin}–${assignment.difficultyMax}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textSecondary, size: 16),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: competencies.map((c) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      color: AppTheme.accentLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final String title;
  final String status;
  final int questionsAnswered;
  final int totalQuestions;
  final VoidCallback onTap;

  const _ActiveSessionCard({
    required this.title,
    required this.status,
    required this.questionsAnswered,
    required this.totalQuestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppTheme.accent.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppTheme.accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$questionsAnswered/$totalQuestions answered • ${status == 'paused' ? 'Paused' : 'In Progress'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppTheme.accent,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.accent, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PastSessionTile extends StatelessWidget {
  final String title;
  final DateTime? date;
  final int questionsAnswered;

  const _PastSessionTile({
    required this.title,
    this.date,
    required this.questionsAnswered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: AppTheme.success, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontSize: 14)),
                Text(
                  '$questionsAnswered questions • ${date != null ? _formatDate(date!) : 'Completed'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
