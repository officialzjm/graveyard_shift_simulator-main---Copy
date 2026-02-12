import 'package:flutter/material.dart';
import 'package:graveyard_shift_simulator/constants.dart';
import 'package:graveyard_shift_simulator/models/path_structure.dart';

Offset cubicPoint(//
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  final u = 1 - t;
  return p0 * (u * u * u) +
      p1 * (3 * u * u * t) +
      p2 * (3 * u * t * t) +
      p3 * (t * t * t);
}

Offset cubicDerivative(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  final u = 1 - t;
  return (p1 - p0) * (3 * u * u) +
         (p2 - p1) * (6 * u * t) +
         (p3 - p2) * (3 * t * t);
}

Color velocityToColor(double v) {
  final t = ((v - 0) / (maxVelocity - 0)).clamp(0.0, 1.0); //min veloc: 0
  return Color.lerp(Colors.red, Colors.green, t)!;
}

double segmentLength(Waypoint a, Waypoint b, {int samples = 50}) {
  final p0 = a.pos;
  final p1 = a.handleOut ?? p0;
  final p2 = b.handleIn ?? b.pos;
  final p3 = b.pos;

  
  double length = 0.0;
  Offset prev = p0;

  for (int i = 1; i <= samples; i++) {
    final t = i / samples;
    final curr = cubicPoint(p0, p1, p2, p3, t);
    length += (curr - prev).distance;
    prev = curr;
  }

  return length;
}

List<double> computeSegmentLengths(List<Waypoint> waypoints) {
  final lengths = <double>[];
  for (int i = 0; i < waypoints.length - 1; i++) {
    lengths.add(segmentLength(waypoints[i], waypoints[i+1]));
  }
  return lengths;
}
List<double> cumulativeDistances(List<double> lengths) {
  final cum = <double>[0.0];
  for (final l in lengths) {
    cum.add(cum.last + l);
  }
  return cum;
}
int samplesPerSegment = 20;

Offset? positionAtTauNormalizedByDistance(List<Waypoint> waypoints, double tau) {
  if (waypoints.length < 2) return null;
  
  tau = tau.clamp(0.0, 1.0);
  
  final segmentLengths = <double>[];
  double totalLength = 0.0;

  for (int i = 0; i < waypoints.length - 1; i++) {
    final w0 = waypoints[i];
    final w1 = waypoints[i + 1];
    final length = segmentLength(w0, w1);

    segmentLengths.add(length);
    totalLength += length;
  }

  if (totalLength <= 0) return waypoints.first.pos;

  double targetDist = tau * totalLength;


  for (int i = 0; i < segmentLengths.length; i++) {
    final segLen = segmentLengths[i];

    if (targetDist <= segLen) {
      final w0 = waypoints[i];
      final w1 = waypoints[i + 1];

      final p0 = w0.pos;
      final p3 = w1.pos;
      final p1 = w0.handleOut ?? p0;
      final p2 = w1.handleIn ?? p3;

      double walked = 0.0;
      Offset prev = p0;

      for (int s = 1; s <= samplesPerSegment; s++) {
        final t = s / samplesPerSegment;
        final curr = cubicPoint(p0, p1, p2, p3, t);
        final d = (curr - prev).distance;

        if (walked + d >= targetDist) {
          final remaining = targetDist - walked;
          final ratio = remaining / d;
          return Offset.lerp(prev, curr, ratio)!;
        }
        
        walked += d;
        prev = curr;
      }
      return p3;
    }
    targetDist -= segLen;
  }
  return waypoints.last.pos;
}

double commandToGlobalT({
  required Command cmd,
  required List<Waypoint> waypoints,
  required List<double> segmentLengths,//change to calculate in the function
  required List<double> cumulative,
}) {
  final segIndex = cmd.waypointIndex;
  if (segIndex < 0 || segIndex >= segmentLengths.length) return 0.0;

  final localDist = cmd.t * segmentLengths[segIndex];
  final globalDist = cumulative[segIndex] + localDist;
  final totalDist = cumulative.last;

  return (totalDist == 0) ? 0.0 : globalDist / totalDist;
}
LocalCommandT globalTToLocalCommandT({
  required double globalT,
  required List<Waypoint> waypoints,
}) {
  final segmentLengths = computeSegmentLengths(waypoints);
  final cumulative = cumulativeDistances(segmentLengths);

  final totalLength = cumulative.last;
  final targetDistance = globalT * totalLength;

  int segmentIndex = 0;
  for (int i = 0; i < cumulative.length - 1; i++) {
    if (targetDistance >= cumulative[i] &&
        targetDistance <= cumulative[i + 1]) {
      segmentIndex = i;
      break;
    }
  }

  final segmentStart = cumulative[segmentIndex];
  final segmentLength = segmentLengths[segmentIndex];

  final localSegmentT =
      segmentLength == 0
          ? 0.0
          : (targetDistance - segmentStart) / segmentLength;
  return LocalCommandT(segmentIndex, localSegmentT.clamp(0.0,1.0));
}
