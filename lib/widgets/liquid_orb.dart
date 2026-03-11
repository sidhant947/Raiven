import 'dart:math';
import 'package:flutter/material.dart';

class LiquidOrb extends StatefulWidget {
  final double size;
  const LiquidOrb({Key? key, this.size = 200}) : super(key: key);

  @override
  State<LiquidOrb> createState() => _LiquidOrbState();
}

class _LiquidOrbState extends State<LiquidOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _controller.value;
            final breathScale =
                0.95 + 0.1 * (0.5 + 0.5 * sin(value * 2 * pi * 0.2));
            return Transform.scale(scale: breathScale, child: child);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  // Inner gradient that rotates
                  _RotatingGradient(controller: _controller),
                  // Middle liquid layer
                  _LiquidLayer(controller: _controller),
                  // Glass reflection overlay — static, no rebuild needed
                  const _GlassReflection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotatingGradient extends StatelessWidget {
  final AnimationController controller;
  const _RotatingGradient({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(angle: controller.value * 2 * pi, child: child);
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: SweepGradient(
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFFC084FC),
              Color(0xFFFDE047),
              Color(0xFFE0E7FF),
              Color(0xFF1E3A8A),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            center: Alignment.center,
          ),
        ),
      ),
    );
  }
}

class _LiquidLayer extends StatelessWidget {
  final AnimationController controller;
  const _LiquidLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: -controller.value * 2 * pi * 0.7,
          child: child,
        );
      },
      child: Transform.scale(
        scale: 1.2,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.transparent, Colors.black87, Colors.transparent],
              stops: [0.1, 0.6, 1.0],
              focal: Alignment(-0.2, -0.2),
              focalRadius: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassReflection extends StatelessWidget {
  const _GlassReflection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.1),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
    );
  }
}
