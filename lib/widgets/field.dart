import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:graveyard_shift_simulator/models/path_structure.dart';
import 'package:graveyard_shift_simulator/bezierinfo.dart';
import 'package:graveyard_shift_simulator/constants.dart';

bool paintVelocities = false;
class FieldView extends StatefulWidget {
  final double tValue;
  const FieldView({super.key, this.tValue = 0.0});

  @override
  State<FieldView> createState() => _FieldViewState();
}

class _FieldViewState extends State<FieldView> {
  DragTargetInfo? dragging;

  ui.Image? fieldImage; // Field background

  @override
  void initState() {
    super.initState();
    _loadFieldImage();
  }

  Future<void> _loadFieldImage() async {
    final data = await rootBundle.load('assets/images/V5PBF.png');
    final bytes = data.buffer.asUint8List();
    final img = await decodeImageFromList(bytes);
    setState(() => fieldImage = img);
  }

  Offset toScreen(Offset logical, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scaleX = size.width / (fieldHalf * 2);
    final scaleY = size.height / (fieldHalf * 2);
    final dynamicScale = min(scaleX, scaleY);
    return Offset(center.dx + (logical.dx * dynamicScale), center.dy - (logical.dy * dynamicScale));
  }

  Offset toLogical(Offset screen, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scaleX = size.width / (fieldHalf * 2);
    final scaleY = size.height / (fieldHalf * 2);
    final dynamicScale = min(scaleX, scaleY);
    return Offset((screen.dx - center.dx)/dynamicScale,(center.dy - screen.dy)/dynamicScale);
  }

  DragTargetInfo? _hitTest(Offset logical) {
    final waypoints = context.read<PathModel>().waypoints;
    for (int i = 0; i < waypoints.length; i++) {
      final s = waypoints[i];

      if ((s.pos - logical).distance <= handleRadius) {
        return DragTargetInfo(index: i, type: SegmentDragType.pos);
      }

      if (s.handleIn != null &&
          (s.handleIn! - logical).distance <= handleRadius) {
        return DragTargetInfo(index: i, type: SegmentDragType.handleIn);
      }

      if (s.handleOut != null &&
          (s.handleOut! - logical).distance <= handleRadius) {
        return DragTargetInfo(index: i, type: SegmentDragType.handleOut);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
      final pathModel = context.watch<PathModel>();
      final commands = context.watch<CommandList>().commands;
      final waypoints = pathModel.waypoints;
      return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          setState(() {
            dragging = _hitTest(toLogical(details.localPosition, size));
          });
        },
        onDoubleTapDown: (details) {
          var realClickPos = toLogical(details.localPosition, size);
          if (waypoints.isEmpty) {
            final secondWaypointPos = realClickPos + Offset(10,10);
            pathModel.addWaypoint(Waypoint(pos: realClickPos, handleOut: realClickPos + Offset(0,10)));
            pathModel.addWaypoint(Waypoint(pos: secondWaypointPos, handleIn: secondWaypointPos + Offset(0,10)));
          } else {
            final prevLast = waypoints[waypoints.length - 2];
            final last = waypoints.last;
            final newHandleOut = last.pos + computeHandleOffset(prevLast.pos, last.pos, distanceFormula(realClickPos, last.pos));
            final updatedLast = Waypoint(pos: last.pos, handleIn: last.handleIn, handleOut: newHandleOut, visible: last.visible, reversed: last.reversed);
            pathModel.updateWaypoint(waypoints.length - 1, updatedLast);
            pathModel.addWaypoint(Waypoint(pos: realClickPos, handleIn: realClickPos + computeHandleOffset(realClickPos, waypoints.last.pos)));
          }
        },
        onSecondaryTapDown: (details) {
          var realClickPos = toLogical(details.localPosition, size);

          bool wasEmpty = waypoints.isEmpty;
          pathModel.addWaypoint(Waypoint(pos: realClickPos));

          if (wasEmpty) {
            pathModel.addWaypoint(Waypoint(pos: realClickPos + Offset(10,10)));
          }
        },
        onPanStart: (details) {
          paintVelocities = false;
          final logical = toLogical(details.localPosition, size);
          dragging = _hitTest(logical);
        },
        onPanUpdate: (details) {
          if (dragging != null && waypoints[dragging!.index].visible == true) {
            final newLogical = toLogical(details.localPosition, size);
            final oldWaypoint = waypoints[dragging!.index];  // ✅ Capture OLD waypoint
            
            pathModel.updateWaypoint(dragging!.index, Waypoint(
              pos: dragging!.type == SegmentDragType.pos 
                ? newLogical 
                : oldWaypoint.pos,
              handleIn: dragging!.type == SegmentDragType.pos
                ? (oldWaypoint.handleIn ?? Offset.zero) + (newLogical - oldWaypoint.pos)
                : (dragging!.type == SegmentDragType.handleIn ? newLogical : oldWaypoint.handleIn),
              handleOut: dragging!.type == SegmentDragType.pos
                ? (oldWaypoint.handleOut ?? Offset.zero) + (newLogical - oldWaypoint.pos)
                : (dragging!.type == SegmentDragType.handleOut ? newLogical : oldWaypoint.handleOut),
              velocity: oldWaypoint.velocity,    // ✅ Preserve!
              accel: oldWaypoint.accel,         // ✅ Preserve!
              visible: oldWaypoint.visible,     // ✅ Preserve!
              reversed: oldWaypoint.reversed,
            ));
          }
        },

        onPanEnd: (details) {dragging = null; paintVelocities = true;},
        child: CustomPaint(
          size: size,
          painter: _FieldPainter(
            toScreen: (o) => toScreen(o, size),
            waypoints: waypoints,
            commands: commands,
            fieldImage: fieldImage,
            tValue: widget.tValue,
            pathModel: pathModel
          ),
        ),
      );
    });
  }
}

class _FieldPainter extends CustomPainter {
  final ui.Image? fieldImage;
  final List<Waypoint> waypoints;
  final List<Command> commands;
  final Offset Function(Offset) toScreen; 
  final double tValue;
  final PathModel pathModel;

  _FieldPainter({
    this.fieldImage,
    required this.waypoints,
    required this.commands,
    required this.toScreen,
    required this.tValue,
    required this.pathModel
  });


  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / (fieldHalf * 2);
    final scaleY = size.height / (fieldHalf * 2);
    final dynamicScale = min(scaleX, scaleY);

    // Draw field image
    if (fieldImage != null) {
      final center = Offset(size.width / 2, size.height / 2);
      final fieldLogicalSize = fieldHalf * 2;
      final destRect = Rect.fromCenter(
        center: center,
        width: fieldLogicalSize * dynamicScale,
        height: fieldLogicalSize * dynamicScale,
      );

      canvas.drawImageRect(
        fieldImage!,
        Rect.fromLTWH(0, 0, fieldImage!.width.toDouble(), fieldImage!.height.toDouble()),
        destRect,
        Paint(),
      );
    }
    final duration = pathModel.getDuration();
    final paintStraightLine = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 / dynamicScale;

    final paintBezierCurve = Paint()
      ..style = PaintingStyle.fill//x
      ..strokeWidth = 15 / dynamicScale
      ..color = Color.fromRGBO(0, 185, 0, 1);

    final paintWp = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.5 / dynamicScale;

    final paintHandle = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / dynamicScale;

    final commandPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..strokeWidth = 1 / dynamicScale;

    final wpWidth = wpRadius * dynamicScale;
    final handleWidth = handleRadius * dynamicScale; // 2 inches scaled

    for (int segmentIndex = 0; segmentIndex < pathModel.segments.length - 1; segmentIndex++) {
      //if visible check
      final wp1 = waypoints[segmentIndex];
      final wp2 = waypoints[segmentIndex + 1];
      final p1 = toScreen(wp1.pos);
      final p2 = toScreen(wp2.pos);
      final hOut = wp1.handleOut != null ? toScreen(wp1.handleOut!) : null;
      final hIn = wp2.handleIn != null ? toScreen(wp2.handleIn!) : null;

      // Velocity visualization (20 points total)
      double time = 0;
      while (time < duration) {
        time += 0.02;
          final pt = pathModel.getPointAtTime(time);
          paintBezierCurve.color = velocityToColor(pt.velocity);
          canvas.drawCircle(toScreen(pt.pos), pathRadius * dynamicScale, paintBezierCurve);
      }
    }

    
    for (int i = 0; i < waypoints.length - 1; i++) {
      if (waypoints[i].visible) {
        final waypoint1 = waypoints[i];
        final waypoint2 = waypoints[i+1];
        final waypoint1pos = toScreen(waypoint1.pos);
        final waypoint2pos = toScreen(waypoint2.pos);
        
        final control1pos = waypoint1.handleOut != null ? toScreen(waypoint1.handleOut!) : null;
        final control2pos = waypoint2.handleIn != null ? toScreen(waypoint2.handleIn!) : null;
       /*
        if (control1pos != null && control2pos != null) {
          int samplesPerSegment = 20;
          for (int s = 0; s < samplesPerSegment; s++) {
            final t0 = s / samplesPerSegment;
            final t1 = (s + 1) / samplesPerSegment;

            final pA = cubicPoint(waypoint1pos, control1pos, control2pos, waypoint2pos, t0);
            final pB = cubicPoint(waypoint1pos, control1pos, control2pos, waypoint2pos, t1);


            //canvas.drawLine(pA, pB, paintBezierCurve);
            canvas.drawLine(waypoint1pos, control1pos, paintHandle);
            canvas.drawLine(waypoint2pos, control2pos, paintHandle);
            canvas.drawCircle(control1pos, handleWidth, paintHandle);
            canvas.drawCircle(control2pos, handleWidth, paintHandle);
          }

        } else {
          canvas.drawLine(waypoint1pos, waypoint2pos, paintStraightLine);
        }
        */ 
        if (control1pos != null && control2pos != null) {

        canvas.drawLine(waypoint1pos, control1pos, paintHandle);
            canvas.drawLine(waypoint2pos, control2pos, paintHandle);
            canvas.drawCircle(control1pos, handleWidth, paintHandle);
            canvas.drawCircle(control2pos, handleWidth, paintHandle);}
        canvas.drawCircle(waypoint1pos, wpWidth, paintWp);
        canvas.drawCircle(waypoint2pos, wpWidth, paintWp);
      }
    }
    for (int i = 0; i < commands.length; i++) {
      //int waypointIndex = commands[i].waypointIndex;
      //if (waypointIndex < waypoints.length - 1) {
        Offset commandPos = pathModel.getPointAtTime(commands[i].t).pos;
        canvas.drawCircle(toScreen(commandPos), handleWidth, commandPaint);
      //}
    }
    
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => true;
}
