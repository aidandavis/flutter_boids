import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../boids/boids_engine.dart';
import 'boids_presets.dart';

class BoidsControls extends StatefulWidget {
  const BoidsControls({
    super.key,
    required this.engine,
    required this.dense,
    this.scrollController,
  });

  final BoidsEngine engine;
  final bool dense;
  final ScrollController? scrollController;

  @override
  State<BoidsControls> createState() => _BoidsControlsState();
}

class _BoidsControlsState extends State<BoidsControls> {
  late int _boids;
  late double _speed;
  late double _perception;
  late double _separation;
  late double _turnRate;
  late double _wSep;
  late double _wAli;
  late double _wCoh;
  late bool _dragRepels;
  late bool _sepOn;
  late bool _aliOn;
  late bool _cohOn;
  late bool _trails;
  late bool _glow;
  late bool _paused;
  late bool _vizSelected;

  BoidsEngine get _e => widget.engine;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    _boids = _e.boidCount;
    _speed = _e.speed;
    _perception = _e.perceptionRadius;
    _separation = _e.separationRadius;
    _turnRate = _e.maxTurnRate;
    _wSep = _e.separationWeight;
    _wAli = _e.alignmentWeight;
    _wCoh = _e.cohesionWeight;
    _dragRepels = _e.dragRepels;
    _sepOn = _e.separationEnabled;
    _aliOn = _e.alignmentEnabled;
    _cohOn = _e.cohesionEnabled;
    _trails = _e.trailsEnabled;
    _glow = _e.glowEnabled;
    _paused = _e.paused;
    _vizSelected = _e.visualizeSelected;
  }

  void _applyPreset(BoidsPreset p) {
    _e.setBoidCount(p.boids);
    _e.speed = p.speed;
    _e.perceptionRadius = p.perception;
    _e.separationRadius = p.separation;
    _e.maxTurnRate = p.turnRate;
    _e.separationWeight = p.wSep;
    _e.alignmentWeight = p.wAli;
    _e.cohesionWeight = p.wCoh;
    _e.separationEnabled = true;
    _e.alignmentEnabled = true;
    _e.cohesionEnabled = true;
    _e.trailsEnabled = p.trails;
    _e.glowEnabled = p.glow;
    _e.attractorWeight = p.attractor;
    _e.setPaused(false);

    setState(_hydrate);
  }

  @override
  Widget build(BuildContext context) {
    final bool dense = widget.dense;

    final TextStyle labelStyle =
        Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Colors.white.withAlpha(219),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontSize: dense ? 12.0 : 13.0,
            );

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(16, dense ? 10 : 18, 16, 18),
      children: [
        _PanelHeader(
          dense: dense,
          paused: _paused,
          onPause: () {
            setState(() {
              _paused = !_paused;
              _e.setPaused(_paused);
            });
          },
          onRandomize: () => _e.randomize(),
          onReset: () => _applyPreset(const BoidsPreset.murmuration()),
        ),
        const SizedBox(height: 12),
        _DragModeRow(
          dense: dense,
          repel: _dragRepels,
          onChanged: (repel) {
            setState(() => _dragRepels = repel);
            _e.setDragRepels(repel);
          },
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Presets', dense: dense),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in kBoidsPresets)
              ActionChip(label: Text(p.name), onPressed: () => _applyPreset(p)),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: 'Rules', dense: dense),
        const SizedBox(height: 6),
        Text(
          'Toggle rules to see how each one changes the flock.',
          style: TextStyle(color: Colors.white.withAlpha(158), height: 1.25),
        ),
        const SizedBox(height: 12),
        _RuleToggleRow(
          dense: dense,
          labelStyle: labelStyle,
          name: 'Separation',
          description: 'Avoid crowding.',
          value: _sepOn,
          onChanged: (v) {
            setState(() {
              _sepOn = v;
              _e.separationEnabled = v;
            });
          },
        ),
        _RuleToggleRow(
          dense: dense,
          labelStyle: labelStyle,
          name: 'Alignment',
          description: 'Match direction.',
          value: _aliOn,
          onChanged: (v) {
            setState(() {
              _aliOn = v;
              _e.alignmentEnabled = v;
            });
          },
        ),
        _RuleToggleRow(
          dense: dense,
          labelStyle: labelStyle,
          name: 'Cohesion',
          description: 'Stay together.',
          value: _cohOn,
          onChanged: (v) {
            setState(() {
              _cohOn = v;
              _e.cohesionEnabled = v;
            });
          },
        ),
        const SizedBox(height: 12),
        _SectionTitle(title: 'Tuning', dense: dense),
        const SizedBox(height: 10),
        _LabeledSlider(
          dense: dense,
          label: 'Boids',
          valueLabel: _boids.toString(),
          value: _boids.toDouble(),
          min: 50,
          max: _e.capacity.toDouble(),
          divisions: ((_e.capacity - 50) / 10).round(),
          onChanged: (v) {
            final int next = v.round().clamp(50, _e.capacity);
            setState(() => _boids = next);
            _e.setBoidCount(next);
          },
        ),
        _LabeledSlider(
          dense: dense,
          label: 'Speed',
          valueLabel: _speed.toStringAsFixed(2),
          value: _speed,
          min: 0.06,
          max: 0.36,
          divisions: 30,
          onChanged: (v) {
            setState(() => _speed = v);
            _e.speed = v;
          },
        ),
        _LabeledSlider(
          dense: dense,
          label: 'Vision Radius',
          valueLabel: _perception.toStringAsFixed(3),
          value: _perception,
          min: 0.045,
          max: 0.22,
          divisions: 35,
          onChanged: (v) {
            setState(() {
              _perception = v;
              _separation = math.min(_separation, _perception);
            });
            _e.perceptionRadius = _perception;
            _e.separationRadius = _separation;
          },
        ),
        _LabeledSlider(
          dense: dense,
          label: 'Separation Radius',
          valueLabel: _separation.toStringAsFixed(3),
          value: _separation,
          min: 0.010,
          max: 0.070,
          divisions: 60,
          onChanged: (v) {
            final double next = math.min(v, _perception);
            setState(() => _separation = next);
            _e.separationRadius = next;
          },
        ),
        _LabeledSlider(
          dense: dense,
          label: 'Turn Rate',
          valueLabel: _turnRate.toStringAsFixed(1),
          value: _turnRate,
          min: 1.0,
          max: 14.0,
          divisions: 26,
          onChanged: (v) {
            setState(() => _turnRate = v);
            _e.maxTurnRate = v;
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'Visuals', dense: dense),
        const SizedBox(height: 10),
        _SwitchRow(
          dense: dense,
          title: 'Trails',
          subtitle: 'Subtle streaks behind boids.',
          value: _trails,
          onChanged: (v) {
            setState(() => _trails = v);
            _e.trailsEnabled = v;
          },
        ),
        _SwitchRow(
          dense: dense,
          title: 'Glow',
          subtitle: 'Additive sparkle.',
          value: _glow,
          onChanged: (v) {
            setState(() => _glow = v);
            _e.glowEnabled = v;
          },
        ),
        _SwitchRow(
          dense: dense,
          title: 'Inspect A Boid',
          subtitle: 'Click the canvas to visualize vision + space.',
          value: _vizSelected,
          onChanged: (v) {
            setState(() => _vizSelected = v);
            _e.setVisualizeSelected(v);
          },
        ),
        const SizedBox(height: 16),
        _AdvancedWeightsTile(
          dense: dense,
          wSep: _wSep,
          wAli: _wAli,
          wCoh: _wCoh,
          onSepChanged: (v) {
            setState(() => _wSep = v);
            _e.separationWeight = v;
          },
          onAliChanged: (v) {
            setState(() => _wAli = v);
            _e.alignmentWeight = v;
          },
          onCohChanged: (v) {
            setState(() => _wCoh = v);
            _e.cohesionWeight = v;
          },
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: 'How To Play', dense: dense),
        const SizedBox(height: 8),
        _HintRow(
          icon: Icons.touch_app,
          text: 'Drag on the scene to attract the flock.',
          dense: dense,
        ),
        _HintRow(
          icon: Icons.keyboard,
          text: 'Use Repel on mobile. On desktop, Shift also repels.',
          dense: dense,
        ),
        _HintRow(
          icon: Icons.mouse,
          text: 'Click to select a boid (when Inspect is on).',
          dense: dense,
        ),
        const SizedBox(height: 16),
        const _BoidsExplainer(),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.dense,
    required this.paused,
    required this.onPause,
    required this.onRandomize,
    required this.onReset,
  });

  final bool dense;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onRandomize;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Boids Playground',
          style: t.titleLarge!
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Complex flocking from three simple rules.',
          style: t.bodyMedium!
              .copyWith(color: Colors.white.withAlpha(166), height: 1.25),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPause,
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(paused ? 'Play' : 'Pause'),
            ),
            OutlinedButton.icon(
              onPressed: onRandomize,
              icon: const Icon(Icons.shuffle),
              label: const Text('Randomize'),
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        SizedBox(height: dense ? 10 : 14),
        const Divider(height: 1),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.dense});

  final String title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: Colors.white.withAlpha(168),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.dense,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final bool dense;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        Theme.of(context).textTheme.labelLarge!.copyWith(
      color: Colors.white.withAlpha(219),
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              Text(valueLabel,
                  style:
                      labelStyle.copyWith(color: Colors.white.withAlpha(158))),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RuleToggleRow extends StatelessWidget {
  const _RuleToggleRow({
    required this.dense,
    required this.labelStyle,
    required this.name,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final bool dense;
  final TextStyle labelStyle;
  final String name;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: labelStyle),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: Colors.white.withAlpha(143)),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.dense,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final bool dense;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: t.bodySmall!
                        .copyWith(color: Colors.white.withAlpha(148))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text, required this.dense});

  final IconData icon;
  final String text;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final double iconSize = dense ? 18 : 20;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 6),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: const Color(0xFF2EF2C7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withAlpha(184), height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragModeRow extends StatelessWidget {
  const _DragModeRow({
    required this.dense,
    required this.repel,
    required this.onChanged,
  });

  final bool dense;
  final bool repel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drag Mode',
          style: t.labelLarge!.copyWith(
            color: Colors.white.withAlpha(219),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: false, label: Text('Attract')),
            ButtonSegment<bool>(value: true, label: Text('Repel')),
          ],
          selected: {repel},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          'Works on touch devices. Desktop: hold Shift to repel temporarily.',
          style: t.bodySmall!.copyWith(color: Colors.white.withAlpha(148)),
        ),
      ],
    );
  }
}

class _AdvancedWeightsTile extends StatelessWidget {
  const _AdvancedWeightsTile({
    required this.dense,
    required this.wSep,
    required this.wAli,
    required this.wCoh,
    required this.onSepChanged,
    required this.onAliChanged,
    required this.onCohChanged,
  });

  final bool dense;
  final double wSep;
  final double wAli;
  final double wCoh;
  final ValueChanged<double> onSepChanged;
  final ValueChanged<double> onAliChanged;
  final ValueChanged<double> onCohChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x770B0F14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: Colors.white.withAlpha(200),
          collapsedIconColor: Colors.white.withAlpha(160),
          title: Text(
            'Advanced',
            style: t.titleSmall!.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Rule strengths (fine tuning)',
            style: t.bodySmall!.copyWith(color: Colors.white.withAlpha(148)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                'These are subtle. Try toggling rules first, then use strengths to refine the feel.',
                style:
                    t.bodySmall!.copyWith(color: Colors.white.withAlpha(148)),
              ),
            ),
            _LabeledSlider(
              dense: dense,
              label: 'Separation Strength',
              valueLabel: wSep.toStringAsFixed(2),
              value: wSep,
              min: 0.0,
              max: 3.5,
              divisions: 70,
              onChanged: onSepChanged,
            ),
            _LabeledSlider(
              dense: dense,
              label: 'Alignment Strength',
              valueLabel: wAli.toStringAsFixed(2),
              value: wAli,
              min: 0.0,
              max: 3.5,
              divisions: 70,
              onChanged: onAliChanged,
            ),
            _LabeledSlider(
              dense: dense,
              label: 'Cohesion Strength',
              valueLabel: wCoh.toStringAsFixed(2),
              value: wCoh,
              min: 0.0,
              max: 3.5,
              divisions: 70,
              onChanged: onCohChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _BoidsExplainer extends StatelessWidget {
  const _BoidsExplainer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x990B0F14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What are boids?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Boids are a classic demo of emergent behavior: each agent follows a few local rules, '
              'and the group appears to flock without any leader.',
              style: TextStyle(color: Color(0xFFBFC7D5), height: 1.25),
            ),
            SizedBox(height: 10),
            Text(
              'Try turning off Alignment or Cohesion and watch the flock fall apart.',
              style: TextStyle(color: Color(0xFFA0A9BA), height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
