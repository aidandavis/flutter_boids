import 'package:flutter/material.dart';

import 'ui/boids_page.dart';

void main() {
  runApp(const BoidsApp());
}

class BoidsApp extends StatelessWidget {
  const BoidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF2EF2C7);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.standard,
    );

    return MaterialApp(
      title: 'Boids Playground',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF070A10),
        sliderTheme: base.sliderTheme.copyWith(
          trackHeight: 3.0,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        cardTheme: base.cardTheme.copyWith(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const BoidsPage(),
    );
  }
}
