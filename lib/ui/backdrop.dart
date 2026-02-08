import 'dart:ui';

import 'package:flutter/material.dart';

class BoidsBackdrop extends StatelessWidget {
  const BoidsBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.4),
          radius: 1.2,
          colors: [
            Color(0xFF0A2033),
            Color(0xFF070A10),
            Color(0xFF05060B),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class BoidsGrain extends StatelessWidget {
  const BoidsGrain({super.key, this.opacity = 0.06});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: const CustomPaint(painter: _GrainPainter()),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  static final Paint _p = Paint()
    ..strokeWidth = 1
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    const double step = 18;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final double a = ((x * 13 + y * 7) % 29) / 29.0;
        _p.color = Color.fromARGB((10 + a * 30).round(), 255, 255, 255);
        canvas.drawPoints(PointMode.points, [Offset(x, y)], _p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
