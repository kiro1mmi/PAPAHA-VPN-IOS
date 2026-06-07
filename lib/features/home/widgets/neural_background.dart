import 'dart:math';
import 'package:flutter/material.dart';

/// Flow-field particle animation.
/// White particles on black background.
/// Activates only when [isActive] is true.
class NeuralBackground extends StatefulWidget {
  final bool isActive;
  final Color color;
  final int particleCount;
  final double speed;
  final double trailOpacity;

  const NeuralBackground({
    super.key,
    required this.isActive,
    this.color = Colors.white,
    this.particleCount = 500,
    this.speed = 1.0,
    this.trailOpacity = 0.12,
  });

  @override
  State<NeuralBackground> createState() => _NeuralBackgroundState();
}

class _NeuralBackgroundState extends State<NeuralBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  Size _lastSize = Size.zero;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _particles = [];
    if (widget.isActive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(NeuralBackground old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.repeat();
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
      // Clear trails by resetting particles
      _particles.clear();
    }
  }

  void _initParticles(Size size) {
    _lastSize = size;
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle.random(_rng, size),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.expand();

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != _lastSize || _particles.isEmpty) {
        _initParticles(size);
      }
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _NeuralPainter(
              particles: _particles,
              color: widget.color,
              speed: widget.speed,
              trailOpacity: widget.trailOpacity,
              size: size,
              rng: _rng,
            ),
            size: size,
          );
        },
      );
    });
  }
}

// ─── Particle ────────────────────────────────────────────────────────────────

class _Particle {
  double x, y, vx, vy;
  int age;
  int life;

  _Particle({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.age = 0,
    required this.life,
  });

  factory _Particle.random(Random rng, Size size) => _Particle(
        x: rng.nextDouble() * size.width,
        y: rng.nextDouble() * size.height,
        life: rng.nextInt(200) + 100,
        age: rng.nextInt(150), // stagger initial age
      );

  void reset(Random rng, Size size) {
    x = rng.nextDouble() * size.width;
    y = rng.nextDouble() * size.height;
    vx = 0;
    vy = 0;
    age = 0;
    life = rng.nextInt(200) + 100;
  }

  void update(Size size, double speed) {
    // Pure vertical flow: particles fall straight down
    vy += 0.4 * speed;
    vy *= 0.96; // gentle friction
    vx *= 0.90; // damp horizontal completely
    x += vx;
    y += vy;
    age++;
    // Wrap only vertically — when off bottom, reset to top
    if (y > size.height) {
      y = 0;
      x = Random().nextDouble() * size.width;
      vx = 0;
      vy = 0;
      age = 0;
    }
    if (x < 0) x = size.width;
    if (x > size.width) x = 0;
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _NeuralPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double speed;
  final double trailOpacity;
  final Size size;
  final Random rng;

  _NeuralPainter({
    required this.particles,
    required this.color,
    required this.speed,
    required this.trailOpacity,
    required this.size,
    required this.rng,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Trail: semi-transparent black overlay
    final trailPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, trailOpacity);
    canvas.drawRect(Offset.zero & canvasSize, trailPaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      p.update(size, speed);

      if (p.age > p.life) {
        p.reset(rng, size);
        continue;
      }

      // Fade in/out
      final t = (p.age / p.life - 0.5).abs() * 2.0; // 0=center(full) 1=edge(zero)
      final alpha = ((1.0 - t) * 200).clamp(0.0, 255.0).toInt();
      if (alpha < 3) continue;

      dotPaint.color = color.withAlpha(alpha);
      canvas.drawRect(
        Rect.fromLTWH(p.x, p.y, 1.5, 1.5),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralPainter old) => true;
}
