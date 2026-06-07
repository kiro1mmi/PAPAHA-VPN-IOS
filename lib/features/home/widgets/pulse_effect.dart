import 'package:flutter/material.dart';

/// Rounded-rectangle waves pulsing outward from a given center offset.
/// Shape matches the toggle silhouette.
/// Waves start thick and slow down / thin out toward edges.
class PulseEffect extends StatefulWidget {
  final bool isActive;
  /// Vertical fraction (0.0 = top, 1.0 = bottom) where the toggle center is.
  /// This is passed from the parent to align waves exactly with the toggle.
  final double centerFraction;

  const PulseEffect({
    super.key,
    required this.isActive,
    this.centerFraction = 0.55,
  });

  @override
  State<PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<PulseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    if (widget.isActive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(PulseEffect old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.repeat();
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && !_ctrl.isAnimating) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight * widget.centerFraction;
        final centerX = constraints.maxWidth / 2;

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _PulsePainter(
                progress: _ctrl.value,
                isActive: widget.isActive,
                center: Offset(centerX, centerY),
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            );
          },
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final Offset center;

  _PulsePainter({
    required this.progress,
    required this.isActive,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    // Toggle base dimensions — matches VerticalToggle exactly
    const baseWidth = 72.0;
    const baseHeight = 140.0;
    const baseRadius = 36.0;

    // 5 waves
    const waveCount = 5;
    for (int i = 0; i < waveCount; i++) {
      final phase = (progress + i / waveCount) % 1.0;
      // Start from scale 1.0 (toggle edge) and grow outward
      final scale = 1.0 + phase * 5.0;

      // Opacity: starts strong, fades toward edges
      final opacity = (1.0 - phase) * 0.40;

      // Stroke width: starts thick (6.5px at toggle edge), thins toward edges
      final strokeWidth = 6.5 * (1.0 - phase) + 1.0;

      if (opacity < 0.01) continue;

      final w = baseWidth * scale;
      final h = baseHeight * scale;
      final r = baseRadius * scale;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: h),
        Radius.circular(r),
      );

      final paint = Paint()
        ..color = const Color(0xFF4CAF50).withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.progress != progress || old.isActive != isActive || old.center != center;
}
