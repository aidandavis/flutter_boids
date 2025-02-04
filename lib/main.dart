import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boids',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late BoidSimulation simulation;
  double _boidCountSliderValue = 75;
  double _speedSliderValue = 0.15;

  @override
  void initState() {
    super.initState();
    simulation = BoidSimulation(this);
    _boidCountSliderValue = simulation.boids.length.toDouble();
    _speedSliderValue = simulation.speed;
  }

  @override
  void dispose() {
    simulation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to support mobile screen sizes.
    final screenSize = MediaQuery.of(context).size;
    // For a square canvas, we use the shortest side.
    final canvasSize = screenSize.shortestSide;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Stack(
          children: [
            // Background square for the simulation.
            Center(
              child: Container(
                height: canvasSize,
                width: canvasSize,
                color: Colors.grey[800],
              ),
            ),
            // Simulation canvas.
            Center(
              child: GestureDetector(
                onPanUpdate: (details) {
                  simulation.coherencePosition = Offset(
                    details.localPosition.dx / canvasSize,
                    details.localPosition.dy / canvasSize,
                  );
                },
                child: AnimatedBuilder(
                  animation: simulation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(canvasSize, canvasSize),
                      painter: BoidPainter(
                        boids: simulation.boids,
                        cohereToPoint: simulation.cohereToPoint,
                        coherencePosition: simulation.coherencePosition,
                        separationDistance: simulation.separationDistance,
                        awarenessDistance: simulation.awarenessDistance,
                        awarenessArc: simulation.awarenessArc,
                        drawAvoidance: simulation.drawAvoidance,
                        drawAwareness: simulation.drawAwareness,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Top-left FPS and boid count indicator.
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedBuilder(
                  animation: simulation,
                  builder: (context, child) {
                    final fps = simulation.fpsList.isNotEmpty
                        ? simulation.fpsList.reduce((a, b) => a + b) ~/
                            simulation.fpsList.length
                        : 60;
                    return Text(
                      'FPS: $fps   Boids: ${simulation.boids.length}',
                      style: const TextStyle(color: Colors.white70),
                    );
                  },
                ),
              ),
            ),
            // Bottom control panel.
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Boid count slider.
                    Row(
                      children: [
                        const Text(
                          "Boid Count",
                          style: TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: BoidSimulation.boidLimit.toDouble(),
                            value: _boidCountSliderValue,
                            divisions: BoidSimulation.boidLimit ~/ 10,
                            label: _boidCountSliderValue.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _boidCountSliderValue = value;
                              });
                              simulation.setBoidCount(value.round());
                            },
                          ),
                        ),
                      ],
                    ),
                    // Speed slider.
                    Row(
                      children: [
                        const Text(
                          "Speed",
                          style: TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0.05,
                            max: 0.5,
                            value: _speedSliderValue,
                            divisions: 9,
                            label: _speedSliderValue.toStringAsFixed(2),
                            onChanged: (value) {
                              setState(() {
                                _speedSliderValue = value;
                              });
                              simulation.speed = value;
                            },
                          ),
                        ),
                      ],
                    ),
                    // Toggle switches.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text("Separation",
                                style: TextStyle(color: Colors.white)),
                            Switch(
                              value: simulation.drawAvoidance,
                              onChanged: (value) {
                                setState(() {
                                  simulation.drawAvoidance = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text("Awareness",
                                style: TextStyle(color: Colors.white)),
                            Switch(
                              value: simulation.drawAwareness,
                              onChanged: (value) {
                                setState(() {
                                  simulation.drawAwareness = value;
                                });
                              },
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text("Cohere To Point",
                                style: TextStyle(color: Colors.white)),
                            Switch(
                              value: simulation.cohereToPoint,
                              onChanged: (value) {
                                setState(() {
                                  simulation.cohereToPoint = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BoidSimulation extends ChangeNotifier {
  static const int boidsPerOperation = 15;
  static const int boidLimit = 500;
  static const int fpsAverageCount = 20;

  final List<Boid> boids = [];
  int lastFrameTime = 0;
  int dt = 0;
  final List<int> fpsList = [];

  double speed = 0.15;
  double maxTurnSpeed = 0.05;
  double separationDistance = 0.02;
  double separationWeight = 0.375;
  double awarenessArc = pi;
  double awarenessDistance = 0.1;
  double coherenceWeight = 0.05;
  double alignmentWeight = 0.05;

  Offset coherencePosition = const Offset(0.5, 0.5);
  bool cohereToPoint = false;
  bool drawAvoidance = false;
  bool drawAwareness = false;

  final TickerProvider vsync;
  late final Ticker _ticker;

  BoidSimulation(this.vsync) {
    addBoids(75);
    _ticker = vsync.createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Spatial partitioning grid resolution.
  static const int gridResolution = 20;

  void _tick(Duration elapsed) {
    dt = elapsed.inMicroseconds - lastFrameTime;
    lastFrameTime = elapsed.inMicroseconds;
    final ds = dt / 1000000;

    calculateFps();

    // Ensure boid count does not exceed limit.
    while (boids.length > boidLimit) {
      removeBoids();
    }

    // Build spatial grid to reduce neighbor comparisons.
    final grid = List.generate(gridResolution,
        (_) => List.generate(gridResolution, (_) => <Boid>[], growable: false),
        growable: false);

    // Assign each boid to a cell. The simulation area is [0,1] in both axes.
    for (var boid in boids) {
      int cellX = (boid.position.x * gridResolution).floor() % gridResolution;
      int cellY = (boid.position.y * gridResolution).floor() % gridResolution;
      grid[cellX][cellY].add(boid);
    }

    // For each boid, gather neighbors from its own and adjacent cells (with wrap-around).
    for (var boid in boids) {
      int cellX = (boid.position.x * gridResolution).floor() % gridResolution;
      int cellY = (boid.position.y * gridResolution).floor() % gridResolution;
      final neighbors = <Boid>[];

      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          int neighborX = (cellX + dx + gridResolution) % gridResolution;
          int neighborY = (cellY + dy + gridResolution) % gridResolution;
          neighbors.addAll(grid[neighborX][neighborY]);
        }
      }

      boid.iterate(
        neighbors,
        ds,
        speed: speed,
        maxTurnSpeed: maxTurnSpeed,
        separationDistance: separationDistance,
        separationWeight: separationWeight,
        awarenessDistance: awarenessDistance,
        awarenessArc: awarenessArc,
        coherenceWeight: coherenceWeight,
        alignmentWeight: alignmentWeight,
        cohereToPoint: cohereToPoint,
        coherencePoint: Point(coherencePosition.dx, coherencePosition.dy),
      );
    }

    notifyListeners();
  }

  void calculateFps() {
    final safeDt = dt == 0 ? 1 : dt;
    fpsList.add(1000000 ~/ safeDt);
    if (fpsList.length > fpsAverageCount) {
      fpsList.removeAt(0);
    }
  }

  void addBoids([int numToAdd = boidsPerOperation]) {
    for (var i = 0; i < numToAdd; i++) {
      boids.add(Boid.createRandom());
    }
  }

  void removeBoids([int numToRemove = boidsPerOperation]) {
    numToRemove = numToRemove > boids.length ? boids.length : numToRemove;
    for (var i = 0; i < numToRemove; i++) {
      boids.removeAt(Boid.random.nextInt(boids.length));
    }
  }

  void setBoidCount(int targetCount) {
    final currentCount = boids.length;
    if (targetCount > currentCount) {
      addBoids(targetCount - currentCount);
    } else if (targetCount < currentCount) {
      removeBoids(currentCount - targetCount);
    }
    notifyListeners();
  }

  void resetSettings() {
    separationDistance = 0.02;
    separationWeight = 0.375;
    awarenessArc = pi;
    awarenessDistance = 0.1;
    coherenceWeight = 0.05;
    alignmentWeight = 0.05;
  }
}

class Boid {
  double _x;
  double _y;
  double _direction; // in radians
  double newDirection = 0.0;
  final List<Point<double>> boidsToAvoid = [];
  final List<Point<double>> boidsAwareOf = [];

  // Each boid has its own random vivid colour.
  final Color color;

  static final Random random = Random();

  Boid.createRandom()
      : _x = random.nextDouble(),
        _y = random.nextDouble(),
        _direction = random.nextDouble() * 2 * pi - pi,
        color = HSLColor.fromAHSL(
          1.0,
          random.nextDouble() * 360,
          0.7,
          0.5,
        ).toColor();

  Point<double> get position => Point(_x, _y);
  double get direction => _direction;

  // Note: The first parameter now is the list of neighbor boids determined via spatial grid.
  void iterate(
    List<Boid> neighbors,
    double ds, {
    required double speed,
    required double maxTurnSpeed,
    required double separationDistance,
    required double separationWeight,
    required double awarenessDistance,
    required double awarenessArc,
    required double coherenceWeight,
    required double alignmentWeight,
    required bool cohereToPoint,
    required Point<double> coherencePoint,
  }) {
    readyForNextTick();

    if (cohereToPoint) {
      newDirection +=
          _relativeDirectionToOtherPoint(coherencePoint) * coherenceWeight * 2;
    }

    double separationTurnAmount = 0.0;
    double cumulativeX = 0.0;
    double cumulativeY = 0.0;
    double alignmentCumulativeDirection = 0.0;
    int numBoidsAwareOf = 0;

    // Iterate over the nearby boids only.
    for (var boid in neighbors) {
      if (boid == this) continue;

      final distanceToOther = _distanceToOtherPoint(boid.position);
      if (distanceToOther <= separationDistance) {
        boidsToAvoid.add(boid.position);
        separationTurnAmount += _getTurnAmountToAvoidPoint(boid.position);
      }

      if (_isAwareOfThisPoint(boid.position, awarenessDistance, awarenessArc)) {
        boidsAwareOf.add(boid.position);
        cumulativeX += boid.position.x;
        cumulativeY += boid.position.y;
        alignmentCumulativeDirection += boid.direction;
        numBoidsAwareOf++;
      }
    }

    newDirection += separationTurnAmount * separationWeight;

    if (numBoidsAwareOf > 0) {
      final com =
          Point(cumulativeX / numBoidsAwareOf, cumulativeY / numBoidsAwareOf);
      newDirection += _relativeDirectionToOtherPoint(com) * coherenceWeight;
      final averageDirection = alignmentCumulativeDirection / numBoidsAwareOf;
      final relativeDirection =
          _normaliseDirection(averageDirection - _direction);
      newDirection += relativeDirection * alignmentWeight;
    }

    applyNextPosition(speed, maxTurnSpeed, ds);
  }

  void readyForNextTick() {
    newDirection = 0.0;
    boidsToAvoid.clear();
    boidsAwareOf.clear();
  }

  Point<double> nextPosition(double speed, double ds) {
    var nextX = _x + cos(_direction) * speed * ds;
    var nextY = _y + sin(_direction) * speed * ds;

    if (nextX > 1) nextX -= 1;
    if (nextX < 0) nextX += 1;
    if (nextY > 1) nextY -= 1;
    if (nextY < 0) nextY += 1;

    return Point(nextX, nextY);
  }

  void applyNextPosition(double speed, double maxTurnSpeed, double ds) {
    if (newDirection.abs() / ds > maxTurnSpeed) {
      newDirection = newDirection.sign * maxTurnSpeed;
    }
    _direction += newDirection;
    _direction = _normaliseDirection(_direction);
    final nextPos = nextPosition(speed, ds);
    _x = nextPos.x;
    _y = nextPos.y;
  }

  double _normaliseDirection(double angle) {
    angle = angle % (2 * pi);
    if (angle > pi) angle -= 2 * pi;
    return angle;
  }

  double _getTurnAmountToAvoidPoint(Point<double> pointToAvoid) {
    final turn = _relativeDirectionToOtherPoint(pointToAvoid);
    return (pi - turn.abs()) * -turn.sign;
  }

  bool _isAwareOfThisPoint(
      Point<double> point, double awarenessDistance, double awarenessArc) {
    if (_distanceToOtherPoint(point) <= awarenessDistance) {
      final angleToOther = _directionToOtherPoint(point);
      final minAngle = _direction - (awarenessArc / 2);
      final maxAngle = _direction + (awarenessArc / 2);
      return angleToOther >= minAngle && angleToOther <= maxAngle;
    }
    return false;
  }

  double _distanceToOtherPoint(Point<double> point) =>
      position.distanceTo(point);

  double _directionToOtherPoint(Point<double> point) =>
      atan2(point.y - _y, point.x - _x);

  double _relativeDirectionToOtherPoint(Point<double> point) {
    return _normaliseDirection(_directionToOtherPoint(point) - _direction);
  }

  @override
  bool operator ==(Object other) {
    if (other is Boid) {
      return _x == other._x && _y == other._y && _direction == other._direction;
    }
    return false;
  }

  @override
  int get hashCode => _x.hashCode ^ _y.hashCode ^ _direction.hashCode;
}

class BoidPainter extends CustomPainter {
  final List<Boid> boids;
  final bool cohereToPoint;
  final Offset coherencePosition;
  final double separationDistance;
  final double awarenessDistance;
  final double awarenessArc;
  final bool drawAvoidance;
  final bool drawAwareness;

  BoidPainter({
    required this.boids,
    required this.cohereToPoint,
    required this.coherencePosition,
    required this.separationDistance,
    required this.awarenessDistance,
    required this.awarenessArc,
    this.drawAvoidance = true,
    this.drawAwareness = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cohereToPoint) {
      canvas.drawCircle(
        coherencePosition.scale(size.width, size.height),
        8,
        Paint()..color = Colors.orange,
      );
    }

    for (var boid in boids) {
      final boidOffset = Offset(
        boid.position.x * size.width,
        boid.position.y * size.height,
      );
      _drawBoid(canvas, boid, boidOffset);
      if (drawAvoidance) {
        _drawAvoidance(canvas, size, boid, boidOffset);
      }
      if (drawAwareness) {
        _drawAwareness(canvas, size, boid, boidOffset);
      }
    }
  }

  void _drawBoid(Canvas canvas, Boid boid, Offset boidOffset) {
    final boidPath = Path()
      ..moveTo(-4, 4)
      ..lineTo(8, 0)
      ..lineTo(-4, -4)
      ..close();

    canvas.save();
    canvas.translate(boidOffset.dx, boidOffset.dy);
    canvas.rotate(boid.direction);
    // Draw drop shadow (if performance becomes an issue, consider toggling this off).
    canvas.drawShadow(boidPath, Colors.black, 4.0, true);
    canvas.drawPath(
      boidPath,
      Paint()..color = boid.color,
    );
    canvas.restore();
  }

  void _drawAvoidance(Canvas canvas, Size size, Boid boid, Offset boidOffset) {
    final avoidanceRect = Rect.fromCenter(
      center: boidOffset,
      width: separationDistance * size.width,
      height: separationDistance * size.height,
    );
    canvas.drawOval(
      avoidanceRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke,
    );

    for (final other in boid.boidsToAvoid) {
      final otherOffset = Offset(
        other.x * size.width,
        other.y * size.height,
      );
      canvas.drawLine(
        boidOffset,
        otherOffset,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1,
      );
    }
  }

  void _drawAwareness(Canvas canvas, Size size, Boid boid, Offset boidOffset) {
    final awarenessRect = Rect.fromCenter(
      center: boidOffset,
      width: awarenessDistance * size.width * 2,
      height: awarenessDistance * size.height * 2,
    );

    // Use a gradient for the awareness arc:
    // If the boid is "aware" of neighbours, use a warm gradient;
    // otherwise use a cooler gradient.
    final bool isActive = boid.boidsAwareOf.isNotEmpty;
    final Paint awarenessPaint = Paint()
      ..shader = SweepGradient(
        startAngle: boid.direction - awarenessArc / 2,
        endAngle: boid.direction + awarenessArc / 2,
        colors: isActive
            ? [Colors.yellow, Colors.orange]
            : [Colors.blue, Colors.blueAccent],
        stops: const [0.0, 1.0],
      ).createShader(awarenessRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawArc(
      awarenessRect,
      boid.direction - awarenessArc / 2,
      awarenessArc,
      true,
      awarenessPaint,
    );

    for (final other in boid.boidsAwareOf) {
      final otherOffset = Offset(
        other.x * size.width,
        other.y * size.height,
      );
      canvas.drawLine(
        boidOffset,
        otherOffset,
        Paint()..color = Colors.green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
