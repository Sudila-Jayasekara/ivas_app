import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/student.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController =
      TextEditingController(text: 'student.test@gradeloop.com');
  final _passwordController = TextEditingController(text: 'Test@12345!');
  bool _obscurePassword = true;
  int _selectedRoleIndex = 0;

  static const _roleOptions = [
    {
      'label': 'Student',
      'email': 'student.test@gradeloop.com',
      'icon': Icons.person_rounded
    },
    {
      'label': 'Instructor',
      'email': 'instructor.test@gradeloop.com',
      'icon': Icons.school_rounded
    },
    {
      'label': 'Admin',
      'email': 'admin.test@gradeloop.com',
      'icon': Icons.admin_panel_settings_rounded
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectRole(int index) {
    setState(() {
      _selectedRoleIndex = index;
      _emailController.text = _roleOptions[index]['email'] as String;
    });
  }

  Future<void> _handleLogin() async {
    final auth = context.read<AuthViewModel>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      final role = auth.userRole;
      switch (role) {
        case UserRole.student:
          Navigator.of(context).pushReplacementNamed('/home');
          break;
        case UserRole.instructor:
          Navigator.of(context).pushReplacementNamed('/instructor/home');
          break;
        case UserRole.admin:
          Navigator.of(context).pushReplacementNamed('/admin/home');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.5, 0.5)),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'IVAS',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 36,
                          letterSpacing: 4,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                AppTheme.primaryLight,
                                AppTheme.accentLight
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 120, 40)),
                        ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Intelligent Viva Assessment',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          letterSpacing: 1,
                        ),
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                  const SizedBox(height: 48),

                  // Role selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_roleOptions.length, (i) {
                      final opt = _roleOptions[i];
                      final isSelected = _selectedRoleIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: () => _selectRole(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient:
                                  isSelected ? AppTheme.primaryGradient : null,
                              color: isSelected
                                  ? null
                                  : AppTheme.surfaceLight
                                      .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(opt['icon'] as IconData,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  opt['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ).animate().fadeIn(delay: 450.ms),
                  const SizedBox(height: 24),

                  // Email field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppTheme.textSecondary),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),

                  // Error message
                  Consumer<AuthViewModel>(
                    builder: (context, auth, _) {
                      if (auth.error != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                      color: AppTheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ).animate().shake(hz: 3, duration: 400.ms);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 28),

                  // Login button
                  Consumer<AuthViewModel>(
                    builder: (context, auth, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleLogin,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                  const SizedBox(height: 24),

                  // Footer
                  Text(
                    'GradeLoop • IVAS v1.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                  ).animate().fadeIn(delay: 900.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
