import 'package:flutter/material.dart';
import 'liquid_orb.dart';

class MainBackground extends StatefulWidget {
  final Widget child;
  const MainBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<MainBackground> createState() => _MainBackgroundState();
}

class _MainBackgroundState extends State<MainBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background layer isolated with RepaintBoundary
        RepaintBoundary(
          child: _StaticBackgroundLayers(animation: _bgAnimationController),
        ),
        
        // Content layer
        RepaintBoundary(
          child: widget.child,
        ),
      ],
    );
  }
}

class _StaticBackgroundLayers extends StatelessWidget {
  final Animation<double> animation;
  const _StaticBackgroundLayers({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFC7D2E6),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E1),
                  Color(0xFF94A3B8),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -100,
          child: Opacity(
            opacity: 0.4,
            child: LiquidOrb(size: 400, animation: animation),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Opacity(
            opacity: 0.3,
            child: LiquidOrb(size: 500, animation: animation),
          ),
        ),
        Positioned(
          top: 300,
          left: -50,
          child: Opacity(
            opacity: 0.2,
            child: LiquidOrb(size: 200, animation: animation),
          ),
        ),
      ],
    );
  }
}
