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

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int dt = 0;

  double speed = 0.1;

  double avoidanceArc = 4 / 3 * pi;
  double avoidanceDistance = 0.05;

  @override
  void initState() {
    _addBoids(20);

    createTicker(_tick)..start();

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
      boid.applyNextPosition(dt);
    }

    setState(() {});
  }

  void _addBoids([int numToAdd = boidsPerOperation]) {
    this.setState(() {
      for (var i = 0; i < numToAdd; i++) {
        boids.add(Boid.createRandom(
          speed: speed,
          avoidanceDistance: avoidanceDistance,
          avoidanceArc: avoidanceArc,
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
  double _direction; // radians

  double speed;

  double avoidanceDistance;

  // in radians, centered on direction
  double avoidanceArc;

  Boid(
    this._x,
    this._y,
    this._direction,
    this.speed,
    this.avoidanceArc,
    this.avoidanceDistance,
  );

  /// create a boid with random velocity starting in the center
  Boid.createRandom(
      {this.speed = 10,
      this.avoidanceArc = pi,
      this.avoidanceDistance = 0.05}) {
    _x = 0.5;
    _y = 0.5;

    _direction = (Random().nextDouble() * 2 * pi);
  }

  get position => Point<double>(_x, _y);

  /// dt is microseconds
  Point<double> nextPostion(int dt) {
    final seconds = dt / 1000000;

    var nextX = _x + (cos(_direction) * speed * seconds);
    var nextY = _y + (sin(_direction) * speed * seconds);

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

  void applyNextPosition(int dt) {
    final nextPosition = nextPostion(dt);

    _x = nextPosition.x;
    _y = nextPosition.y;
  }

  double distanceToPoint(Point point) => position.distanceTo(point);

  bool operator ==(dynamic other) {
    if (other is Boid) {
      return other.position == this.position &&
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
  final double avoidanceDistance;

  BoidPainter(this.boids, this.avoidanceDistance);

  @override
  void paint(Canvas canvas, Size size) {
    for (var boid in boids) {
      final boidOffset =
          Offset(boid.position.x * size.width, boid.position.y * size.height);

      canvas.drawCircle(boidOffset, 3, Paint()..color = Colors.red);

      final avoidanceRect = Rect.fromCenter(
        center: boidOffset,
        width: avoidanceDistance * size.width,
        height: avoidanceDistance * size.height,
      );

      // left
      canvas.drawArc(
        avoidanceRect,
        boid._direction - boid.avoidanceArc / 2,
        boid.avoidanceArc / 2,
        true,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke,
      );

      // right
      canvas.drawArc(
        avoidanceRect,
        boid._direction,
        boid.avoidanceArc / 2,
        true,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke,
      );

      // canvas.drawOval(Paint()
      //   ..color = Colors.green
      //   ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
