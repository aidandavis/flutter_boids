import 'package:flutter/material.dart';

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

class _MyHomePageState extends State<MyHomePage> {
  var mx = 0.0;
  var my = 0.0;

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: MouseRegion(
        onHover: (event) => setState(() {
          mx = event.position.dx;
          my = event.position.dy;
        }),
        child: Stack(
          children: [
            Positioned(
              left: 2,
              bottom: 2,
              child: Text(
                screenSize.toString(),
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Text(
                '$mx, $my',
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            Positioned(
              left: screenSize.width / 2,
              top: screenSize.height / 4,
              child: SizedBox(
                height: 20,
                width: 20,
                child: Container(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
