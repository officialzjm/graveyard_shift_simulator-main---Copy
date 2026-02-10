import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'dart:math';
//Speed and Velocity Variables
//Inches per second , we will standarize to meters later
const double maxVelocity = 70;
const double maxAccel = 200; // im not sure what this should be
const double fieldHalf = 72.6;

const wpRadius = 2.0;
const handleRadius = 1.5;
const pathRadius = 1;

const double trackWidth = 12;

extension OffsetToVector2 on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}
num clamp(num x, num minVal, num maxVal) {
  return max(minVal, min(x, maxVal));
}
double fmod(double a, double b) {
  return a - b * (a / b).floor();
}
extension Vector2Norm on Vector2 {
  double squaredNorm() => x * x + y * y;
}
