import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TalkingWaveform extends StatefulWidget {
  final bool isSpeaking;
  final Color? color;
  final int barCount;
  final double? soundLevel;

  const TalkingWaveform({
    super.key,
    required this.isSpeaking,
    this.color,
    this.barCount = 30,
    this.soundLevel,
  });

  @override
  State<TalkingWaveform> createState() => _TalkingWaveformState();
}

class _TalkingWaveformState extends State<TalkingWaveform>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + _random.nextInt(400)),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.1,
        end: 0.4 + _random.nextDouble() * 0.6,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isSpeaking) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    for (var controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.animateTo(0.1,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void didUpdateWidget(TalkingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking != oldWidget.isSpeaking) {
      if (widget.isSpeaking) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              double heightFactor = _animations[index].value;

              // If real sound levels are provided, give them priority but keep some natural jitter
              if (widget.soundLevel != null && widget.isSpeaking) {
                // soundLevel is typically in dB (e.g. -40 to 10 or 0 to 40 depending on platform)
                // Normalize it roughly to 0.2 - 1.0 range
                double normalized = (widget.soundLevel! + 2) / 10;
                normalized = normalized.clamp(0.1, 1.0);
                heightFactor =
                    normalized * (0.7 + _animations[index].value * 0.3);
              }

              return Container(
                width: 3,
                height: 40 * heightFactor,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color ?? AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    if (widget.isSpeaking)
                      BoxShadow(
                        color: (widget.color ?? AppTheme.primaryLight)
                            .withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
