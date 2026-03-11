import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LiquidOrb extends StatefulWidget {
  final double size;
  const LiquidOrb({Key? key, this.size = 200}) : super(key: key);

  @override
  _LiquidOrbState createState() => _LiquidOrbState();
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
    return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // Inner gradient that rotates
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * pi,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              const Color(0xFF1E3A8A), // Dark blue
                              const Color(0xFFC084FC), // Purple
                              const Color(0xFFFDE047), // Yellow/gold
                              const Color(0xFFE0E7FF), // Light blue
                              const Color(0xFF1E3A8A),
                            ],
                            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                            center: Alignment.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Middle liquid layer
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: -_controller.value * 2 * pi * 0.7,
                      child: Transform.scale(
                        scale: 1.2,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black87,
                                Colors.transparent,
                              ],
                              stops: [0.1, 0.6, 1.0],
                              focal: Alignment(-0.2, -0.2),
                              focalRadius: 0.1,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Glass reflection overlay
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 0.95,
          end: 1.05,
          duration: 3.seconds,
          curve: Curves.easeInOutSine,
        );
  }
}
