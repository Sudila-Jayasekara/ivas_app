import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../widgets/glass_card.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AdminViewModel>();
      vm.loadSystemInfo();
      vm.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    // Stop auto-refresh when leaving screen
    // Can't use context.read in dispose, so this is handled by the ViewModel lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final vm = context.watch<AdminViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: vm.isLoading && vm.health == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: () => vm.loadSystemInfo(),
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // ── Header ──
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Admin Panel',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(fontSize: 22)),
                                  const SizedBox(height: 4),
                                  Text(auth.user?.name ?? 'Admin',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                // Instructor dashboard access
                                GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushNamed('/instructor/home'),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.school_rounded,
                                        color: AppTheme.accentLight, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    vm.stopAutoRefresh();
                                    auth.logout();
                                    Navigator.of(context)
                                        .pushReplacementNamed('/login');
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        AppTheme.accent,
                                        AppTheme.primary
                                      ]),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.logout_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      // ── Messages ──
                      if (vm.error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(vm.error!,
                                    style: const TextStyle(
                                        color: AppTheme.error, fontSize: 13)),
                              ),
                              GestureDetector(
                                onTap: vm.clearMessages,
                                child: const Icon(Icons.close,
                                    color: AppTheme.error, size: 16),
                              ),
                            ],
                          ),
                        ),

                      if (vm.successMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppTheme.success, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(vm.successMessage!,
                                    style: const TextStyle(
                                        color: AppTheme.success, fontSize: 13)),
                              ),
                              GestureDetector(
                                onTap: vm.clearMessages,
                                child: const Icon(Icons.close,
                                    color: AppTheme.success, size: 16),
                              ),
                            ],
                          ),
                        ),

                      // ── System Health Card ──
                      _SectionHeader(title: 'SYSTEM HEALTH'),
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        borderColor:
                            (vm.isHealthy ? AppTheme.success : AppTheme.error)
                                .withValues(alpha: 0.2),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: (vm.isHealthy
                                            ? AppTheme.success
                                            : AppTheme.error)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    vm.isHealthy
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: vm.isHealthy
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vm.isHealthy
                                            ? 'All Systems Go'
                                            : 'Issues Detected',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'Status: ${vm.health?['status'] ?? 'Unknown'}',
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: AppTheme.textSecondary),
                                  onPressed: () => vm.refreshHealth(),
                                ),
                              ],
                            ),
                            if (vm.health != null) ...[
                              const SizedBox(height: 14),
                              const Divider(
                                  color: AppTheme.surfaceLight, height: 1),
                              const SizedBox(height: 14),
                              _buildHealthDetails(vm.health!),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                      const SizedBox(height: 20),

                      // ── Readiness ──
                      Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    vm.isReady
                                        ? Icons.power_settings_new_rounded
                                        : Icons.power_off_rounded,
                                    color: vm.isReady
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(vm.isReady ? 'Ready' : 'Not Ready',
                                      style: TextStyle(
                                          color: vm.isReady
                                              ? AppTheme.success
                                              : AppTheme.warning,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Icon(Icons.dns_rounded,
                                      color: AppTheme.primaryLight, size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    vm.health?['database'] as String? ??
                                        vm.health?['db_status'] as String? ??
                                        'Unknown',
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const Text('Database',
                                      style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),

                      // ── LLM Provider Card ──
                      _SectionHeader(title: 'LLM PROVIDER'),
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        borderColor: AppTheme.primary.withValues(alpha: 0.2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.psychology_rounded,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Current: ${vm.currentProvider}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      if (vm.llmProvider?['model'] != null)
                                        Text(
                                          'Model: ${vm.llmProvider!['model']}',
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: AppTheme.textSecondary),
                                  onPressed: () => vm.refreshLLM(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // LLM Health
                            if (vm.llmHealth != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LLM Health',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11)),
                                    const SizedBox(height: 4),
                                    ...vm.llmHealth!.entries
                                        .where((e) => e.key != 'status')
                                        .map((e) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 2),
                                              child: Text(
                                                '${e.key}: ${e.value}',
                                                style: const TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 12),
                                              ),
                                            )),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Switch buttons
                            const Text('Switch Provider',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _ProviderButton(
                                  label: 'OpenAI',
                                  isActive: vm.currentProvider
                                      .toLowerCase()
                                      .contains('openai'),
                                  onTap: () => vm.switchProvider('openai'),
                                ),
                                const SizedBox(width: 8),
                                _ProviderButton(
                                  label: 'Ollama',
                                  isActive: vm.currentProvider
                                      .toLowerCase()
                                      .contains('ollama'),
                                  onTap: () => vm.switchProvider('ollama'),
                                ),
                                const SizedBox(width: 8),
                                _ProviderButton(
                                  label: 'Gemini',
                                  isActive: vm.currentProvider
                                      .toLowerCase()
                                      .contains('gemini'),
                                  onTap: () => vm.switchProvider('gemini'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHealthDetails(Map<String, dynamic> health) {
    final entries = health.entries.where((e) => e.key != 'status').toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      children: entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(e.key,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              Text('${e.value}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTheme.textSecondary,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ProviderButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            color: isActive ? null : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      ),
    );
  }
}
