# Boids Playground (Flutter Web)

An interactive boids tech demo: flocking emerges from three simple local rules.

## Run

```sh
flutter run -d chrome
```

Tips:
- Drag on the scene to attract the flock.
- Hold Shift while dragging to repel.
- Toggle rules to see how each one changes the group.

## Build (GitHub Pages)

```sh
flutter build web --release
```

After building, copy the contents of `build/web/` into `docs/`.

Live URL: https://aidandavis.github.io/flutter_boids/#/
