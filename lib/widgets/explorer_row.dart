import 'package:flutter/material.dart';
import 'package:graveyard_shift_simulator/constants.dart';
import 'package:provider/provider.dart';
import 'package:graveyard_shift_simulator/models/path_structure.dart';
import 'dart:async';
class WaypointRow extends StatefulWidget {
  final int index;
  final List<({int globalIndex, Command command})> wpCommands;
  const WaypointRow({super.key, required this.index, required this.wpCommands});

  @override
  State<WaypointRow> createState() => _WaypointRowState();
}

class _WaypointRowState extends State<WaypointRow> {
  Timer? _velocityDebounce;
  Timer? _accelDebounce;

  @override
  void dispose() {
    _velocityDebounce?.cancel();
    _accelDebounce?.cancel();
    super.dispose();
  }

  void _debounceVelocity(double value) {
    _velocityDebounce?.cancel();
    _velocityDebounce = Timer(const Duration(milliseconds: 250), () {
      final path = Provider.of<PathModel>(context, listen: false);
      path.setVelocity(widget.index, value);
    });
  }

  void _debounceAccel(double value) {
    _accelDebounce?.cancel();
    _accelDebounce = Timer(const Duration(milliseconds: 250), () {
      final path = Provider.of<PathModel>(context, listen: false);
      path.setAccel(widget.index, value);
   });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PathModel>(
      builder: (context, pathModel, child) {
        final waypoint = pathModel.waypoints[widget.index];
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => pathModel.setVisibility(widget.index, !waypoint.visible),
                    icon: Icon(
                      waypoint.visible
                          ? Icons.remove_red_eye
                          : Icons.remove_red_eye_outlined,
                    ),
                    color: Colors.lightBlueAccent,
                    iconSize: 28,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: Colors.redAccent,
                    onPressed: () => pathModel.removeWaypoint(widget.index),
                    iconSize: 28,
                  ),
                  IconButton(
                    icon: Icon(
                      waypoint.reversed 
                          ? Icons.arrow_back 
                          : Icons.arrow_forward
                    ),
                    color: Colors.purpleAccent,
                    onPressed: () => pathModel.setReversed(widget.index, !waypoint.reversed),
                    iconSize: 28,
                  ),
                  Expanded(
                    child: Slider(
                      value: waypoint.velocity,
                      onChanged: _debounceVelocity,  // Throttled updates
                      min: 0,
                      max: maxVelocity,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: waypoint.accel,
                      onChanged: _debounceAccel,    // Throttled updates
                      min: 0,
                      max: maxAccel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Waypoint ${widget.index}', 
                        style: const TextStyle(color: Colors.white70))
                  ),
                  Consumer<CommandList>(
                    builder: (context, commandList, child) {
                      return IconButton(
                        onPressed: () => commandList.addCommand(
                          Command(t: 1.0, waypointIndex: widget.index, name: CommandName.intake),
                        ),
                        icon: const Icon(Icons.add_circle),
                        iconSize: 30,
                        color: Colors.pink,
                      );
                    },
                  ),
                ],
              ),
              ...widget.wpCommands.map((entry) => CommandRow(
                globalIndex: entry.globalIndex,
                command: entry.command,
              )),
            ],
          ),
        );
      },
    );
  }
}

class CommandRow extends StatelessWidget {
  final int globalIndex;
  final Command command;

  const CommandRow({
    super.key,
    required this.globalIndex,
    required this.command,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CommandList>(
      builder: (context, commandList, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: IconButton(
                  icon: Icon(Icons.delete),
                  color: Colors.redAccent,
                  onPressed: () =>
                      commandList.removeCommand(globalIndex),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 8,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Distance along the path',
                    hintText: '0 < tau < 1',
                  ),
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: true),
                  maxLength: 7,
                  onChanged: (v) {
                    final t = double.tryParse(v);
                    if (t != null) {
                      commandList.changeCmdT(globalIndex, t);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 20,
                child: DropdownButton<CommandName>(
                  value: command.name,
                  isExpanded: true,
                  onChanged: (newName) {
                    if (newName != null) {
                      commandList.modifyCommand(
                        globalIndex,
                        Command(
                          t: command.t,
                          waypointIndex: command.waypointIndex,
                          name: newName,
                        ),
                      );
                    }
                  },
                  items: CommandName.values.map((cmd) {
                    return DropdownMenuItem(
                      value: cmd,
                      child: Text(cmd.name),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
