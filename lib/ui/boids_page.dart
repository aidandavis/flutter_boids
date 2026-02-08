import 'dart:async';

import 'package:flutter/material.dart';

import '../boids/boids_engine.dart';
import '../boids/boids_painter.dart';
import 'backdrop.dart';
import 'boids_controls.dart';
import 'boids_scene.dart';

class BoidsPage extends StatefulWidget {
  const BoidsPage({super.key});

  @override
  State<BoidsPage> createState() => _BoidsPageState();
}

class _BoidsPageState extends State<BoidsPage>
    with SingleTickerProviderStateMixin {
  late final BoidsEngine _engine;
  late final BoidsPainter _painter;

  bool _showIntro = true;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();

    _engine = BoidsEngine(
      vsync: this,
      capacity: 600,
      initialBoids: 200,
      gridResolution: 20,
      statsHz: 4,
    );
    _painter = BoidsPainter(engine: _engine);

    _introTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _showIntro = false);
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _dismissIntro() {
    if (!_showIntro) return;
    setState(() => _showIntro = false);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= 980;

            if (wide) {
              return Stack(
                children: [
                  const Positioned.fill(child: BoidsBackdrop()),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: BoidsSceneCard(
                              engine: _engine,
                              painter: _painter,
                              showIntro: _showIntro,
                              onDismissIntro: _dismissIntro,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 400,
                            child: _GlassPanel(
                              child: BoidsControls(
                                engine: _engine,
                                dense: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                const Positioned.fill(child: BoidsBackdrop()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: BoidsSceneCard(
                      engine: _engine,
                      painter: _painter,
                      showIntro: _showIntro,
                      onDismissIntro: _dismissIntro,
                    ),
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.20,
                  minChildSize: 0.12,
                  maxChildSize: 0.86,
                  builder: (context, scrollController) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _GlassPanel(
                        child: BoidsControls(
                          engine: _engine,
                          dense: true,
                          scrollController: scrollController,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC070A10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            color: Colors.black.withAlpha(89),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}
