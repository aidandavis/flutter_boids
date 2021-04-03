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

  // list of boids
  final List<Boid> boids = [];

  /// time of last frame in microseconds
  int lastFrameTime = 0;
  int fps;

  @override
  void initState() {
    createTicker(_tick)..start();

    _addBoids();

    super.initState();
  }

  _tick(Duration totalElapsedDuration) {
    int dt = totalElapsedDuration.inMicroseconds - lastFrameTime;
    lastFrameTime = totalElapsedDuration.inMicroseconds;

    if (dt == 0) {
      dt = 1;
    }

    fps = 1000000 ~/ dt;

    for (var boid in boids) {
      boid.applyVelocity(dt);
    }

    setState(() {});
  }

  void _addBoids() {
    this.setState(() {
      for (var i = 0; i < boidsPerOperation; i++) {
        boids.add(Boid.createRandom());
      }
    });
  }

  void _removeBoids() {
    this.setState(() {
      for (var i = 0; i < boidsPerOperation; i++) {
        boids.removeAt(Random().nextInt(boids.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: CustomPaint(
        painter: BoidPainter(boids),
        child: Container(
          height: screenSize.height,
          width: screenSize.width,
          child: Stack(
            children: [
              Positioned(
                child: Text('fps: ${fps ?? 0} (${boids.length})'),
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
  double x;
  double y;

  // velocity
  double vx;
  double vy;

  Boid(this.x, this.y, this.vx, this.vy);

  /// create a boid with random velocity starting in the center
  Boid.createRandom() {
    x = 0.5;
    y = 0.5;

    vx = (Random().nextDouble() - 0.5) * 10;
    vy = (Random().nextDouble() - 0.5) * 10;
  }

  void applyVelocity(int dt) {
    final seconds = dt / 1000000;

    x += vx * 0.01 * seconds;
    if (x > 1) {
      x = x - 1;
    }
    if (x < 0) {
      x = x + 1;
    }

    y += vy * 0.01 * seconds;
    if (y > 1) {
      y = y - 1;
    }
    if (y < 0) {
      y = y + 1;
    }
  }
}

class BoidPainter extends CustomPainter {
  final List<Boid> boids;

  BoidPainter(this.boids);

  @override
  void paint(Canvas canvas, Size size) {
    for (var boid in boids) {
      var boidPosition = Offset(boid.x * size.width, boid.y * size.height);
      canvas.drawCircle(boidPosition, 3, Paint()..color = Colors.red);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
