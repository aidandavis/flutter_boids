import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter_boids/clock.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boids',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  BoidSimulation simulation;

  @override
  void initState() {
    super.initState();

    simulation = BoidSimulation(this);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        color: Colors.grey[900],
        child: Stack(
          children: [
            Center(
              child: Container(
                height: screenSize.shortestSide,
                width: screenSize.shortestSide,
                color: Colors.grey[800],
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: simulation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(
                      screenSize.shortestSide,
                      screenSize.shortestSide,
                    ),
                    painter: BoidPainter(
                      simulation,
                      drawAvoidance: simulation.drawAvoidance,
                      drawAwareness: simulation.drawAwareness,
                    ),
                  );
                },
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
                              ? simulation.fpsList.reduce(
                                      (value, element) => value + element) ~/
                                  simulation.fpsList.length
                              : 60;
                          return Text(
                            'fps: $fps (${simulation.boids.length}) boids',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          );
                        }),
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
                  // ElevatedButton(
                  //   child: Text('Add boids'),
                  //   onPressed: () => simulation.addBoids(),
                  // ),
                  // ElevatedButton(
                  //   child: Text('Remove boids'),
                  //   onPressed: () => simulation.removeBoids(),
                  // ),
                  ElevatedButton(
                    child: Text('Toggle Clock'),
                    onPressed: () {
                      simulation.drawClock = !simulation.drawClock;
                    },
                  ),
                  ElevatedButton(
                    child: Text('Toggle Separation'),
                    onPressed: () {
                      simulation.drawAvoidance = !simulation.drawAvoidance;
                    },
                  ),
                  ElevatedButton(
                    child: Text('Toggle Awareness'),
                    onPressed: () {
                      simulation.drawAwareness = !simulation.drawAwareness;
                    },
                  ),
                ]
                    .map((Widget widget) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
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
  static const boidsPerAddOrRemove = 15;
  static const boidLimit = 500;
  static const fpsAverageCount = 20;

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int dt = 0;

  List<int> fpsList = [];

  double speed = 0.125;
  double maxTurnSpeed = 0.2;

  double separationDistance = 0.015;
  double separationWeight = 0.1;

  double awarenessArc = pi;
  double awarenessDistance = 0.075;

  double coherenceWeight = 0.02;
  double alignmentWeight = 0.02;

  double cohereToSegmentWeight = 0.2;

  bool drawAvoidance = false;
  bool drawAwareness = false;
  bool drawClock = false;

  List<Line> clockSegments = [];

  final TickerProvider vsync;
  Ticker _ticker;

  BoidSimulation(this.vsync) {
    addBoids(180);
    _ticker = vsync.createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  _tick(Duration totalElapsedDuration) {
    // microseconds are smoother
    dt = totalElapsedDuration.inMicroseconds - lastFrameTime;
    lastFrameTime = totalElapsedDuration.inMicroseconds;

    var ds = dt / 1000000;

    calculateFps();

    while (boids.length > boidLimit) {
      removeBoids();
    }

    final time = DateTime.now();
    clockSegments = getClockSegments(time);

    // first 30 seconds, stay on clock,
    // then gradually drift off,
    // final 15 seconds, no coherence to clock
    var amountToCohereToClock = cohereToSegmentWeight;
    if (time.second > 30 && time.second <= 45) {
      amountToCohereToClock =
          cohereToSegmentWeight * (15 - (time.second - 30)) / 15;
    }
    if (time.second > 45) {
      amountToCohereToClock = 0;
    }

    // need to divide boids evenly amoung segments
    final boidsPerSegment = boids.length / clockSegments.length;

    for (var i = 0; i < boids.length; i++) {
      final indexOfSegment = i ~/ boidsPerSegment;

      boids[i].iterate(
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
        amountToCohereToLine: amountToCohereToClock,
        lineToCohereTo: clockSegments[indexOfSegment],
        turnAroundDistance: 0.0125,
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

  void addBoids([int numToAdd = boidsPerAddOrRemove]) {
    for (var i = 0; i < numToAdd; i++) {
      boids.add(Boid.createRandom());
    }
  }

  void removeBoids([int numToRemove = boidsPerAddOrRemove]) {
    if (numToRemove > boids.length) {
      numToRemove = boids.length;
    }

    for (var i = 0; i < numToRemove; i++) {
      boids.removeAt(Random().nextInt(boids.length));
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

/// the boid
/// position (x, y) will be 0 to 1, so will scale to viewport
class Boid {
  //posistion
  double _x;
  double _y;
  double _direction; // radians

  double newDirection = 0.0; // for the next tick

  List<Point> boidsToAvoid = [];

  List<Point> boidsAwareOf = [];

  bool _headingToP1 = true;

  /// create a boid with random velocity starting in the center
  Boid.createRandom() {
    _x = Random().nextDouble();
    _y = Random().nextDouble();

    _direction = -2 * pi * (Random().nextDouble() * 2 * pi);
  }

  Point<double> get position => Point<double>(_x, _y);

  /// process the next step
  void iterate(
    List boids,
    double ds, {
    @required double speed,
    @required double maxTurnSpeed,
    @required double separationDistance,
    @required double separationWeight,
    @required double awarenessDistance,
    @required double awarenessArc,
    @required double coherenceWeight,
    @required double alignmentWeight,
    @required Line lineToCohereTo,
    @required double amountToCohereToLine,
    @required double turnAroundDistance,
  }) {
    readyForNextTick();

    // cohere to given line
    if (lineToCohereTo != null) {
      // want them to go along the line back and forward
      if (_headingToP1) {
        newDirection += _relativeDirectionToOtherPoint(lineToCohereTo.p1) *
            amountToCohereToLine;
      } else {
        newDirection += _relativeDirectionToOtherPoint(lineToCohereTo.p2) *
            amountToCohereToLine;
      }

// close to point, swap to other point
      if ((_headingToP1 &&
              _distanceToOtherPoint(lineToCohereTo.p1) < turnAroundDistance) ||
          (!_headingToP1 &&
              _distanceToOtherPoint(lineToCohereTo.p2) < turnAroundDistance)) {
        _headingToP1 = !_headingToP1;
      }
    }

    var separationTurnAmount = 0.0;
    var coherenceCumulativePoint;
    var alignmentCumulativeDirection = 0.0;

    var numBoidsAwareOf = 0;

    for (Boid boid in boids) {
      // this will be a part of the list
      if (boid == this) {
        continue;
      }

      final distanceToOtherBoid = _distanceToOtherPoint(boid.position);

      // separation
      if (distanceToOtherBoid <= separationDistance) {
        boidsToAvoid.add(boid.position);
        separationTurnAmount += _getTurnAmountToAvoidPoint(boid.position);
      }

      if (_isAwareOfThisPoint(boid.position, awarenessDistance, awarenessArc)) {
        boidsAwareOf.add(boid.position);

        // coherence
        if (coherenceCumulativePoint == null) {
          coherenceCumulativePoint = boid.position;
        } else {
          coherenceCumulativePoint += boid.position;
        }

        // alignment
        alignmentCumulativeDirection += boid._direction;
        numBoidsAwareOf++;
      }
    }

    // separation
    newDirection += separationTurnAmount * separationWeight;

    if (numBoidsAwareOf > 0) {
      // coherence
      final com = Point<double>(coherenceCumulativePoint.x / numBoidsAwareOf,
          coherenceCumulativePoint.y / numBoidsAwareOf);
      newDirection += _relativeDirectionToOtherPoint(com) * coherenceWeight;

      // alignment
      final averageDirectionOfOthers =
          alignmentCumulativeDirection / numBoidsAwareOf;

      final relativeDirection =
          _normaliseDirection(averageDirectionOfOthers - _direction);

      newDirection += relativeDirection * alignmentWeight;
    }

    newDirection += avoidWalls(separationDistance);

    applyNextPosition(speed, maxTurnSpeed, ds);
  }

  void readyForNextTick() {
    newDirection = 0.0;
    boidsToAvoid.clear();
    boidsAwareOf.clear();
  }

  /// dt is microseconds
  Point<double> nextPostion(double speed, double ds) {
    var nextX = _x + (cos(_direction) * speed * ds);
    var nextY = _y + (sin(_direction) * speed * ds);

    // wrap
    if (nextX > 1) {
      nextX -= 1;
    }
    if (nextX < 0) {
      nextX += 1;
    }
    if (nextY > 1) {
      nextY -= 1;
    }
    if (nextY < 0) {
      nextY += 1;
    }

    return Point(nextX, nextY);
  }

  void applyNextPosition(double speed, double maxTurnSpeed, double ds) {
    if (newDirection.abs() / ds > maxTurnSpeed) {
      newDirection = newDirection.sign * maxTurnSpeed;
    }

    _direction += newDirection;
    _direction = _normaliseDirection(_direction);

    final nextPosition = nextPostion(speed, ds);

    _x = nextPosition.x;
    _y = nextPosition.y;
  }

  /// keep direction between pi and -pi
  double _normaliseDirection(double direction) {
    if (direction.abs() > pi) {
      return direction - 2 * pi * ((direction + pi) / (2 * pi)).floor();
    } else {
      return direction;
    }
  }

  double _getTurnAmountToAvoidPoint(Point<double> pointToAvoid) {
    // we want to turn in opposite direction of other boid
    final turn = _relativeDirectionToOtherPoint(pointToAvoid);

    // we want maximum turning if other boid is straight ahead
    return (pi - turn.abs()) * -turn.sign;
  }

  bool _isAwareOfThisPoint(
    Point<double> point,
    double awarenessDistance,
    double awarenessArc,
  ) {
    if (_distanceToOtherPoint(point) <= awarenessDistance) {
      final angleToOtherBoid = _directionToOtherPoint(point);
      final minAngle = _direction - (awarenessArc / 2);
      final maxAngle = _direction + (awarenessArc / 2);
      return (angleToOtherBoid >= minAngle && angleToOtherBoid <= maxAngle);
    } else {
      return false;
    }
  }

  double avoidWalls(double separationDistance) {
    var turnAmount = 0.0;

    // left
    if (_x < separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(0, _y));
    }

    // right
    if (_x > 1 - separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(1, _y));
    }

    // top
    if (_y < separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 0));
    }

    // bottom
    if (_y > 1 - separationDistance) {
      turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 1));
    }

    return _normaliseDirection(turnAmount);
  }

  double _distanceToOtherPoint(Point<double> point) =>
      position.distanceTo(point);

  /// not relative to current direction
  double _directionToOtherPoint(Point<double> point) =>
      atan2(point.y - _y, point.x - _x);

  /// -pi to pi
  double _relativeDirectionToOtherPoint(Point<double> point) {
    return _normaliseDirection(_directionToOtherPoint(point) - _direction);
  }

  bool operator ==(dynamic other) {
    if (other is Boid) {
      return other._x == this._x &&
          other._y == this._y &&
          other._direction == this._direction;
    } else
      return false;
  }

  @override
  int get hashCode => (_x * _y * _direction).toInt();
}

class BoidPainter extends CustomPainter {
  final BoidSimulation simulation;
  final bool drawAvoidance;
  final bool drawAwareness;

  BoidPainter(
    this.simulation, {
    this.drawAvoidance = false,
    this.drawAwareness = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (simulation.drawClock) {
      for (final line in simulation.clockSegments) {
        canvas.drawLine(
            Offset(line.p1.x * size.width, line.p1.y * size.height),
            Offset(line.p2.x * size.width, line.p2.y * size.height),
            Paint()
              ..color = Colors.pink
              ..strokeWidth = 4);
      }
    }

    for (final boid in simulation.boids) {
      final boidOffset =
          Offset(boid.position.x * size.width, boid.position.y * size.height);

      _drawBoid(canvas, size, boid, boidOffset);

      if (drawAvoidance) {
        _drawAvoidance(canvas, size, boid, boidOffset);
      }

      if (drawAwareness) {
        _drawAwareness(canvas, size, boid, boidOffset);
      }
    }
  }

  void _drawBoid(Canvas canvas, Size size, Boid boid, Offset boidOffset) {
    // draw a little triangle
    final boidPath = Path()
      ..addPolygon(
        [
          Offset(-4, 4),
          Offset(8, 0),
          Offset(-4, -4),
        ],
        true,
      );

    // rotate to face direction and translate to match offset
    final transformationMatrix = Matrix4.identity()
      ..rotateZ(boid._direction)
      ..setTranslationRaw(boidOffset.dx, boidOffset.dy, 0);

    canvas.drawPath(
      boidPath.transform(transformationMatrix.storage),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.fill,
    );
  }

  void _drawAvoidance(Canvas canvas, Size size, Boid boid, Offset boidOffset) {
    // avoidance
    final avoidanceRect = Rect.fromCenter(
      center: boidOffset,
      width: simulation.separationDistance * size.width,
      height: simulation.separationDistance * size.height,
    );

    canvas.drawOval(
      avoidanceRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke,
    );

    for (final otherBoid in boid.boidsToAvoid) {
      final otherBoidOffset =
          Offset(otherBoid.x * size.width, otherBoid.y * size.height);
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
    // avoidance
    final awarenessRect = Rect.fromCenter(
      center: boidOffset,
      width: simulation.awarenessDistance * size.width * 2,
      height: simulation.awarenessDistance * size.height * 2,
    );

    canvas.drawArc(
      awarenessRect,
      boid._direction - simulation.awarenessArc / 2,
      simulation.awarenessArc,
      true,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke,
    );

    for (final otherBoid in boid.boidsAwareOf) {
      final otherBoidOffset =
          Offset(otherBoid.x * size.width, otherBoid.y * size.height);
      canvas.drawLine(
        boidOffset,
        otherBoidOffset,
        Paint()..color = Colors.green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
