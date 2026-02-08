import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../boids/boids_engine.dart';
import '../boids/boids_painter.dart';
import 'backdrop.dart';

class BoidsSceneCard extends StatelessWidget {
  const BoidsSceneCard({
    super.key,
    required this.engine,
    required this.painter,
    required this.showIntro,
    required this.onDismissIntro,
  });

  final BoidsEngine engine;
  final BoidsPainter painter;
  final bool showIntro;
  final VoidCallback onDismissIntro;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double s = math.min(constraints.maxWidth, constraints.maxHeight);

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071623),
                  Color(0xFF0A0B14),
                  Color(0xFF070814),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: BoidsGrain()),
                Center(
                  child: SizedBox.square(
                    dimension: s,
                    child: _BoidsCanvas(
                      engine: engine,
                      painter: painter,
                      onDismissIntro: onDismissIntro,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StatsPill(engine: engine),
                ),
                if (showIntro)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _IntroPill(onDismiss: onDismissIntro),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoidsCanvas extends StatefulWidget {
  const _BoidsCanvas({
    required this.engine,
    required this.painter,
    required this.onDismissIntro,
  });

  final BoidsEngine engine;
  final BoidsPainter painter;
  final VoidCallback onDismissIntro;

  @override
  State<_BoidsCanvas> createState() => _BoidsCanvasState();
}

class _BoidsCanvasState extends State<_BoidsCanvas> {
  bool _shiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  void _setAttractor(Offset local, double size, {required bool active}) {
    if (!active) {
      widget.engine.setAttractor(null, repel: false);
      return;
    }

    final Offset norm = Offset(
      (local.dx / size).clamp(0.0, 1.0),
      (local.dy / size).clamp(0.0, 1.0),
    );
    widget.engine.setAttractor(
      norm,
      repel: _shiftPressed() || widget.engine.dragRepels,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        if (!widget.engine.visualizeSelected) return;
        final RenderBox box = context.findRenderObject()! as RenderBox;
        final Offset p = box.globalToLocal(d.globalPosition);
        final double s = box.size.shortestSide;
        final Offset norm = Offset(
          (p.dx / s).clamp(0.0, 1.0),
          (p.dy / s).clamp(0.0, 1.0),
        );
        widget.engine.selectNearestBoid(norm);
      },
      onPanStart: (d) {
        widget.onDismissIntro();
        final RenderBox box = context.findRenderObject()! as RenderBox;
        _setAttractor(d.localPosition, box.size.shortestSide, active: true);
      },
      onPanUpdate: (d) {
        final RenderBox box = context.findRenderObject()! as RenderBox;
        _setAttractor(d.localPosition, box.size.shortestSide, active: true);
      },
      onPanEnd: (_) => _setAttractor(Offset.zero, 1.0, active: false),
      onPanCancel: () => _setAttractor(Offset.zero, 1.0, active: false),
      child: CustomPaint(
        painter: widget.painter,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill({required this.engine});

  final BoidsEngine engine;

  @override
  Widget build(BuildContext context) {
    final TextStyle s = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: Colors.white.withAlpha(235),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ValueListenableBuilder<BoidsStats>(
      valueListenable: engine.stats,
      builder: (context, stats, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x990B0F14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '${stats.fps} fps  |  ${stats.boids} boids  |  ${stats.frameMs.toStringAsFixed(1)} ms',
              style: s,
            ),
          ),
        );
      },
    );
  }
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xCC0B0F14), Color(0x990B0F14)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.scatter_plot, size: 18, color: Color(0xFF2EF2C7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Drag to attract. Toggle Repel (or hold Shift) to push away. Then play with the rules.',
                style: TextStyle(
                  color: Colors.white.withAlpha(217),
                  height: 1.15,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: Colors.white.withAlpha(204),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

class BoidsBackground extends StatelessWidget {
  const BoidsBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(child: BoidsBackdrop()),
      ],
    );
  }
}
