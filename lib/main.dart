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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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

  @override
  void initState() {
    super.initState();
    simulation = BoidSimulation(this);
  }

  @override
  void dispose() {
    simulation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final canvasSize = screenSize.shortestSide;

    return Scaffold(
      body: Container(
        color: Colors.grey[900],
        child: Stack(
          children: [
            Center(
              child: Container(
                height: canvasSize,
                width: canvasSize,
                color: Colors.grey[800],
              ),
            ),
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
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    AnimatedBuilder(
                      animation: simulation,
                      builder: (context, child) {
                        final fps = simulation.fpsList.isNotEmpty
                            ? simulation.fpsList.reduce((a, b) => a + b) ~/
                                simulation.fpsList.length
                            : 60;
                        return Text(
                          'fps: $fps (${simulation.boids.length}) boids',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: simulation.addBoids,
                    child: const Text('Add boids'),
                  ),
                  ElevatedButton(
                    onPressed: simulation.removeBoids,
                    child: const Text('Remove boids'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      simulation.drawAvoidance = !simulation.drawAvoidance;
                    },
                    child: const Text('Toggle Separation'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      simulation.drawAwareness = !simulation.drawAwareness;
                    },
                    child: const Text('Toggle Awareness'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      simulation.cohereToPoint = !simulation.cohereToPoint;
                    },
                    child: const Text('Toggle to Point'),
                  ),
                ]
                    .map((widget) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: widget,
                        ))
                    .toList(),
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

  void _tick(Duration elapsed) {
    dt = elapsed.inMicroseconds - lastFrameTime;
    lastFrameTime = elapsed.inMicroseconds;
    final ds = dt / 1000000;

    calculateFps();

    while (boids.length > boidLimit) {
      removeBoids();
    }

    for (var boid in boids) {
      boid.iterate(
        boids,
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

  static final Random random = Random();

  Boid.createRandom()
      : _x = random.nextDouble(),
        _y = random.nextDouble(),
        _direction = random.nextDouble() * 2 * pi - pi;

  Point<double> get position => Point(_x, _y);
  double get direction => _direction;

  void iterate(
    List<Boid> boids,
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

    // Cohere to a fixed point if toggled.
    if (cohereToPoint) {
      newDirection +=
          _relativeDirectionToOtherPoint(coherencePoint) * coherenceWeight * 2;
    }

    double separationTurnAmount = 0.0;
    double cumulativeX = 0.0;
    double cumulativeY = 0.0;
    double alignmentCumulativeDirection = 0.0;
    int numBoidsAwareOf = 0;

    for (var boid in boids) {
      if (boid == this) continue;

      final distanceToOtherBoid = _distanceToOtherPoint(boid.position);

      // Separation: steer away from nearby boids.
      if (distanceToOtherBoid <= separationDistance) {
        boidsToAvoid.add(boid.position);
        separationTurnAmount += _getTurnAmountToAvoidPoint(boid.position);
      }

      // Awareness: consider boids within a certain distance and within a field of view.
      if (_isAwareOfThisPoint(boid.position, awarenessDistance, awarenessArc)) {
        boidsAwareOf.add(boid.position);
        cumulativeX += boid.position.x;
        cumulativeY += boid.position.y;
        alignmentCumulativeDirection += boid.direction;
        numBoidsAwareOf++;
      }
    }

    // Apply separation influence.
    newDirection += separationTurnAmount * separationWeight;

    if (numBoidsAwareOf > 0) {
      // Cohesion: steer towards the centre of mass.
      final com =
          Point(cumulativeX / numBoidsAwareOf, cumulativeY / numBoidsAwareOf);
      newDirection += _relativeDirectionToOtherPoint(com) * coherenceWeight;

      // Alignment: adjust direction to match neighbours.
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

    // Wrap around if going off the boundaries.
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
      final angleToOtherBoid = _directionToOtherPoint(point);
      final minAngle = _direction - (awarenessArc / 2);
      final maxAngle = _direction + (awarenessArc / 2);
      return angleToOtherBoid >= minAngle && angleToOtherBoid <= maxAngle;
    } else {
      return false;
    }
  }

  double avoidWalls(double separationDistance) {
    var turnAmount = 0.0;
    if (_x < separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(0, _y));
    }
    if (_x > 1 - separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(1, _y));
    }
    if (_y < separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 0));
    }
    if (_y > 1 - separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 1));
    }
    return _normaliseDirection(turnAmount);
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

    // Use canvas transforms rather than building a transformation matrix.
    canvas.save();
    canvas.translate(boidOffset.dx, boidOffset.dy);
    canvas.rotate(boid.direction);
    canvas.drawPath(
      boidPath,
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.fill,
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

    for (final otherBoid in boid.boidsToAvoid) {
      final otherBoidOffset = Offset(
        otherBoid.x * size.width,
        otherBoid.y * size.height,
      );
      canvas.drawLine(
        boidOffset,
        otherBoidOffset,
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

    canvas.drawArc(
      awarenessRect,
      boid.direction - awarenessArc / 2,
      awarenessArc,
      true,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke,
    );

    for (final otherBoid in boid.boidsAwareOf) {
      final otherBoidOffset = Offset(
        otherBoid.x * size.width,
        otherBoid.y * size.height,
      );
      canvas.drawLine(
        boidOffset,
        otherBoidOffset,
        Paint()..color = Colors.green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
