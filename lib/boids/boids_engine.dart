import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset;

import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier;
import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter/scheduler.dart';

class BoidsStats {
  const BoidsStats({
    required this.boids,
    required this.fps,
    required this.frameMs,
  });

  final int boids;
  final int fps;
  final double frameMs;
}

/// A lightweight boids engine optimized for Flutter Web:
/// - avoids per-frame allocations (typed arrays + reusable spatial grid)
/// - toroidal ("wrap") world for nicer edge behavior
class BoidsEngine extends ChangeNotifier {
  BoidsEngine({
    required TickerProvider vsync,
    this.capacity = 2000,
    int initialBoids = 650,
    int gridResolution = 20,
    int statsHz = 4,
  })  : assert(capacity > 0),
        assert(initialBoids >= 0),
        assert(gridResolution >= 8),
        assert(statsHz >= 1),
        _gridResolution = gridResolution,
        _statsIntervalUs = (1000000 / statsHz).round() {
    _x = Float32List(capacity);
    _y = Float32List(capacity);
    _hx = Float32List(capacity);
    _hy = Float32List(capacity);
    _prevX = Float32List(capacity);
    _prevY = Float32List(capacity);
    _heat = Float32List(capacity);
    _colors = Int32List(capacity);

    _cells = List.generate(
      _gridResolution * _gridResolution,
      (_) => <int>[],
      growable: false,
    );

    setBoidCount(initialBoids.clamp(0, capacity));

    _ticker = vsync.createTicker(_tick)..start();
  }

  final int capacity;

  // Tunables (world units are [0,1]).
  double speed = 0.22; // units / second
  double perceptionRadius = 0.115;
  double separationRadius = 0.032;
  double maxTurnRate = 4.6; // rad / second

  double separationWeight = 1.55;
  double alignmentWeight = 1.05;
  double cohesionWeight = 0.85;
  double attractorWeight = 1.15;

  bool separationEnabled = true;
  bool alignmentEnabled = true;
  bool cohesionEnabled = true;

  bool trailsEnabled = true;
  bool glowEnabled = true;

  bool paused = false;

  // UI/debug state.
  int selectedIndex = -1;
  bool visualizeSelected = false;

  // Pointer interaction (normalized [0,1] coords).
  Offset? _attractor;
  int _attractorSign = 1; // +1 attract, -1 repel
  bool dragRepels = false;

  late final Ticker _ticker;

  // Exposed for painting (read-only by convention).
  late final Float32List _x;
  late final Float32List _y;
  late final Float32List _hx;
  late final Float32List _hy;
  late final Float32List _prevX;
  late final Float32List _prevY;
  late final Float32List _heat;
  late final Int32List _colors;

  int boidCount = 0;

  // Spatial grid.
  final int _gridResolution;
  late final List<List<int>> _cells;

  // Stats (decoupled from repaint rate).
  final int _statsIntervalUs;
  final ValueNotifier<BoidsStats> stats =
      ValueNotifier(const BoidsStats(boids: 0, fps: 60, frameMs: 16.0));
  int _lastStatsUs = 0;
  double _fpsEma = 60.0;
  double _msEma = 16.0;

  // Timekeeping.
  Duration _lastElapsed = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    stats.dispose();
    super.dispose();
  }

  Float32List get x => _x;
  Float32List get y => _y;
  Float32List get hx => _hx;
  Float32List get hy => _hy;
  Float32List get prevX => _prevX;
  Float32List get prevY => _prevY;
  Float32List get heat => _heat;
  Int32List get colors => _colors;

  Offset? get attractor => _attractor;
  int get attractorSign => _attractorSign;

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }

  void setBoidCount(int target) {
    target = target.clamp(0, capacity);
    if (target == boidCount) return;

    if (target > boidCount) {
      for (int i = boidCount; i < target; i++) {
        _initBoid(i);
        _prevX[i] = _x[i];
        _prevY[i] = _y[i];
      }
    }

    boidCount = target;
    if (selectedIndex >= boidCount) {
      selectedIndex = boidCount - 1;
    }

    stats.value = BoidsStats(
      boids: boidCount,
      fps: stats.value.fps,
      frameMs: stats.value.frameMs,
    );
    notifyListeners();
  }

  void randomize({bool keepColors = true}) {
    for (int i = 0; i < boidCount; i++) {
      _x[i] = _rng.nextDouble().toDouble();
      _y[i] = _rng.nextDouble().toDouble();
      final double a = _rng.nextDouble() * math.pi * 2.0;
      _hx[i] = math.cos(a);
      _hy[i] = math.sin(a);
      _prevX[i] = _x[i];
      _prevY[i] = _y[i];
      _heat[i] = 0.0;
      if (!keepColors) {
        _colors[i] = _randomVividColor().toARGB32();
      }
    }
    notifyListeners();
  }

  void setAttractor(Offset? normalizedPosition, {required bool repel}) {
    _attractor = normalizedPosition;
    _attractorSign = repel ? -1 : 1;
    if (paused) {
      // When paused we don't repaint every frame, so force a redraw so the
      // interaction marker still updates.
      notifyListeners();
    }
  }

  void setDragRepels(bool value) {
    if (dragRepels == value) return;
    dragRepels = value;
  }

  void markNeedsPaint() => notifyListeners();

  void setVisualizeSelected(bool value) {
    if (visualizeSelected == value) return;
    visualizeSelected = value;
    notifyListeners();
  }

  void setSelectedIndex(int value) {
    if (selectedIndex == value) return;
    selectedIndex = value;
    notifyListeners();
  }

  void selectNearestBoid(Offset normalizedPosition) {
    setSelectedIndex(findNearestBoid(normalizedPosition));
  }

  int findNearestBoid(Offset normalizedPosition) {
    if (boidCount == 0) return -1;
    final double tx = normalizedPosition.dx;
    final double ty = normalizedPosition.dy;
    double bestD2 = double.infinity;
    int best = -1;
    for (int i = 0; i < boidCount; i++) {
      double dx = _wrapDiff(_x[i] - tx);
      double dy = _wrapDiff(_y[i] - ty);
      final double d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = i;
      }
    }
    return best;
  }

  void _tick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final int dtUs = (elapsed - _lastElapsed).inMicroseconds;
    _lastElapsed = elapsed;
    if (dtUs <= 0) return;

    final double dt = (dtUs / 1000000.0).clamp(0.0, 0.05);

    _updateStats(dtUs);
    if (paused) return;

    _step(dt);
    notifyListeners();
  }

  void _updateStats(int dtUs) {
    final double fpsNow = 1000000.0 / dtUs;
    _fpsEma += (fpsNow - _fpsEma) * 0.06;
    _msEma += ((dtUs / 1000.0) - _msEma) * 0.06;

    final int nowUs = _lastElapsed.inMicroseconds;
    if (nowUs - _lastStatsUs < _statsIntervalUs) return;
    _lastStatsUs = nowUs;

    stats.value = BoidsStats(
      boids: boidCount,
      fps: _fpsEma.round().clamp(1, 999),
      frameMs: _msEma,
    );
  }

  void _step(double dt) {
    if (boidCount == 0) return;

    // Clear cells (reused, no per-frame allocations).
    for (final cell in _cells) {
      cell.clear();
    }

    // Rebuild spatial grid.
    final int res = _gridResolution;
    for (int i = 0; i < boidCount; i++) {
      final int cx = _cellOf(_x[i]);
      final int cy = _cellOf(_y[i]);
      _cells[cx + cy * res].add(i);
    }

    final double perception = perceptionRadius.clamp(0.001, 0.5);
    final double separation = separationRadius.clamp(0.001, perception);
    final double perception2 = perception * perception;
    final double separation2 = separation * separation;

    // Cell radius for neighborhood search. Must be >= 1 to avoid edge misses.
    final int cellRadius = math.max(1, (perception * _gridResolution).ceil());

    final Offset? target = _attractor;
    final int targetSign = _attractorSign;
    final bool hasTarget = target != null;

    final double maxTurn = maxTurnRate.clamp(0.1, 50.0) * dt;
    final double v = speed.clamp(0.01, 1.0);

    for (int i = 0; i < boidCount; i++) {
      // Store previous pos for trails/glow.
      _prevX[i] = _x[i];
      _prevY[i] = _y[i];

      final double xi = _x[i];
      final double yi = _y[i];
      final double hxi = _hx[i];
      final double hyi = _hy[i];

      final int cx = _cellOf(xi);
      final int cy = _cellOf(yi);

      double sepX = 0.0;
      double sepY = 0.0;
      double cohX = 0.0;
      double cohY = 0.0;
      double aliX = 0.0;
      double aliY = 0.0;
      int neighbors = 0;

      // Neighborhood scan.
      for (int oy = -cellRadius; oy <= cellRadius; oy++) {
        final int ny = _wrapCell(cy + oy);
        for (int ox = -cellRadius; ox <= cellRadius; ox++) {
          final int nx = _wrapCell(cx + ox);
          final List<int> cell = _cells[nx + ny * res];
          for (int k = 0; k < cell.length; k++) {
            final int j = cell[k];
            if (j == i) continue;

            double dx = _wrapDiff(_x[j] - xi);
            double dy = _wrapDiff(_y[j] - yi);
            final double d2 = dx * dx + dy * dy;
            if (d2 >= perception2 || d2 <= 1e-12) continue;

            neighbors++;

            if (cohesionEnabled) {
              cohX += dx;
              cohY += dy;
            }
            if (alignmentEnabled) {
              aliX += _hx[j];
              aliY += _hy[j];
            }
            if (separationEnabled && d2 < separation2) {
              // Weighted push away: stronger when closer.
              final double inv = 1.0 / (d2 + 1e-6);
              sepX -= dx * inv;
              sepY -= dy * inv;
            }
          }
        }
      }

      // A cheap "activity" metric for visuals.
      _heat[i] += ((neighbors / 18.0).clamp(0.0, 1.0) - _heat[i]) * 0.08;

      double steerX = 0.0;
      double steerY = 0.0;

      if (neighbors > 0) {
        final double inv = 1.0 / neighbors;

        if (cohesionEnabled) {
          steerX += (cohX * inv) * cohesionWeight;
          steerY += (cohY * inv) * cohesionWeight;
        }

        if (alignmentEnabled) {
          final double ax = (aliX * inv) - hxi;
          final double ay = (aliY * inv) - hyi;
          steerX += ax * alignmentWeight;
          steerY += ay * alignmentWeight;
        }
      }

      if (separationEnabled) {
        steerX += sepX * separationWeight;
        steerY += sepY * separationWeight;
      }

      if (hasTarget) {
        final double dx = _wrapDiff(target.dx - xi);
        final double dy = _wrapDiff(target.dy - yi);
        steerX += dx * attractorWeight * targetSign;
        steerY += dy * attractorWeight * targetSign;
      }

      // Desired heading from steering.
      double desiredX = hxi + steerX;
      double desiredY = hyi + steerY;
      final double dl2 = desiredX * desiredX + desiredY * desiredY;
      if (dl2 > 1e-12) {
        final double inv = 1.0 / math.sqrt(dl2);
        desiredX *= inv;
        desiredY *= inv;
      } else {
        desiredX = hxi;
        desiredY = hyi;
      }

      // Turn toward desired heading, capped by maxTurnRate.
      final double cross = hxi * desiredY - hyi * desiredX;
      final double dot = (hxi * desiredX + hyi * desiredY).clamp(-1.0, 1.0);
      double angle = math.atan2(cross, dot);
      if (angle > maxTurn) angle = maxTurn;
      if (angle < -maxTurn) angle = -maxTurn;

      final double sa = math.sin(angle);
      final double ca = math.cos(angle);
      final double nhx = (hxi * ca) - (hyi * sa);
      final double nhy = (hxi * sa) + (hyi * ca);

      _hx[i] = nhx;
      _hy[i] = nhy;

      _x[i] = _wrap01(xi + nhx * v * dt);
      _y[i] = _wrap01(yi + nhy * v * dt);
    }
  }

  int _wrapCell(int c) {
    final int res = _gridResolution;
    int v = c % res;
    if (v < 0) v += res;
    return v;
  }

  int _cellOf(double pos01) {
    final int res = _gridResolution;
    int c = (pos01 * res).floor();
    if (c < 0) c = 0;
    if (c >= res) c = res - 1;
    return c;
  }

  static double _wrap01(double v) {
    if (v >= 1.0) return v - 1.0;
    if (v < 0.0) return v + 1.0;
    return v;
  }

  static double _wrapDiff(double d) {
    if (d > 0.5) return d - 1.0;
    if (d < -0.5) return d + 1.0;
    return d;
  }

  void _initBoid(int i) {
    _x[i] = _rng.nextDouble().toDouble();
    _y[i] = _rng.nextDouble().toDouble();
    final double a = _rng.nextDouble() * math.pi * 2.0;
    _hx[i] = math.cos(a);
    _hy[i] = math.sin(a);
    _heat[i] = 0.0;

    // Vivid but not neon: better readability against dark backgrounds.
    _colors[i] = _randomVividColor().toARGB32();
  }

  static final math.Random _rng = math.Random();

  static Color _randomVividColor() {
    final double hue = _rng.nextDouble() * 360.0;
    final double sat = 0.68 + _rng.nextDouble() * 0.22;
    final double light = 0.52 + _rng.nextDouble() * 0.12;
    return HSLColor.fromAHSL(
            1.0, hue, sat.clamp(0.0, 1.0), light.clamp(0.0, 1.0))
        .toColor();
  }
}
