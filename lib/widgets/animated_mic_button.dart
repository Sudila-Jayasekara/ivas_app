import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedMicButton extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final VoidCallback onTap;
  final double size;

  const AnimatedMicButton({
    super.key,
    required this.isListening,
    this.isProcessing = false,
    required this.onTap,
    this.size = 80,
  });

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _spinController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ripple1;
  late Animation<double> _ripple2;
  late Animation<double> _ripple3;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ripple1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _ripple2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
      ),
    );
    _ripple3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _spinAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_spinController);
  }

  @override
  void didUpdateWidget(AnimatedMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
      _rippleController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _rippleController.stop();
      _rippleController.reset();
    }

    if (widget.isProcessing) {
      _spinController.repeat();
    } else {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_pulseController, _rippleController, _spinController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple circles
              if (widget.isListening) ...[
                _buildRipple(_ripple1.value),
                _buildRipple(_ripple2.value),
                _buildRipple(_ripple3.value),
              ],
              // Processing spinner background
              if (widget.isProcessing)
                RotationTransition(
                  turns: _spinAnimation,
                  child: Container(
                    width: widget.size + 12,
                    height: widget.size + 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.5),
                        width: 4,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  ),
                ),
              // Main button
              ScaleTransition(
                scale: _pulseAnimation,
                child: child,
              ),
            ],
          );
        },
        child: GestureDetector(
          onTap: widget.isProcessing ? null : widget.onTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.isListening
                  ? const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : widget.isProcessing
                      ? const LinearGradient(
                          colors: [
                            AppTheme.surfaceLight,
                            AppTheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: (widget.isListening
                          ? const Color(0xFFEF4444)
                          : widget.isProcessing
                              ? AppTheme.accent
                              : AppTheme.primary)
                      .withValues(alpha: 0.4),
                  blurRadius: widget.isProcessing ? 12 : 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: widget.isProcessing
                ? const Center(
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppTheme.accent,
                      size: 32,
                    ),
                  )
                : Icon(
                    widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: widget.size * 0.4,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRipple(double value) {
    return Container(
      width: widget.size + (widget.size * 0.8 * value),
      height: widget.size + (widget.size * 0.8 * value),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3 * (1 - value)),
          width: 2,
        ),
      ),
    );
  }
}
