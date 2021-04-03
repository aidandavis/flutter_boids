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

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int dt = 0;

  double speed = 0.05;
  double maxTurnSpeed = 0.05;

  double avoidanceArc = 4 / 3 * pi;
  double avoidanceDistance = 0.075;
  double avoidanceWeight = 0.01;

  @override
  void initState() {
    super.initState();

    _addBoids(10);

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

    if (ds == 0) {
      ds = 0.0167;
    }

    while (boids.length > boidLimit) {
      _removeBoids();
    }

    for (var boid in boids) {
      boid.readyForNextTick();

      boid.avoidOtherBoids(boids, ds);

      boid.applyNextPosition(ds);
    }

    setState(() {});
  }

  void _addBoids([int numToAdd = boidsPerOperation]) {
    this.setState(() {
      for (var i = 0; i < numToAdd; i++) {
        boids.add(Boid.createRandom(
          speed: speed,
          maxTurnSpeed: maxTurnSpeed,
          avoidanceDistance: avoidanceDistance,
          avoidanceArc: avoidanceArc,
          avoidanceWeight: avoidanceWeight,
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
    final safeDt = dt == 0 ? 1 : dt;

    return Scaffold(
      body: CustomPaint(
        painter: BoidPainter(boids),
        child: Container(
          height: screenSize.height,
          width: screenSize.width,
          child: Stack(
            children: [
              Positioned(
                child: Text('fps: ${1000000 ~/ safeDt} (${boids.length})'),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  double avoidanceDistance;
  double avoidanceArc; // in radians, centered on direction
  double avoidanceWeight;

  List<Point> boidsToAvoid = [];

  /// create a boid with random velocity starting in the center
  Boid.createRandom({
    @required this.speed,
    @required this.maxTurnSpeed,
    @required this.avoidanceDistance,
    @required this.avoidanceArc,
    @required this.avoidanceWeight,
  }) {
    _x = 0.5;
    _y = 0.5;

    _direction = -2 * pi * (Random().nextDouble() * 2 * pi);
    // _direction = pi / 2;
  }

  get position => Point<double>(_x, _y);

  void readyForNextTick() {
    newDirection = 0.0;
    boidsToAvoid.clear();
  }

  /// dt is microseconds
  Point<double> nextPostion(double ds) {
    var nextX = _x + (cos(_direction) * speed * ds);
    var nextY = _y + (sin(_direction) * speed * ds);

    // wrapping
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
    if (newDirection.abs() > maxTurnSpeed) {
      newDirection = newDirection.sign * maxTurnSpeed;
    }

    _direction += newDirection;
    _normaliseDirection();

    final nextPosition = nextPostion(ds);

    _x = nextPosition.x;
    _y = nextPosition.y;
  }

  /// keep direction between pi and -pi
  void _normaliseDirection() {
    if (_direction.abs() > pi) {
      _direction = _direction - 2 * pi * ((_direction + pi) / (2 * pi)).floor();
    }
  }

  void avoidOtherBoids(List<Boid> boids, double ds) {
    var turnAmount = 0.0;

    for (final boid in boids) {
      // this boid will be part of the list, so skip it
      if (boid == this) {
        continue;
      }

      if (distanceToPoint(boid.position) <= avoidanceDistance) {
        // scaled to 0 +- pi
        final angleToOtherBoid =
            atan2(boid.position.y - _y, boid.position.x - _x);

        final scaledDirection = _direction + pi;
        final scaledAngleToOtherBoid = angleToOtherBoid + pi;

        final minAvoidanceBound = scaledDirection - (avoidanceArc / 2);
        final maxAvoidanceBound = scaledDirection + (avoidanceArc / 2);

        if (scaledAngleToOtherBoid >= minAvoidanceBound &&
            scaledAngleToOtherBoid <= maxAvoidanceBound) {
          boidsToAvoid.add(boid.position);

          newDirection += avoidanceWeight *
              (pi - (_direction - angleToOtherBoid)) *
              (_direction - angleToOtherBoid).sign;
        }
      }
    }

    newDirection += turnAmount;
  }

  void avoidWalls(double ds) {
    final nextPosition = nextPostion(ds);

    if (nextPosition.x < avoidanceDistance) {}
  }

  double distanceToPoint(Point point) => position.distanceTo(point);

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

  BoidPainter(this.boids);

  @override
  void paint(Canvas canvas, Size size) {
    for (var boid in boids) {
      final boidOffset =
          Offset(boid.position.x * size.width, boid.position.y * size.height);

      canvas.drawCircle(boidOffset, 4, Paint()..color = Colors.red);

      // _drawAvoidance(canvas, size, boid);

      // for (final otherBoid in boid.boidsToAvoid) {
      //   final otherBoidOffset =
      //       Offset(otherBoid.x * size.width, otherBoid.y * size.height);
      //   canvas.drawLine(
      //     boidOffset,
      //     otherBoidOffset,
      //     Paint()
      //       ..color = Colors.black
      //       ..strokeWidth = 2,
      //   );
      // }
    }
  }

  void _drawAvoidance(Canvas canvas, Size size, Boid boid) {
    final boidOffset =
        Offset(boid.position.x * size.width, boid.position.y * size.height);

    // avoidance
    final avoidanceRect = Rect.fromCenter(
      center: boidOffset,
      width: boid.avoidanceDistance * size.width * 2,
      height: boid.avoidanceDistance * size.height * 2,
    );

    // left
    canvas.drawArc(
      avoidanceRect,
      boid._direction - boid.avoidanceArc / 2,
      boid.avoidanceArc / 2,
      true,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (boid.newDirection.sign < 0) {
      canvas.drawArc(
        avoidanceRect,
        boid._direction - boid.avoidanceArc / 2,
        boid.avoidanceArc / 2,
        true,
        Paint()
          ..color = Colors.blue
              .withOpacity(0.5 * boid.newDirection.abs() / boid.maxTurnSpeed)
          ..style = PaintingStyle.fill
          ..strokeWidth = 2,
      );
    }

    // right
    canvas.drawArc(
      avoidanceRect,
      boid._direction,
      boid.avoidanceArc / 2,
      true,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (boid.newDirection.sign > 0) {
      canvas.drawArc(
        avoidanceRect,
        boid._direction,
        boid.avoidanceArc / 2,
        true,
        Paint()
          ..color = Colors.red
              .withOpacity(0.5 * boid.newDirection.abs() / boid.maxTurnSpeed)
          ..style = PaintingStyle.fill
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
