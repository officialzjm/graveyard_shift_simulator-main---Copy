import 'package:flutter/material.dart';
import 'package:graveyard_shift_simulator/models/path_structure.dart';
import 'package:graveyard_shift_simulator/bezierinfo.dart';
import 'dart:convert';
import 'dart:html' as html;



void downloadJsonWeb(String data, String filename) {
  final bytes = utf8.encode(data);

  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();

  html.Url.revokeObjectUrl(url);
}

String createPathJson(List<Waypoint> waypoints, List<Command> commands, [double startSpeed = 0.0, double endSpeed = 0.0]) {
  List<Segment> segments = createSegmentList(waypoints);
  final segmentLengths = computeSegmentLengths(waypoints);
  final cumulative = cumulativeDistances(segmentLengths);

  final exportedCommands = commands.map((cmd) {
    final globalTau = commandToGlobalT(
      cmd: cmd,
      waypoints: waypoints,
      segmentLengths: segmentLengths,
      cumulative: cumulative,
    );

    return {
      "t": globalTau.toPrecision(4),
      "name": cmd.name.name,
    };
  }).toList();

  Map<String, dynamic> root = {
    'start_speed': startSpeed,
    'end_speed': endSpeed,
    'segments': segments.map((s) => s.toJson()).toList(),
    'commands': exportedCommands,
  };

  return const JsonEncoder.withIndent('  ').convert(root);
}

List<Segment> createSegmentList(List<Waypoint> waypoints) {
  List<Segment> segments = [];
  for (int i = 0; i < waypoints.length-1; i++) {
    Waypoint wp = waypoints[i];
    Waypoint nextWp = waypoints[i+1];
    List<Offset> path = [];
    if (wp.handleOut != null && nextWp.handleIn != null) {
      path = [wp.pos,wp.handleOut!,nextWp.handleIn!,nextWp.pos];
    } else {
      path = [wp.pos,nextWp.pos];
    }
    segments.add(Segment(inverted: wp.reversed, stopEnd: false, path: path, velocity: (wp.velocity*0.0254).toPrecision(4), accel: (wp.accel*0.0254).toPrecision(4)));
  }
  return segments;
}

List<Command> importCommands(
  List<dynamic> jsonCommands,
  List<Waypoint> waypoints,
) {
  return jsonCommands.map((c) {
    final globalT = (c['t'] as num).toDouble();
    final localCmdT = globalTToLocalCommandT(globalT: globalT, waypoints: waypoints);
    return Command(
      name: commandNameFromString(c['name']),
      t: localCmdT.localT,
      waypointIndex: localCmdT.waypointIndex,
    );
  }).toList();
}
List<Waypoint> importWaypoints(List<dynamic> jsonSegments) {
  final List<Waypoint> waypoints = [];

  for (int i = 0; i < jsonSegments.length; i++) {
    final seg = jsonSegments[i];
    final path = seg['path'] as List;
    final inverted = seg['inverted'] as bool;
    final constraints = seg['constraints'];

    final velocity = (constraints['velocity'] as num).toDouble() / 0.0254;
    final accel = (constraints['accel'] as num).toDouble() / 0.0254;

    final start = Offset(
      (path.first['x'] as num).toDouble(),
      (path.first['y'] as num).toDouble(),
    );

    final end = Offset(
      (path.last['x'] as num).toDouble(),
      (path.last['y'] as num).toDouble(),
    );

    final isBezier = path.length == 4;

    Offset? handleOut;
    Offset? handleIn;

    if (isBezier) {
      handleOut = Offset(
        (path[1]['x'] as num).toDouble(),
        (path[1]['y'] as num).toDouble(),
      );
      handleIn = Offset(
        (path[2]['x'] as num).toDouble(),
        (path[2]['y'] as num).toDouble(),
      );
    }

    if (i == 0) {
      waypoints.add(
        Waypoint(
          pos: start,
          velocity: velocity,
          accel: accel,
          reversed: inverted,
        ),
      );
    }

    if (isBezier) {
      waypoints.last.handleOut = handleOut;
    }

    waypoints.add(
      Waypoint(
        pos: end,
        handleIn: handleIn,
        velocity: velocity,
        accel: accel,
        reversed: inverted,
      ),
    );
  }

  return waypoints;
}

PathImportResult importPathJson(String jsonString) {
  final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

  final segments = decoded['segments'] as List;
  final waypoints = importWaypoints(segments);

  final commands = importCommands(
    decoded['commands'] as List,
    waypoints,
  );

  return PathImportResult(
    waypoints: waypoints,
    commands: commands,
    startSpeed: (decoded['start_speed'] as num).toDouble(),
    endSpeed: (decoded['end_speed'] as num).toDouble(),
  );
}


