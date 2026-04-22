import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final bool enableBlur;

  const GlassContainer({
    Key? key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.2,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.enableBlur = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderRadiusGeometry = BorderRadius.circular(borderRadius);
    final resolvedColor = color ?? Colors.white.withValues(alpha: opacity);

    Widget container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: borderRadiusGeometry,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );

    if (enableBlur) {
      return RepaintBoundary(
        child: Container(
          margin: margin,
          width: width,
          height: height,
          decoration: BoxDecoration(borderRadius: borderRadiusGeometry),
          child: ClipRRect(
            borderRadius: borderRadiusGeometry,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: container,
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.transparent, // Ensure no extra layer
          borderRadius: borderRadiusGeometry,
        ),
        child: container,
      ),
    );
  }
}
