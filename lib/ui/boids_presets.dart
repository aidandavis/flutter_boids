import 'package:flutter/foundation.dart';

@immutable
class BoidsPreset {
  const BoidsPreset({
    required this.name,
    required this.boids,
    required this.speed,
    required this.perception,
    required this.separation,
    required this.turnRate,
    required this.wSep,
    required this.wAli,
    required this.wCoh,
    required this.attractor,
    required this.trails,
    required this.glow,
  });

  final String name;
  final int boids;
  final double speed;
  final double perception;
  final double separation;
  final double turnRate;
  final double wSep;
  final double wAli;
  final double wCoh;
  final double attractor;
  final bool trails;
  final bool glow;

  const BoidsPreset.murmuration()
      : this(
          name: 'Murmuration',
          boids: 200,
          speed: 0.22,
          perception: 0.115,
          separation: 0.032,
          turnRate: 4.6,
          wSep: 1.55,
          wAli: 1.05,
          wCoh: 0.85,
          attractor: 1.15,
          trails: true,
          glow: true,
        );

  const BoidsPreset.school()
      : this(
          name: 'School',
          boids: 320,
          speed: 0.19,
          perception: 0.105,
          separation: 0.026,
          turnRate: 5.6,
          wSep: 1.25,
          wAli: 1.45,
          wCoh: 0.70,
          attractor: 1.10,
          trails: true,
          glow: true,
        );

  const BoidsPreset.fireflies()
      : this(
          name: 'Fireflies',
          boids: 180,
          speed: 0.12,
          perception: 0.165,
          separation: 0.022,
          turnRate: 8.0,
          wSep: 0.95,
          wAli: 0.55,
          wCoh: 1.25,
          attractor: 0.95,
          trails: false,
          glow: true,
        );

  const BoidsPreset.chaos()
      : this(
          name: 'Chaos',
          boids: 600,
          speed: 0.31,
          perception: 0.075,
          separation: 0.018,
          turnRate: 12.0,
          wSep: 1.95,
          wAli: 0.35,
          wCoh: 0.25,
          attractor: 1.35,
          trails: true,
          glow: false,
        );
}

const List<BoidsPreset> kBoidsPresets = <BoidsPreset>[
  BoidsPreset.murmuration(),
  BoidsPreset.school(),
  BoidsPreset.fireflies(),
  BoidsPreset.chaos(),
];
