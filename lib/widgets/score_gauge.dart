import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScoreGauge extends StatefulWidget {
  final double score;
  final double maxScore;
  final double size;
  final Duration animationDuration;

  const ScoreGauge({
    super.key,
    required this.score,
    required this.maxScore,
    this.size = 180,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<ScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(begin: 0, end: widget.score / widget.maxScore)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor(double ratio) {
    if (ratio >= 0.8) return AppTheme.success;
    if (ratio >= 0.6) return AppTheme.accent;
    if (ratio >= 0.4) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final ratio = _animation.value;
        final color = _getScoreColor(ratio);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  progress: 1.0,
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 12,
                ),
              ),
              // Progress arc
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  progress: ratio,
                  color: color,
                  strokeWidth: 12,
                  glow: true,
                ),
              ),
              // Score text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (widget.score * ratio / (widget.score / widget.maxScore))
                        .toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: widget.size * 0.22,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                  ),
                  Text(
                    'out of ${widget.maxScore.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: widget.size * 0.08,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool glow;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.glow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -pi * 0.75;
    const totalAngle = pi * 1.5;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalAngle * progress,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalAngle * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
