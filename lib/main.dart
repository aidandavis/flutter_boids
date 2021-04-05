import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';

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
  static const boidsPerOperation = 15;
  static const boidLimit = 200;
  static const fpsAverageCount = 10;

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int dt = 0;

  List<int> fpsList = [];

  double speed = 0.15;
  double maxTurnSpeed = 0.05;

  double avoidanceDistance = 0.02;
  double avoidanceWeight = 0.375;

  double awarenessArc = pi;
  double awarenessDistance = 0.1;

  double coherenceWeight = 0.05;
  double alignmentWeight = 0.125;

  Offset coherencePosition = Offset(0.5, 0.5);

  bool cohereToPoint = false;

  bool drawAvoidance = false;
  bool drawAwareness = false;

  @override
  void initState() {
    super.initState();

    _addBoids(50);

    createTicker(_tick)..start();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _tick(Duration totalElapsedDuration) {
    // microseconds are smoother
    dt = totalElapsedDuration.inMicroseconds - lastFrameTime;
    lastFrameTime = totalElapsedDuration.inMicroseconds;

    var ds = dt / 1000000;

    _calculateFps();

    while (boids.length > boidLimit) {
      _removeBoids();
    }

    for (Boid boid in boids) {
      boid.iterate(
        boids,
        ds,
        cohereToPoint,
        Point(coherencePosition.dx, coherencePosition.dy),
      );
    }

    setState(() {});
  }

  void _calculateFps() {
    final safeDt = dt == 0 ? 1 : dt;

    fpsList.add(1000000 ~/ safeDt);

    if (fpsList.length > fpsAverageCount) {
      fpsList.removeAt(0);
    }
  }

  void _addBoids([int numToAdd = boidsPerOperation]) {
    this.setState(() {
      for (var i = 0; i < numToAdd; i++) {
        boids.add(Boid.createRandom(
          speed: speed,
          maxTurnSpeed: maxTurnSpeed,
          separationDistance: avoidanceDistance,
          separationWeight: avoidanceWeight,
          awarenessDistance: awarenessDistance,
          awarenessArc: awarenessArc,
          coherenceWeight: coherenceWeight,
          alignmentWeight: alignmentWeight,
        ));
      }
    });
  }

  void _removeBoids([int numToRemove = boidsPerOperation]) {
    if (numToRemove > boids.length) {
      numToRemove = boids.length;
    }

    this.setState(() {
      for (var i = 0; i < numToRemove; i++) {
        boids.removeAt(Random().nextInt(boids.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final fps = fpsList.isNotEmpty
        ? fpsList.reduce((value, element) => value + element) / fpsList.length
        : 60;

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
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    coherencePosition = Offset(
                      details.localPosition.dx / screenSize.shortestSide,
                      details.localPosition.dy / screenSize.shortestSide,
                    );
                  });
                },
                child: CustomPaint(
                  size: Size(
                    screenSize.shortestSide,
                    screenSize.shortestSide,
                  ),
                  painter: BoidPainter(
                    boids,
                    cohereToPoint,
                    coherencePosition,
                    drawAvoidance: drawAvoidance,
                    drawAwareness: drawAwareness,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Text(
                'fps: $fps (${boids.length})',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: ElevatedButton(
                      child: Text('Add boids'),
                      onPressed: () => _addBoids(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: ElevatedButton(
                      child: Text('Remove boids'),
                      onPressed: () => _removeBoids(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: ElevatedButton(
                      child:
                          Text('${drawAvoidance ? 'Hide' : 'Show'} Avoidance'),
                      onPressed: () {
                        setState(() {
                          drawAvoidance = !drawAvoidance;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: ElevatedButton(
                      child:
                          Text('${drawAwareness ? 'Hide' : 'Show'} Awareness'),
                      onPressed: () {
                        setState(() {
                          drawAwareness = !drawAwareness;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: ElevatedButton(
                      child: Text(
                          '${cohereToPoint ? 'Stop' : 'Start'} Cohherence to Point'),
                      onPressed: () {
                        setState(() {
                          cohereToPoint = !cohereToPoint;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  double speed;
  double maxTurnSpeed; // how many radians per second this boid can turn

  double separationDistance;
  double separationWeight;

  List<Point> boidsToAvoid = [];

  double awarenessDistance;
  double awarenessArc;
  List<Point> boidsAwareOf = [];

  double coherenceWeight;
  double alignmentWeight;

  /// create a boid with random velocity starting in the center
  Boid.createRandom({
    @required this.speed,
    @required this.maxTurnSpeed,
    @required this.separationDistance,
    @required this.separationWeight,
    @required this.awarenessDistance,
    @required this.awarenessArc,
    @required this.coherenceWeight,
    @required this.alignmentWeight,
  }) {
    _x = 0.5;
    _y = 0.5;

    _direction = -2 * pi * (Random().nextDouble() * 2 * pi);
    // _direction = pi / 2;
  }

  Point<double> get position => Point<double>(_x, _y);

  /// process the next step
  void iterate(
    List boids,
    double ds,
    bool cohereToPoint,
    Point<double> coherencePoint,
  ) {
    readyForNextTick();

    // cohere to point
    if (cohereToPoint) {
      newDirection +=
          _relativeDirectionToOtherPoint(coherencePoint) * coherenceWeight * 2;
    }

    // avoidWalls();

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

      // coherence
      if (coherenceCumulativePoint == null) {
        coherenceCumulativePoint = boid.position;
      } else {
        coherenceCumulativePoint += boid.position;
      }

      if (_isAwareOfThisPoint(boid.position)) {
        // alignment
        boidsAwareOf.add(boid.position);
        alignmentCumulativeDirection += boid._direction;
        numBoidsAwareOf++;
      }
    }

    // separation
    newDirection += separationTurnAmount * separationWeight;

    // coherence
    final com = Point<double>(coherenceCumulativePoint.x / (boids.length - 1),
        coherenceCumulativePoint.y / (boids.length - 1));
    newDirection += _relativeDirectionToOtherPoint(com) * coherenceWeight;

    if (numBoidsAwareOf > 0) {
      // alignment
      final averageDirectionOfOthers =
          alignmentCumulativeDirection / numBoidsAwareOf;

      final relativeDirection =
          _normaliseDirection(averageDirectionOfOthers - _direction);

      newDirection += relativeDirection * alignmentWeight;
    }

    applyNextPosition(ds);
  }

  void readyForNextTick() {
    newDirection = 0.0;
    boidsToAvoid.clear();
    boidsAwareOf.clear();
  }

  /// dt is microseconds
  Point<double> nextPostion(double ds) {
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

  void applyNextPosition(double ds) {
    if (newDirection.abs() / ds > maxTurnSpeed) {
      newDirection = newDirection.sign * maxTurnSpeed;
    }

    _direction += newDirection;
    _direction = _normaliseDirection(_direction);

    final nextPosition = nextPostion(ds);

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

  bool _isAwareOfThisPoint(Point<double> point) {
    if (_distanceToOtherPoint(point) <= awarenessDistance) {
      final angleToOtherBoid = _directionToOtherPoint(point);
      final minAngle = _direction - (awarenessArc / 2);
      final maxAngle = _direction + (awarenessArc / 2);
      return (angleToOtherBoid >= minAngle && angleToOtherBoid <= maxAngle);
    } else {
      return false;
    }
  }

  // void avoidWalls() {
  //   var turnAmount = 0.0;

  //   // left
  //   if (_x < separationDistance) {
  //     turnAmount += _getTurnAmountToAvoidPoint(Point(0, _y));
  //   }

  //   // right
  //   if (_x > 1 - separationDistance) {
  //     turnAmount += _getTurnAmountToAvoidPoint(Point(1, _y));
  //   }

  //   // top
  //   if (_y < separationDistance) {
  //     turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 0));
  //   }

  //   // bottom
  //   if (_y > 1 - separationDistance) {
  //     turnAmount += _getTurnAmountToAvoidPoint(Point(_x, 1));
  //   }

  //   newDirection += _normaliseDirection(turnAmount);
  // }

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
          other._direction == this._direction &&
          other.speed == this.speed;
    } else
      return false;
  }

  @override
  int get hashCode => (_x * _y * _direction * speed).toInt();
}

class BoidPainter extends CustomPainter {
  final List<Boid> boids;
  final bool cohereToPoint;
  final Offset coherencePosition;
  final bool drawAvoidance;
  final bool drawAwareness;

  BoidPainter(this.boids, this.cohereToPoint, this.coherencePosition,
      {this.drawAvoidance = true, this.drawAwareness = true});

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
      width: boid.separationDistance * size.width * 2,
      height: boid.separationDistance * size.height * 2,
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
      width: boid.awarenessDistance * size.width * 2,
      height: boid.awarenessDistance * size.height * 2,
    );

    canvas.drawArc(
      awarenessRect,
      boid._direction - boid.awarenessArc / 2,
      boid.awarenessArc,
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
