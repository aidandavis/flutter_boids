import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'boids_engine.dart';

class BoidsPainter extends CustomPainter {
  BoidsPainter({required this.engine}) : super(repaint: engine);

  final BoidsEngine engine;

  // Cached typed buffers for Vertices.raw.
  Float32List _posNow = Float32List(0);
  Int32List _colNow = Int32List(0);
  Int32List _colGlow = Int32List(0);

  Float32List _posTrail = Float32List(0);
  Int32List _colTrail = Int32List(0);

  late final Paint _paint = Paint()..isAntiAlias = true;
  late final Paint _paintAdd = Paint()..isAntiAlias = true;

  late final Paint _debugRingPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.25;

  late final Paint _debugFillPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = engine.boidCount;
    if (n <= 0) return;

    final double w = size.width;
    final double h = size.height;
    final double s = math.min(w, h);

    // Sizing tuned for typical web canvas sizes.
    final double base = (s * 0.008).clamp(2.0, 7.4);
    final double tip = base * 1.85;
    final double back = base * 1.10;
    final double wing = base * 0.95;

    _ensureCapacity(n);

    // Build vertices.
    final Float32List x = engine.x;
    final Float32List y = engine.y;
    final Float32List hx = engine.hx;
    final Float32List hy = engine.hy;
    final Float32List heat = engine.heat;
    final Int32List colors = engine.colors;

    if (engine.trailsEnabled) {
      _writeTrails(
        count: n,
        outPos: _posTrail,
        outCol: _colTrail,
        x: x,
        y: y,
        hx: hx,
        hy: hy,
        heat: heat,
        colors: colors,
        w: w,
        h: h,
        s: s,
      );
      final Vertices vTrail = Vertices.raw(
        VertexMode.triangles,
        _posTrail,
        colors: _colTrail,
      );
      canvas.drawVertices(vTrail, BlendMode.srcOver, _paint);
    }

    _writeTriangles(
      count: n,
      outPos: _posNow,
      outCol: _colNow,
      x: x,
      y: y,
      hx: hx,
      hy: hy,
      heat: heat,
      colors: colors,
      w: w,
      h: h,
      tip: tip,
      back: back,
      wing: wing,
      alphaBase: 0xE8,
      lighten: 0.18,
    );

    if (engine.glowEnabled) {
      // A subtle "bloom" pass: additive, low alpha.
      for (int i = 0; i < n * 3; i++) {
        _colGlow[i] = (_colNow[i] & 0x00FFFFFF) | (0x26 << 24);
      }
      final Vertices vGlow = Vertices.raw(
        VertexMode.triangles,
        _posNow,
        colors: _colGlow,
      );
      canvas.drawVertices(vGlow, BlendMode.plus, _paintAdd);
    }

    final Vertices vNow = Vertices.raw(
      VertexMode.triangles,
      _posNow,
      colors: _colNow,
    );
    canvas.drawVertices(vNow, BlendMode.srcOver, _paint);

    _drawInteractionOverlay(canvas, size);
    _drawSelectedDebug(canvas, size);
  }

  void _ensureCapacity(int boids) {
    final int posLen = boids * 6; // 3 vertices * (x,y)
    final int colLen = boids * 3; // 3 vertices

    final int trailPosLen = boids * 12; // 6 vertices (2 triangles) * (x,y)
    final int trailColLen = boids * 6; // 6 vertices

    if (_posNow.length != posLen) _posNow = Float32List(posLen);
    if (_colNow.length != colLen) _colNow = Int32List(colLen);
    if (_colGlow.length != colLen) _colGlow = Int32List(colLen);

    if (_posTrail.length != trailPosLen) _posTrail = Float32List(trailPosLen);
    if (_colTrail.length != trailColLen) _colTrail = Int32List(trailColLen);
  }

  static void _writeTriangles({
    required int count,
    required Float32List outPos,
    required Int32List outCol,
    required Float32List x,
    required Float32List y,
    required Float32List hx,
    required Float32List hy,
    required Float32List heat,
    required Int32List colors,
    required double w,
    required double h,
    required double tip,
    required double back,
    required double wing,
    required int alphaBase,
    required double lighten,
  }) {
    int p = 0;
    int c = 0;

    for (int i = 0; i < count; i++) {
      final double px = x[i] * w;
      final double py = y[i] * h;

      final double dx = hx[i];
      final double dy = hy[i];
      // Perpendicular.
      final double nx = -dy;
      final double ny = dx;

      final double t = heat[i].clamp(0.0, 1.0);
      final double l = (lighten * t).clamp(0.0, 1.0);
      final int tipColor =
          _tint(colors[i], alphaBase, (l + 0.22).clamp(0.0, 1.0));
      final int sideColor = _tint(colors[i], alphaBase, l);

      // Tip
      outPos[p++] = (px + dx * tip).toDouble();
      outPos[p++] = (py + dy * tip).toDouble();
      // Left
      outPos[p++] = (px - dx * back + nx * wing).toDouble();
      outPos[p++] = (py - dy * back + ny * wing).toDouble();
      // Right
      outPos[p++] = (px - dx * back - nx * wing).toDouble();
      outPos[p++] = (py - dy * back - ny * wing).toDouble();

      outCol[c++] = tipColor;
      outCol[c++] = sideColor;
      outCol[c++] = sideColor;
    }
  }

  static void _writeTrails({
    required int count,
    required Float32List outPos,
    required Int32List outCol,
    required Float32List x,
    required Float32List y,
    required Float32List hx,
    required Float32List hy,
    required Float32List heat,
    required Int32List colors,
    required double w,
    required double h,
    required double s,
  }) {
    // A small, crisp streak along the heading direction.
    final double lenBase = (s * 0.020).clamp(8.0, 20.0);
    final double thickness = (s * 0.0014).clamp(0.6, 1.8);

    int p = 0;
    int c = 0;

    for (int i = 0; i < count; i++) {
      final double headX = x[i] * w;
      final double headY = y[i] * h;

      // Direction in screen space (account for aspect ratio).
      double dx = hx[i] * w;
      double dy = hy[i] * h;
      final double dl2 = dx * dx + dy * dy;
      if (dl2 > 1e-12) {
        final double inv = 1.0 / math.sqrt(dl2);
        dx *= inv;
        dy *= inv;
      } else {
        dx = 1.0;
        dy = 0.0;
      }

      final double t = heat[i].clamp(0.0, 1.0);
      final double len = lenBase * (0.55 + 0.55 * t);

      final double tailX = headX - dx * len;
      final double tailY = headY - dy * len;

      // Perpendicular.
      final double nx = -dy;
      final double ny = dx;
      final double wx = nx * thickness;
      final double wy = ny * thickness;

      // Alpha is intentionally low; it should read as a streak, not a blur.
      final int aHead = (0x14 + (t * 0x24)).round().clamp(0, 0x48);
      final int rgb = colors[i] & 0x00FFFFFF;
      final int headColor = (aHead << 24) | rgb;
      const int tailColor = 0x00000000;

      // Two triangles forming a quad:
      // tailL, headL, headR
      outPos[p++] = (tailX + wx).toDouble();
      outPos[p++] = (tailY + wy).toDouble();
      outPos[p++] = (headX + wx).toDouble();
      outPos[p++] = (headY + wy).toDouble();
      outPos[p++] = (headX - wx).toDouble();
      outPos[p++] = (headY - wy).toDouble();

      outCol[c++] = tailColor;
      outCol[c++] = headColor;
      outCol[c++] = headColor;

      // tailL, headR, tailR
      outPos[p++] = (tailX + wx).toDouble();
      outPos[p++] = (tailY + wy).toDouble();
      outPos[p++] = (headX - wx).toDouble();
      outPos[p++] = (headY - wy).toDouble();
      outPos[p++] = (tailX - wx).toDouble();
      outPos[p++] = (tailY - wy).toDouble();

      outCol[c++] = tailColor;
      outCol[c++] = headColor;
      outCol[c++] = tailColor;
    }
  }

  static int _tint(int argb, int alpha, double toWhite) {
    final int a = alpha.clamp(0, 255);
    int r = (argb >> 16) & 0xFF;
    int g = (argb >> 8) & 0xFF;
    int b = argb & 0xFF;
    if (toWhite > 0) {
      final double t = toWhite.clamp(0.0, 1.0);
      r = (r + ((255 - r) * t)).round().clamp(0, 255);
      g = (g + ((255 - g) * t)).round().clamp(0, 255);
      b = (b + ((255 - b) * t)).round().clamp(0, 255);
    }
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  void _drawInteractionOverlay(Canvas canvas, Size size) {
    final Offset? attractor = engine.attractor;
    if (attractor == null) return;

    final Offset p =
        Offset(attractor.dx * size.width, attractor.dy * size.height);
    final bool repel = engine.attractorSign < 0;

    final Color core =
        repel ? const Color(0xFFFF4D4D) : const Color(0xFF2EF2C7);
    final Color ring =
        repel ? const Color(0x55FF4D4D) : const Color(0x552EF2C7);

    _debugFillPaint.color = core.withAlpha(77);
    canvas.drawCircle(p, 10.0, _debugFillPaint);

    _debugRingPaint.color = ring;
    canvas.drawCircle(p, 34.0, _debugRingPaint);
    canvas.drawCircle(p, 56.0, _debugRingPaint..strokeWidth = 0.8);
    _debugRingPaint.strokeWidth = 1.25;
  }

  void _drawSelectedDebug(Canvas canvas, Size size) {
    if (!engine.visualizeSelected) return;
    final int i = engine.selectedIndex;
    if (i < 0 || i >= engine.boidCount) return;

    final double px = engine.x[i] * size.width;
    final double py = engine.y[i] * size.height;
    final Offset p = Offset(px, py);

    final double pr =
        engine.perceptionRadius * math.min(size.width, size.height);
    final double sr =
        engine.separationRadius * math.min(size.width, size.height);

    _debugRingPaint
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.25;
    canvas.drawCircle(p, pr, _debugRingPaint);

    _debugRingPaint
      ..color = const Color(0x44FFB020)
      ..strokeWidth = 1.0;
    canvas.drawCircle(p, sr, _debugRingPaint);
  }

  @override
  bool shouldRepaint(covariant BoidsPainter oldDelegate) =>
      oldDelegate.engine != engine;
}
