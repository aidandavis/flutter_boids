import 'dart:math';

/// Return a list of segments that make up a clock of the curent time.
/// optionally, return the segments for the given time.
List<Line> getClockSegments(
  DateTime dateTime, {
  double lengthX = 0.8,
  double lengthY = 1 / 3,
  double distBetween = 0.08,
}) {
  final segments = <Line>[];

  final startX = (1 - lengthX) / 2;
  final startY = (1 - lengthY) / 2;

  final segmentWidth = (lengthX - (distBetween * 3.5)) / 4;

  // hours
  segments.addAll(ClockSegment(dateTime.hour ~/ 10).scale(
    startX,
    startY,
    segmentWidth * 2,
    lengthY,
  ));
  segments.addAll(ClockSegment(dateTime.hour % 10).scale(
    startX + segmentWidth + distBetween,
    startY,
    segmentWidth * 2,
    lengthY,
  ));

  // minutes
  segments.addAll(ClockSegment(dateTime.minute ~/ 10).scale(
    startX + (segmentWidth * 2) + (distBetween * 2.5),
    startY,
    segmentWidth * 2,
    lengthY,
  ));
  segments.addAll(ClockSegment(dateTime.minute % 10).scale(
    startX + (segmentWidth * 3) + (distBetween * 3.5),
    startY,
    segmentWidth * 2,
    lengthY,
  ));

  return segments;
}

/// A list of lines that correspond to a single digit on a 7-segment display.
/// All values between 0 and 1 so that height is 1 and width is 0.5 .
/// ![](https://media.geeksforgeeks.org/wp-content/uploads/20200413202916/Untitled-Diagram-237.png)
class ClockSegment {
  int _number;

  ClockSegment(this._number);

  List<Line> get segment => _createSegment();

  List<Line> _createSegment() {
    switch (_number) {
      case 0:
        return [a, b, c, d, e, f];
      case 1:
        return [b, c];
      case 2:
        return [a, b, d, e, g];
      case 3:
        return [a, b, c, d, g];
      case 4:
        return [b, c, f, g];
      case 5:
        return [a, c, d, f, g];
      case 6:
        return [a, c, d, e, f, g];
      case 7:
        return [a, b, c];
      case 8:
        return [a, b, c, d, e, f, g];
      case 9:
        return [a, b, c, d, f, g];
      default:
        return <Line>[];
    }
  }

  List<Line> scale(
    double startX,
    double startY,
    double lengthX,
    double lengthY,
  ) {
    final scaledSegment = <Line>[];

    for (final line in segment) {
      final p1Scaled =
          Point((startX + line.p1.x * lengthX), (startY + line.p1.y * lengthY));
      final p2Scaled =
          Point((startX + line.p2.x * lengthX), (startY + line.p2.y * lengthY));

      scaledSegment.add(Line(p1Scaled, p2Scaled));
    }

    return scaledSegment;
  }

  static const a = Line(Point(0, 0), Point(0.5, 0));
  static const b = Line(Point(0.5, 0), Point(0.5, 0.5));
  static const c = Line(Point(0.5, 0.5), Point(0.5, 1));
  static const d = Line(Point(0, 1), Point(0.5, 1));
  static const e = Line(Point(0, 0.5), Point(0, 1));
  static const f = Line(Point(0, 0), Point(0, 0.5));
  static const g = Line(Point(0, 0.5), Point(0.5, 0.5));
}

class Line {
  final Point<double> p1;
  final Point<double> p2;

  const Line(this.p1, this.p2);
}
