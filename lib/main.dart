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
      title: 'Flutter Demo',
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

  double agility = 0.25;
  double speedLimit = 10;

  double avoidanceDistance = 0.025;
  double avoidanceFactor = 100;

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int dt = 0;

  @override
  void initState() {
    createTicker(_tick)..start();

    _addBoids(50);

    super.initState();
  }

  _tick(Duration totalElapsedDuration) {
    // microseconds are smoother
    dt = totalElapsedDuration.inMicroseconds - lastFrameTime;
    lastFrameTime = totalElapsedDuration.inMicroseconds;

    while (boids.length > boidLimit) {
      _removeBoids();
    }

    for (var boid in boids) {
      boid.avoidOthers(boids, dt);

      boid.applyNextPosition(dt);
    }

    setState(() {});
  }

  void _addBoids([int numToAdd = boidsPerOperation]) {
    this.setState(() {
      for (var i = 0; i < numToAdd; i++) {
        boids.add(Boid.createRandom(
          maxVelocity: speedLimit,
          agility: agility,
          avoidanceDistance: avoidanceDistance,
          avoidanceFactor: avoidanceFactor,
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
        painter: BoidPainter(boids, avoidanceDistance),
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
/// velocity will be in 0.01 units per second
class Boid {
  //posistion
  double _x;
  double _y;

  // velocity
  double _vx;
  double _vy;

  // velocity changes to apply before next tick
  double dvx = 0.0;
  double dvy = 0.0;

  /// limit of change to velocity per second
  double agility;

  /// maximum velocity
  double maxVelocity;

  double avoidanceDistance;
  double avoidanceFactor;

  Boid(
    this._x,
    this._y,
    this._vx,
    this._vy, {
    this.maxVelocity = 10,
    this.agility = 1,
    this.avoidanceDistance = 0.05,
    this.avoidanceFactor = 10,
  });

  /// create a boid with random velocity starting in the center
  Boid.createRandom({
    this.maxVelocity = 10,
    this.agility = 1,
    this.avoidanceDistance = 0.05,
    this.avoidanceFactor = 10,
  }) {
    _x = 0.5;
    _y = 0.5;

    _vx = (Random().nextDouble() - 0.5) * 10;
    _vy = (Random().nextDouble() - 0.5) * 10;
  }

  get position => Point<double>(_x, _y);

  /// dt is microseconds
  Point<double> nextPostion(int dt) {
    final seconds = dt / 1000000;

    var nextX = _x + _vx * 0.01 * seconds;
    var nextY = _y + _vy * 0.01 * seconds;

    return Point(nextX, nextY);
  }

  /// avoid the edges
  void _avoidWalls() {
    var dx = 0.0;
    var dy = 0.0;

    // left edge
    if (_x < avoidanceDistance) {
      dx += _x.abs();
    }

    // right edge
    if (1 - _x < avoidanceDistance) {
      dx -= (1 - _x).abs();
    }

    // top edge
    if (_y < avoidanceDistance) {
      dy += _y.abs();
    }

    // bottom edge
    if (1 - _y < avoidanceDistance) {
      dy -= (1 - _y).abs();
    }

    dvx += dx * avoidanceFactor;
    dvy += dy * avoidanceFactor;
  }

  void applyNextPosition(int dt) {
    _avoidWalls();
    _applyVelocities();
    _limitTotalVelocity();

    final nextPosition = nextPostion(dt);

    _x = nextPosition.x;
    _y = nextPosition.y;
  }

  void _applyVelocities() {
    if (dvx > agility) {
      dvx = agility;
    }
    if (dvx < -agility) {
      dvx = -agility;
    }
    _vx += dvx;

    if (dvy > agility) {
      dvy = agility;
    }
    if (dvy < -agility) {
      dvy = -agility;
    }
    _vy += dvy;

    dvx = 0.0;
    dvy = 0.0;
  }

  void _limitTotalVelocity() {
    final totalVelocity = sqrt(_vx * _vx + _vy * _vy);
    if (totalVelocity > maxVelocity) {
      _vx = (_vx / totalVelocity) * maxVelocity;
      _vy = (_vy / totalVelocity) * maxVelocity;
    }
  }

  void avoidOthers(
    List<Boid> boids,
    int dt, {
    bool useNextPosition = true,
  }) {
    var dx = 0.0;
    var dy = 0.0;

    for (var boid in boids) {
      // this boid would be in the list, so skip it
      if (boid == this) {
        continue;
      }

      final positionOfOther =
          useNextPosition ? boid.nextPostion(dt) : boid.position;

      final distanceToOther = distanceToPoint(positionOfOther);

      if (distanceToOther < avoidanceDistance) {
        dx += _x - positionOfOther.x;
        dy += _y - positionOfOther.y;
      }
    }

    dvx += dx * avoidanceFactor;
    dvy += dy * avoidanceFactor;
  }

  double distanceToPoint(Point point) => position.distanceTo(point);

  bool operator ==(dynamic other) {
    if (other is Boid) {
      return other.position == this.position &&
          other._vx == this._vx &&
          other._vy == this._vy;
    } else
      return false;
  }

  @override
  int get hashCode => (_x * _y * _vx * _vy).toInt();
}

class BoidPainter extends CustomPainter {
  final List<Boid> boids;
  final double avoidanceDistance;

  BoidPainter(this.boids, this.avoidanceDistance);

  @override
  void paint(Canvas canvas, Size size) {
    for (var boid in boids) {
      var boidOffset =
          Offset(boid.position.x * size.width, boid.position.y * size.height);
      canvas.drawCircle(boidOffset, 3, Paint()..color = Colors.red);

      canvas.drawOval(
          Rect.fromCenter(
            center: boidOffset,
            width: avoidanceDistance * size.width,
            height: avoidanceDistance * size.height,
          ),
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
