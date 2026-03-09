import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/instructor_viewmodel.dart';
import '../widgets/glass_card.dart';

class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({super.key});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _assignmentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final id = args?['assignmentId'] as String?;
    if (id != null && id != _assignmentId) {
      _assignmentId = id;
      context.read<InstructorViewModel>().loadAssignmentDetail(id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InstructorViewModel>();
    final assignment = vm.assignments.cast().firstWhere(
          (a) => a.assignmentId == _assignmentId,
          orElse: () => null,
        );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back + title ──
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
                      child: Text(
                        assignment?.title ?? 'Assignment',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tabs ──
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Grading Criteria'),
                    Tab(text: 'Questions'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Body ──
              Expanded(
                child: vm.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _CriteriaTab(
                            vm: vm,
                            assignmentId: _assignmentId ?? '',
                          ),
                          _QuestionsTab(
                            vm: vm,
                            assignmentId: _assignmentId ?? '',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Grading Criteria Tab ───────────────────────────────────────
class _CriteriaTab extends StatelessWidget {
  final InstructorViewModel vm;
  final String assignmentId;
  const _CriteriaTab({required this.vm, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Generate button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: vm.isGenerating
                  ? null
                  : () async {
                      final result = await vm.generateCriteria(assignmentId);
                      if (result != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Generated ${result.totalGenerated} criteria'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
              icon: vm.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label:
                  Text(vm.isGenerating ? 'Generating...' : 'Generate Criteria'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: vm.criteria.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grading_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('No grading criteria yet',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      const Text('Tap Generate to create criteria with AI',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  itemCount: vm.criteria.length,
                  itemBuilder: (context, i) {
                    final c = vm.criteria[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(c.competency,
                                      style: const TextStyle(
                                          color: AppTheme.accentLight,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      'Level ${c.difficultyLevel}: ${c.levelLabel}',
                                      style: const TextStyle(
                                          color: AppTheme.primaryLight,
                                          fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(c.levelDescription,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(c.markingCriteria,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (60 * i).ms);
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Questions Tab ──────────────────────────────────────────────
class _QuestionsTab extends StatelessWidget {
  final InstructorViewModel vm;
  final String assignmentId;
  const _QuestionsTab({required this.vm, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: vm.isGenerating
                  ? null
                  : () async {
                      final result = await vm.generateQuestions(assignmentId);
                      if (result != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Generated ${result.totalGenerated} questions'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
              icon: vm.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.quiz_rounded, size: 18),
              label: Text(
                  vm.isGenerating ? 'Generating...' : 'Generate Questions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: vm.questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('No questions yet',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      const Text(
                          'Generate grading criteria first, then questions',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  itemCount: vm.questions.length,
                  itemBuilder: (context, i) {
                    final q = vm.questions[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${i + 1}',
                                        style: const TextStyle(
                                            color: AppTheme.primaryLight,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(q.competency,
                                      style: const TextStyle(
                                          color: AppTheme.accentLight,
                                          fontSize: 10)),
                                ),
                                const SizedBox(width: 6),
                                Text('Diff: ${q.difficulty}',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10)),
                                const Spacer(),
                                Text('${q.maxPoints} pts',
                                    style: const TextStyle(
                                        color: AppTheme.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(q.questionText,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 13)),
                            if (q.expectedAnswer.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  q.expectedAnswer,
                                  style: const TextStyle(
                                      color: AppTheme.success, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (60 * i).ms);
                  },
                ),
        ),
      ],
    );
  }
}
