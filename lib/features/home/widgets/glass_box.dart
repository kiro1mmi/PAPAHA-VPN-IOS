import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass3D — blur + subtle tint + top-left highlight border.
class GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 14,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 30,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              color: Colors.black.withAlpha(200),
              border: Border.all(
                color: Colors.white.withAlpha(55),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
