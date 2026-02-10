import 'package:vector_math/vector_math.dart';
import 'package:graveyard_shift_simulator/constants.dart';
import 'dart:math' as math;
double hypot(double a, double b) => math.sqrt(a * a + b * b);
class BezierSegment {
    Vector2 p0, p1, p2, p3;
    double maxVel, maxAccel;
    bool reversed = false;
    BezierSegment(this.p0, this.p1, this.p2, this.p3, this.maxVel, this.maxAccel, this.reversed);


    Vector3 poseAtT(double t) {
        double u = 1.0 - t;
        double tt = t * t;
        double uu = u * u;
        double uuu = uu * u;
        double ttt = tt * t;

        double x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x;
        double y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y;

        double dx = 3 * uu * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * tt * (p3.x - p2.x);
        double dy = 3 * uu * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * tt * (p3.y - p2.y);
        double theta = math.atan2(dy, dx);

        return Vector3(x, y, theta);
    }

    Vector2 derivative(double t) {
        double u = 1.0 - t;
        double tt = t * t;
        double uu = u * u;

        double dx = 3 * uu * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * tt * (p3.x - p2.x);
        double dy = 3 * uu * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * tt * (p3.y - p2.y);
        return Vector2(dx, dy);
    }

    Vector2 secondDerivative(double t) {
        double u = 1.0 - t;
        double tt = t * t;

        double dx = 6 * u * (p2.x - 2 * p1.x + p0.x) + 6 * tt * (p3.x - 2 * p2.x + p1.x);
        double dy = 6 * u * (p2.y - 2 * p1.y + p0.y) + 6 * tt * (p3.y - 2 * p2.y + p1.y);
        return Vector2(dx, dy);
    }

    double curvature(double t) {
        Vector2 v1 = derivative(t);
        Vector2 v2 = secondDerivative(t);
        double num = (v1.x * v2.y - v1.y * v2.x).abs();
        double den = math.pow(v1.squaredNorm(), 1.5).toDouble();
        return den > 1e-6 ? num / den : 0.0;
    }

    double totalArcLength() {
        return arcLengthAtT(1.0);
    }

    double arcLengthAtT(double t) {
        const int samplingRate = 50;
        double length = 0.0;
        double prevX = p0.x, prevY = p0.y;
        
        for (int i = 1; i <= samplingRate; ++i) {
            double u = t * i / samplingRate;
            Vector3 pos = poseAtT(u);
            length += hypot(pos.x - prevX, pos.y - prevY);
            prevX = pos.x; prevY = pos.y;
        }
        return length;
    }
}