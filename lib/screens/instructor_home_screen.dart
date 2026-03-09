import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/instructor_viewmodel.dart';
import '../widgets/glass_card.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      context.read<InstructorViewModel>().loadDashboard(auth.userId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<InstructorViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructor Dashboard',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(auth.user?.name ?? 'Instructor',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        auth.logout();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppTheme.accent, AppTheme.primary]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── Tabs ──
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
                    Tab(text: 'Assignments'),
                    Tab(text: 'Assessments'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Content ──
              Expanded(
                child: vm.isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _AssignmentsTab(vm: vm),
                          _AssessmentsTab(vm: vm, instructorId: auth.userId),
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

// ─── Assignments Tab ────────────────────────────────────────────
class _AssignmentsTab extends StatelessWidget {
  final InstructorViewModel vm;
  const _AssignmentsTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.assignments.isEmpty) {
      return const Center(
        child: Text('No assignments found',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: vm.assignments.length,
      itemBuilder: (context, i) {
        final a = vm.assignments[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed(
                '/instructor/assignment',
                arguments: {'assignmentId': a.assignmentId},
              );
            },
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: AppTheme.primary.withValues(alpha: 0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Course: ${a.courseId} • Difficulty ${a.difficultyMin}–${a.difficultyMax}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: a.competencies.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c,
                            style: const TextStyle(
                                color: AppTheme.accentLight, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: 0.03),
        );
      },
    );
  }
}

// ─── Assessments Tab ────────────────────────────────────────────
class _AssessmentsTab extends StatelessWidget {
  final InstructorViewModel vm;
  final String instructorId;
  const _AssessmentsTab({required this.vm, required this.instructorId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children:
                [null, 'in_progress', 'completed', 'abandoned'].map((status) {
              final label = status ?? 'All';
              final isSelected = vm.statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label[0].toUpperCase() + label.substring(1)),
                  selected: isSelected,
                  onSelected: (_) {
                    vm.setStatusFilter(status);
                    vm.refreshAssessments(instructorId);
                  },
                  selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                  backgroundColor: AppTheme.surfaceLight,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primary
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.assessments.isEmpty
              ? const Center(
                  child: Text('No assessments found',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  itemCount: vm.assessments.length,
                  itemBuilder: (context, i) {
                    final a = vm.assessments[i];
                    final sessionId =
                        a['session_id'] as String? ?? a['id'] as String? ?? '';
                    final status = a['status'] as String? ?? 'unknown';
                    final studentId = a['student_id'] as String? ?? '';
                    final assignmentId = a['assignment_id'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/instructor/transcript',
                            arguments: {'sessionId': sessionId},
                          );
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _statusColor(status)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_statusIcon(status),
                                    color: _statusColor(status), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vm.getAssignmentTitle(assignmentId),
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Student: ${studentId.length > 8 ? '${studentId.substring(0, 8)}...' : studentId} • $status',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.textSecondary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: (60 * i).ms);
                  },
                ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'in_progress':
        return AppTheme.accent;
      case 'abandoned':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'in_progress':
        return Icons.play_circle_outline;
      case 'abandoned':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
