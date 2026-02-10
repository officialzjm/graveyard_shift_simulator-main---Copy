import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import 'package:graveyard_shift_simulator/models/path_structure.dart';
import 'package:graveyard_shift_simulator/widgets/explorer_row.dart';
import 'package:graveyard_shift_simulator/widgets/field.dart';
import 'package:graveyard_shift_simulator/jsonconversion.dart';



class PlannerScreen extends StatefulWidget { //main UI
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  double tValue = 0.0; // 0..1 for robot preview
  double speedMin = 0.0;
  double speedMax = 200.0;

  bool displayWaypoints = true;

  @override
  Widget build(BuildContext context) {
    final pathModel = context.watch<PathModel>();
    final commandList = context.watch<CommandList>();
    final commands = commandList.commands; // <-- typed list
    return Scaffold(
      body: Column(
        children: [
          Container( //top toolbar
            height: 40,
            color: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Planner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    String jsonPath = createPathJson(pathModel.waypoints, commandList.commands);
                    downloadJsonWeb(jsonPath, 'Path1');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.upload_file),
                  onPressed: () async {
                    final input = html.FileUploadInputElement();
                    input.accept = '.json';
                    input.click();

                    input.onChange.listen((event) {
                      final file = input.files?.first;
                      if (file == null) return;
                      final reader = html.FileReader();

                      reader.onLoadEnd.listen((e) {
                        final jsonString = reader.result as String;
                        try {
                          final result = importPathJson(jsonString);

                          context.read<PathModel>().setPath(result); //not optimal to place it here so i will move it later
                          context.read<CommandList>().setCommands(result.commands);
                          //commandList.setCommands(result.commands);
                        } catch (err) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to load path: $err"),
                            ),
                          );
                        }
                     });
                     reader.readAsText(file);
                   });
                  },
                )
              ],
            ),
          ),
          Expanded( // Outer Expanded for field+sidebar
  child: Row(
    
    children: [
      const SizedBox(width: 12), // 👈 THIS is the missing piece
      // Field - fixed
      Expanded(child:
      Column(
        children:[ 
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 200, //500x900
            minHeight: 200,
            maxHeight: 550,
            maxWidth: 550,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: FieldView(tValue: tValue),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Robot Path Visualizer', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('Duration: ${pathModel.getDuration()}', style: TextStyle(fontWeight: FontWeight.bold) ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => setState(() => tValue = 0.0),
                      child: const Text('Reset t'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => tValue = 1.0),
                      child: const Text('End t'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('t = '),
                    Expanded(
                      child: Slider(
                        value: tValue,
                        onChanged: (v) => setState(() => tValue = v),
                        min: 0,
                        max: 1,
                      ),
                    ),
                    Text(tValue.toStringAsFixed(2)),
                  ],
                ),
              ],
            ),
          ),
        )],
      ),),
      const SizedBox(width: 12),
      Expanded( 
        child: Container(
          color: Colors.grey.shade800,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1, 
                    child: ElevatedButton(
                      onPressed:() {
                        setState(() {
                          displayWaypoints = true;
                        });
                      },
                      child: const Text('Waypoints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 1, 
                    child: ElevatedButton(
                      onPressed:() {
                        setState(() {
                          displayWaypoints = false;
                        });
                      },
                      child: const Text('Commands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if(displayWaypoints)
                    const Text('Waypoints Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if(!displayWaypoints)
                    const Text('Commands Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              
              
              if (displayWaypoints) 
                Expanded(
                  child: ListView.builder(
                    itemCount: pathModel.waypoints.length,
                    itemBuilder: (context, index) {
                      final wpCommands = <({int globalIndex, Command command})>[];

                      for (int i = 0; i < commands.length; i++) {
                        if (commands[i].waypointIndex == index) {
                          wpCommands.add((globalIndex: i, command: commands[i]));
                        }
                      }

                      return WaypointRow(index: index, wpCommands: wpCommands);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              /*
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Robot Path Visualizer', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('t = '),
                        Expanded(
                          child: Slider(
                            value: tValue,
                            onChanged: (v) => setState(() => tValue = v),
                            min: 0,
                            max: 1,
                          ),
                        ),
                        Text(tValue.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => tValue = 0.0),
                          child: const Text('Reset t'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => setState(() => tValue = 1.0),
                          child: const Text('End t'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              */
              const SizedBox(height: 8),

            ],
          ),
        ),
      ),
    ],
  ),
),

          // Bottom toolbar
          /*
          SizedBox(
            height: 160,
            child: Material(
              elevation: 4,
              color: Colors.grey.shade800,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Robot Path Visualizer panel
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Robot Path Visualizer (t)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('t = '),
                                Expanded(
                                  child: Slider(
                                    value: tValue,
                                    onChanged: (v) => setState(() => tValue = v),
                                    min: 0,
                                    max: 1,
                                  ),
                                ),
                                Text(tValue.toStringAsFixed(2)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => setState(() => tValue = 0.0),
                                  child: const Text('Reset t'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => setState(() => tValue = 1.0),
                                  child: const Text('End t'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Speed profile panel
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Speed Profile (min/max)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('min'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '0',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  onChanged: (v) => setState(() => speedMin = double.tryParse(v) ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('max'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '200',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                  onChanged: (v) => setState(() => speedMax = double.tryParse(v) ?? 200.0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: Center(child: Text('Speed graph preview (future)', style: TextStyle(color: Colors.white70)))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),*/
        ],
      ),
    );
  }
}
