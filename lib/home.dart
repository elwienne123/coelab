import 'package:coelab/run.dart';
import 'package:flutter/material.dart';
import 'package:coelab/component.dart';
import 'package:coelab/painter.dart';
import 'package:coelab/connection.dart';
import 'package:coelab/history.dart';
import 'package:coelab/history_manager.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final HistoryManager historyManager = HistoryManager();
  CircuitSnapshot captureCurrentState() {
    return CircuitSnapshot.capture(objectsNotifier.value, nodesNotifier.value);
  }

  Widget _buildComponentButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),

        child: Container(
          height: 42,

          padding: const EdgeInsets.symmetric(horizontal: 12),

          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 40, 40, 40),

            borderRadius: BorderRadius.circular(10),

            border: Border.all(color: Colors.white12),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 19,
                color: const Color.fromARGB(255, 120, 175, 225),
              ),

              const SizedBox(width: 8),

              Text(
                label,
                style: const TextStyle(
                  color: Color.fromARGB(255, 200, 200, 200),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void undo() {
    final currentState = captureCurrentState();

    final previousState = historyManager.undo(currentState);

    if (previousState == null) {
      return;
    }

    final restored = previousState.restore();

    objectsNotifier.value = restored.objects;
    nodesNotifier.value = restored.nodes;

    selectedObject = null;
    selectedNode = null;
    selectedSegment = null;

    connectionStartObject = null;
    connectionStartTerminal = null;
    connectionDragPosition = null;

    isConnecting.value = false;
    valueListenable.value = true;

    objectsNotifier.value = List.from(objectsNotifier.value);

    nodesNotifier.value = List.from(nodesNotifier.value);
  }

  void redo() {
    final currentState = captureCurrentState();

    final nextState = historyManager.redo(currentState);

    if (nextState == null) {
      return;
    }

    final restored = nextState.restore();

    objectsNotifier.value = restored.objects;
    nodesNotifier.value = restored.nodes;

    selectedObject = null;
    selectedNode = null;
    selectedSegment = null;

    connectionStartObject = null;
    connectionStartTerminal = null;
    connectionDragPosition = null;

    isConnecting.value = false;
    valueListenable.value = true;

    objectsNotifier.value = List.from(objectsNotifier.value);

    nodesNotifier.value = List.from(nodesNotifier.value);
  }
  // ============================================================
  // CONTROLLERS
  // ============================================================

  late AnimationController rotationController;

  final TransformationController transformationController =
      TransformationController();

  final TextEditingController editValueController = TextEditingController();

  // ============================================================
  // NOTIFIERS
  // ============================================================

  final ValueNotifier<bool> isRotating = ValueNotifier<bool>(false);

  final ValueNotifier<bool> isConnecting = ValueNotifier<bool>(false);

  final ValueNotifier<bool> valueListenable = ValueNotifier<bool>(true);

  final ValueNotifier<bool> showEditPanel = ValueNotifier<bool>(false);

  final ValueNotifier<List<Component>> objectsNotifier =
      ValueNotifier<List<Component>>([]);

  final ValueNotifier<List<ConnectionNode>> nodesNotifier =
      ValueNotifier<List<ConnectionNode>>([]);

  // ============================================================
  // SELECTION
  // ============================================================

  Component? selectedObject;

  ConnectionNode? selectedNode;

  // NEW:
  // Exact wire segment currently selected.
  WireSegment? selectedSegment;

  // ============================================================
  // CONNECTION DRAG STATE
  // ============================================================

  Component? connectionStartObject;

  int? connectionStartTerminal;

  Offset? connectionDragPosition;

  // ============================================================
  // COMPONENT DRAG STATE
  // ============================================================

  Offset? lastPointerPosition;
  bool hasMovedSelectedObject = false;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const double gridSize = 25.0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Initial empty circuit state
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    editValueController.dispose();
    transformationController.dispose();

    rotationController.dispose();

    isRotating.dispose();
    isConnecting.dispose();
    valueListenable.dispose();
    showEditPanel.dispose();

    objectsNotifier.dispose();
    nodesNotifier.dispose();

    super.dispose();
  }

  // ============================================================
  // FIND TERMINAL
  // ============================================================

  ({Component object, int terminal})? findTerminal(Offset position) {
    for (final object in objectsNotifier.value.reversed) {
      final terminal = object.getTerminalAt(position);

      if (terminal != null) {
        return (object: object, terminal: terminal);
      }
    }

    return null;
  }

  // ============================================================
  // DISTANCE TO LINE SEGMENT
  // ============================================================

  double distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;

    final pointVector = point - start;

    final segmentLengthSquared =
        segment.dx * segment.dx + segment.dy * segment.dy;

    if (segmentLengthSquared == 0) {
      return (point - start).distance;
    }

    final t =
        ((pointVector.dx * segment.dx) + (pointVector.dy * segment.dy)) /
        segmentLengthSquared;

    final clampedT = t.clamp(0.0, 1.0);

    final closestPoint = Offset(
      start.dx + segment.dx * clampedT,
      start.dy + segment.dy * clampedT,
    );

    return (point - closestPoint).distance;
  }

  // ============================================================
  // GET POSITION ON SEGMENT
  // ============================================================

  double getPositionOnSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;

    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;

    if (lengthSquared == 0) {
      return 0.0;
    }

    final pointVector = point - start;

    final t =
        ((pointVector.dx * segment.dx) + (pointVector.dy * segment.dy)) /
        lengthSquared;

    return t.clamp(0.0, 1.0);
  }

  // ============================================================
  // FIND WIRE AT POSITION
  // ============================================================

  ({
    ConnectionNode node,
    WireSegment segment,
    double position,
    WireLeg wireLeg,
  })?
  findWireAtPosition(Offset position) {
    const double hitTolerance = 25.0;

    for (final node in nodesNotifier.value.reversed) {
      for (final segment in node.segments) {
        final start = segment.start.getPosition();
        final end = segment.end.getPosition();

        // ========================================================
        // HORIZONTAL PART
        // ========================================================

        final horizontalEnd = Offset(end.dx, start.dy);

        final horizontalDistance = distanceToSegment(
          position,
          start,
          horizontalEnd,
        );

        if (horizontalDistance <= hitTolerance) {
          final segmentPosition = getPositionOnSegment(
            position,
            start,
            horizontalEnd,
          );

          return (
            node: node,
            segment: segment,
            position: segmentPosition,
            wireLeg: WireLeg.horizontal,
          );
        }

        // ========================================================
        // VERTICAL PART
        // ========================================================

        final verticalStart = Offset(end.dx, start.dy);

        final verticalDistance = distanceToSegment(
          position,
          verticalStart,
          end,
        );

        if (verticalDistance <= hitTolerance) {
          final segmentPosition = getPositionOnSegment(
            position,
            verticalStart,
            end,
          );

          return (
            node: node,
            segment: segment,
            position: segmentPosition,
            wireLeg: WireLeg.vertical,
          );
        }
      }
    }

    return null;
  }

  // ============================================================
  // FIND NODE AT WIRE
  // ============================================================

  ConnectionNode? findNodeAtWire(Offset position) {
    final result = findWireAtPosition(position);

    return result?.node;
  }

  void printNodeState(String message) {
    print('');
    print('================ NODE DEBUG ================');
    print(message);
    print('Total nodes: ${nodesNotifier.value.length}');

    for (int i = 0; i < nodesNotifier.value.length; i++) {
      final node = nodesNotifier.value[i];

      print('');
      print('NODE ${i + 1}');
      print('Terminals:');

      for (final terminal in node.terminals) {
        print('  ${terminal.object.name}-T${terminal.terminal}');
      }

      print('Segments: ${node.segments.length}');

      for (int j = 0; j < node.segments.length; j++) {
        final segment = node.segments[j];

        final start = segment.start;
        final end = segment.end;

        String describePoint(NodePoint point) {
          if (point.object != null && point.terminal != null) {
            return '${point.object!.name}-T${point.terminal}';
          }

          if (point.parentSegment != null && point.position != null) {
            return 'WIRE POINT @ ${point.position!.toStringAsFixed(2)}';
          }

          if (point.fixedPosition != null) {
            return 'FIXED ${point.fixedPosition}';
          }

          return 'UNKNOWN';
        }

        print(
          '  Segment ${j + 1}: '
          '${describePoint(start)} '
          '→ '
          '${describePoint(end)}',
        );
      }
    }

    print('============================================');
    print('');
  }

  // ============================================================
  // CONNECT TERMINAL TO EXISTING WIRE
  // ============================================================

  void connectTerminalToWire(
    Component object,
    int terminal,
    Offset wirePosition,
  ) {
    final result = findWireAtPosition(wirePosition);
    /**
     * print('');
    print('******** WIRE CONNECTION ********');
    print('Dragged terminal: ${object.name}-T$terminal');
     if (result != null) {
      print('Target node found.');
      print('Target segment found.');
      print(
        'Position on segment: '
        '${result.position.toStringAsFixed(3)}',
      );
    } else {
      print('NO TARGET WIRE FOUND');
    }
    print('********************************');
     */

   
    if (result == null) {
      return;
    }

    final targetNode = result.node;
    final targetSegment = result.segment;
    final position = result.position;
    /**
     * print(
      'ATTACHMENT: '
      '${result.wireLeg} '
      'position=${position.toStringAsFixed(3)}',
    );
     */
    // ============================================================
    // DON'T CONNECT A COMPONENT TO ITS OWN DIRECT WIRE
    // ============================================================

    if (targetSegment.start.object == object ||
        targetSegment.end.object == object) {
      return;
    }

    // ============================================================
    // FIND THE NODE THAT THE DRAGGED TERMINAL CURRENTLY BELONGS TO
    // ============================================================

    ConnectionNode? sourceNode;

    for (final node in nodesNotifier.value) {
      if (node.containsTerminal(object, terminal)) {
        sourceNode = node;
        break;
      }
    }

    // ============================================================
    // IF TERMINAL IS ALREADY PART OF THE TARGET NODE
    // ============================================================

    if (sourceNode == targetNode) {
     /**
      *  print('Terminal already belongs to this node.');
      */
      return;
    }
    historyManager.save(captureCurrentState());
    // ============================================================
    // CREATE A POINT ON THE TARGET WIRE
    // ============================================================

    final wirePoint = NodePoint.onWire(
      parentSegment: targetSegment,
      position: position,
      wireLeg: result.wireLeg,
    );

    // ============================================================
    // CREATE THE NEW BRANCH
    // ============================================================

    final branch = WireSegment(
      start: NodePoint.component(object: object, terminal: terminal),
      end: wirePoint,
    );

    // ============================================================
    // CASE 1:
    // TERMINAL IS NOT CONNECTED TO ANY NODE
    //
    // Just add it to the target node.
    // ============================================================

    if (sourceNode == null) {
      targetNode.addBranch(segment: branch, object: object, terminal: terminal);
      printNodeState('AFTER ADDING TERMINAL TO WIRE');
      
      nodesNotifier.value = [...nodesNotifier.value];
      
      
     /**
      *  print(
        'Added ${object.name}-T$terminal '
        'to existing wire/node.',
      );
      */

      return;
    }

    // ============================================================
    // CASE 2:
    // TERMINAL BELONGS TO ANOTHER NODE
    //
    // Merge the two electrical nodes.
    // ============================================================

    targetNode.addBranch(segment: branch, object: object, terminal: terminal);

    targetNode.mergeWith(sourceNode);
    /**
     * print('Merged source node into target node.');
     */

    printNodeState('AFTER MERGING NODES THROUGH WIRE');
    // Remove the old source node.
    nodesNotifier.value = nodesNotifier.value
        .where((node) => node != sourceNode)
        .toList();

    // Trigger repaint.
    nodesNotifier.value = [...nodesNotifier.value];

   /**
    *  print(
      'Merged electrical nodes through '
      '${object.name}-T$terminal.',
    );
    */
  }

  // ============================================================
  // CREATE CONNECTION
  // ============================================================

  void createConnection(
    Component startObject,
    int startTerminal,
    Component endObject,
    int endTerminal,
  ) {
    historyManager.save(captureCurrentState());
    // ============================================================
    // DON'T CONNECT COMPONENT TO ITSELF
    // ============================================================

    if (startObject == endObject) {
      return;
    }

    // ============================================================
    // FIND EXISTING NODES
    // ============================================================

    ConnectionNode? startNode;
    ConnectionNode? endNode;

    for (final node in nodesNotifier.value) {
      if (node.containsTerminal(startObject, startTerminal)) {
        startNode = node;
      }

      if (node.containsTerminal(endObject, endTerminal)) {
        endNode = node;
      }
    }

    // ============================================================
    // CASE 1
    //
    // NEITHER TERMINAL BELONGS TO A NODE
    //
    // Create a new electrical node.
    // ============================================================

    if (startNode == null && endNode == null) {
      final newNode = ConnectionNode(
        start: NodeTerminal(object: startObject, terminal: startTerminal),
        end: NodeTerminal(object: endObject, terminal: endTerminal),
      );

      Component wire= Component(x: 0, y: 0, type: 3);
      
      for(Component comp in objectsNotifier.value){
        if(comp.name==startObject.name){
          comp.compAtTerminal[startTerminal]=wire;
           wire.children.add(comp);
           break;
        }
       
      }
      for(Component comp in objectsNotifier.value){
        if(comp.name==endObject.name){
          comp.compAtTerminal[endTerminal]=wire;
          wire.children.add(comp);
           break;
        }
       
      }
     

      
      addObject(wire);
      newNode.wire=wire;
      nodesNotifier.value = [...nodesNotifier.value, newNode];
      printNodeState('AFTER CREATING NEW NODE');
      /**
       * print(
        'Created new node: '
        '${startObject.name}-T$startTerminal ↔ '
        '${endObject.name}-T$endTerminal',
      );

       */
      
      return;
    }

    // ============================================================
    // CASE 2
    //
    // BOTH TERMINALS ALREADY BELONG TO THE SAME NODE
    //
    // They are already electrically connected.
    // Don't create another wire.
    // ============================================================

    if (startNode != null && startNode == endNode) {
      /**
       * print('Already electrically connected.');
       */

      return;
    }

    // ============================================================
    // CASE 3
    //
    // START TERMINAL IS IN A NODE
    // END TERMINAL IS NOT.
    //
    // Add the end component to the same node
    // and create a wire between the terminals.
    // ============================================================

    if (startNode != null && endNode == null) {
      startNode.addTerminalConnection(
        startObject: startObject,
        startTerminal: startTerminal,
        endObject: endObject,
        endTerminal: endTerminal,
      );

      nodesNotifier.value = [...nodesNotifier.value];
      printNodeState('AFTER ADDING TERMINAL TO EXISTING NODE');
        /**
         * print(
          'Added ${endObject.name}-T$endTerminal '
          'to existing node.',
        );
         */

      return;
    }

    // ============================================================
    // CASE 4
    //
    // END TERMINAL IS IN A NODE
    // START TERMINAL IS NOT.
    // ============================================================

    if (startNode == null && endNode != null) {
      endNode.addTerminalConnection(
        startObject: startObject,
        startTerminal: startTerminal,
        endObject: endObject,
        endTerminal: endTerminal,
      );

      nodesNotifier.value = [...nodesNotifier.value];

      /**
       * print(
        'Added ${startObject.name}-T$startTerminal '
        'to existing node.',
      );
       */

      return;
    }

    // ============================================================
    // CASE 5
    //
    // BOTH TERMINALS BELONG TO DIFFERENT NODES.
    //
    // Connecting them merges the two electrical nodes.
    // ============================================================

    if (startNode != null && endNode != null && startNode != endNode) {
      // First create the new wire joining the two nodes.
      startNode.addTerminalConnection(
        startObject: startObject,
        startTerminal: startTerminal,
        endObject: endObject,
        endTerminal: endTerminal,
      );

      // Merge all terminals and wires
      // from the second node.
      startNode.mergeWith(endNode);

      // Remove the old second node.
      nodesNotifier.value = nodesNotifier.value
          .where((node) => node != endNode)
          .toList();

      // Trigger repaint.
      nodesNotifier.value = [...nodesNotifier.value];
      printNodeState('AFTER MERGING TWO NODES');
     /**
      *  print('');
      print('******** NODE MERGE ********');
      print(
        'START NODE terminals: '
        '${startNode.terminals.length}',
      );
      print(
        'END NODE terminals: '
        '${endNode.terminals.length}',
      );
      print('****************************');
      print('Merged two electrical nodes.');
      */
    }
  }

  // ============================================================
  // ADD COMPONENT
  // ============================================================

  void addObject(Component object) {
    // Save the circuit BEFORE making the change.
    historyManager.save(captureCurrentState());
    final position = getTopCenterOfCanvas();

    final snappedX = (position.dx / gridSize).round() * gridSize;

    final snappedY = (position.dy / gridSize).round() * gridSize;

    final newObject = Component(
      x: snappedX,
      y: snappedY,
      type: object.type,
      name: generateComponentName(object.type),
    );
    if(object.type==3){
      newObject.children.addAll(object.children);

    }
    objectsNotifier.value = [...objectsNotifier.value, newObject];
  }

  // ============================================================
  // GENERATE COMPONENT NAME
  // ============================================================

  String generateComponentName(int type) {
    String prefix;

    if (type == 0) {
      prefix = 'R';
    } else if (type == 1) {
      prefix = 'V';
    }else if(type==3){
      prefix='W';
    } else {
      prefix = 'I';
    }

    int number = 1;

    while (objectsNotifier.value.any(
      (object) => object.name == '$prefix$number',
    )) {
      number++;
    }

    return '$prefix$number';
  }

  // ============================================================
  // SELECT COMPONENT
  // ============================================================

  void selectObject(Offset position) {
    selectedObject = null;
    selectedSegment = null;
    selectedNode = null;

    showEditPanel.value = false;

    for (final object in objectsNotifier.value.reversed) {
      if (object.contains(position)) {
        selectedObject = object;

        valueListenable.value = false;

        break;
      }
    }

    if (selectedObject == null) {
      valueListenable.value = true;
    }
  }

  // ============================================================
  // SELECT WIRE SEGMENT
  // ============================================================

  void selectWireSegment(Offset position) {
    final result = findWireAtPosition(position);

    if (result == null) {
      selectedSegment = null;
      selectedNode = null;

      return;
    }

    selectedSegment = result.segment;

    selectedNode = result.node;

    selectedObject = null;

    showEditPanel.value = false;

    valueListenable.value = false;

   /**
    *  print('Selected wire segment');
    */
  }

  // ============================================================
  // DELETE SELECTED WIRE SEGMENT
  // ============================================================

  void deleteSelectedSegment() {
    if (selectedSegment == null) {
      return;
    }
    historyManager.save(captureCurrentState());
    final segmentToDelete = selectedSegment!;

    for (final node in nodesNotifier.value) {
      if (node.segments.contains(segmentToDelete)) {
        node.removeSegment(segmentToDelete);

        break;
      }
    }

    // Remove empty nodes.
    nodesNotifier.value = nodesNotifier.value
        .where((node) => node.segments.isNotEmpty)
        .toList();

    selectedSegment = null;
    selectedNode = null;

    valueListenable.value = true;

    nodesNotifier.value = [...nodesNotifier.value];

    /**
     * print('Deleted wire segment');
     */
  }

  // ============================================================
  // MOVE SELECTED COMPONENT
  // ============================================================

  void moveSelectedObject(Offset position) {
    if (selectedObject == null) {
      return;
    }

    if (lastPointerPosition == null) {
      lastPointerPosition = position;

      return;
    }

    final delta = position - lastPointerPosition!;

    double newX = selectedObject!.x + delta.dx;

    double newY = selectedObject!.y + delta.dy;

    const double canvasWidth = 900;
    const double canvasHeight = 1273;

    const double componentLength = 100;

    newX = newX.clamp(25.0, canvasWidth - componentLength - 25);

    newY = newY.clamp(75.0, canvasHeight - 75);

    selectedObject!.x = newX;
    selectedObject!.y = newY;

    lastPointerPosition = position;

    objectsNotifier.value = [...objectsNotifier.value];
  }

  // ============================================================
  // CHECK TERMINAL
  // ============================================================

  void checkTerminal(Offset position) {
    for (final object in objectsNotifier.value.reversed) {
      final terminal = object.getTerminalAt(position);

      if (terminal != null) {
        connectionStartObject = object;

        connectionStartTerminal = terminal;

        isConnecting.value = true;

        connectionDragPosition = object.getWorldTerminalPosition(terminal);

        /**
         * print(
          'Connection started: '
          '${object.name} - Terminal $terminal',
        );
         */

        return;
      }
    }
  }

  // ============================================================
  // DELETE SELECTED COMPONENT
  // ============================================================

  void deleteSelectedObject() {
    if (selectedObject == null) {
      return;
    }
    historyManager.save(captureCurrentState());
    final objectToDelete = selectedObject!;

    objectsNotifier.value = objectsNotifier.value
        .where((object) => object != objectToDelete)
        .toList();

    nodesNotifier.value = nodesNotifier.value
        .where((node) => !node.containsObject(objectToDelete))
        .toList();

    selectedObject = null;
    selectedSegment = null;
    selectedNode = null;

    showEditPanel.value = false;

    valueListenable.value = true;
  }

  // ============================================================
  // ROTATE COMPONENT
  // ============================================================

  void rotateSelectedObject() async {
    if (selectedObject == null || isRotating.value) {
      return;
    }
    historyManager.save(captureCurrentState());
    isRotating.value = true;

    final double startRotation = selectedObject!.rotation;

    final double endRotation = startRotation + (3.14159265359 / 2);

    final animation = Tween<double>(begin: startRotation, end: endRotation)
        .animate(
          CurvedAnimation(
            parent: rotationController,
            curve: Curves.easeOutCubic,
          ),
        );

    animation.addListener(() {
      if (selectedObject != null) {
        selectedObject!.rotation = animation.value;

        objectsNotifier.value = [...objectsNotifier.value];
      }
    });

    rotationController.reset();

    await rotationController.forward();

    isRotating.value = false;
  }

  // ============================================================
  // GET SNAPPED POSITION
  // ============================================================

  Offset getSnappedPosition(Component object) {
    return Offset(
      (object.x / gridSize).round() * gridSize,

      (object.y / gridSize).round() * gridSize,
    );
  }

  // ============================================================
  // GET TOP CENTER OF CANVAS
  // ============================================================

  Offset getTopCenterOfCanvas() {
    final screenSize = MediaQuery.of(context).size;

    final screenPoint = Offset((screenSize.width / 2) - 100 / 2, 100);

    final canvasPoint = transformationController.toScene(screenPoint);

    return canvasPoint;
  }

  // ============================================================
  // EDIT SELECTED COMPONENT
  // ============================================================

  void editSelectedObject() {
    if (selectedObject == null) {
      return;
    }

    final object = selectedObject!;

    if (object.type == 0) {
      editValueController.text = object.resistance.toString();
    } else if (object.type == 1) {
      editValueController.text = object.voltage.toString();
    } else {
      editValueController.text = object.current.toString();
    }

    showEditPanel.value = true;
  }

  // ============================================================
  // EDIT PANEL
  // ============================================================

  Widget _buildEditPanel() {
    if (selectedObject == null) {
      return const SizedBox();
    }

    final object = selectedObject!;

    String title;
    String label;
    String unit;

    if (object.type == 0) {
      title = 'Resistor';
      label = 'Resistance';
      unit = 'Ω';
    } else if (object.type == 1) {
      title = 'Voltage Source';
      label = 'Voltage';
      unit = 'V';
    } else {
      title = 'Current Source';
      label = 'Current';
      unit = 'A';
    }

    return Container(
      width: 280,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFF252525),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.white24),

        boxShadow: const [
          BoxShadow(blurRadius: 15, spreadRadius: 2, color: Colors.black54),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                'Edit $title',

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              IconButton(
                onPressed: () {
                  showEditPanel.value = false;
                },

                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            label,

            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: editValueController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),

                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),

                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Text(
                unit,

                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton(
              onPressed: () {
                final double? value = double.tryParse(editValueController.text);

                if (value == null) {
                  return;
                }
                historyManager.save(captureCurrentState());
                if (object.type == 0) {
                  object.resistance = value;
                } else if (object.type == 1) {
                  object.voltage = value;
                } else {
                  object.current = value;
                }

                objectsNotifier.value = [...objectsNotifier.value];

                showEditPanel.value = false;
              },

              child: const Text('SAVE'),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: const Border(
              bottom: BorderSide(color: Colors.white12, width: 1),
            ),
            color: const Color.fromARGB(255, 30, 30, 30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // =====================================================
              // COELAB TITLE
              // =====================================================
              const Text(
                'COELAB',
                style: TextStyle(
                  color: Color.fromARGB(255, 215, 215, 215),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const Spacer(),

              // =====================================================
              // UNDO / REDO GROUP
              // =====================================================
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 40, 40, 40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListenableBuilder(
                  listenable: historyManager,
                  builder: (context, child) {
                    return Row(
                      children: [
                        IconButton(
                          tooltip: 'Undo',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          onPressed: historyManager.canUndo ? undo : null,
                          icon: Icon(
                            Icons.undo_rounded,
                            size: 21,
                            color: historyManager.canUndo
                                ? const Color.fromARGB(255, 215, 215, 215)
                                : const Color.fromARGB(255, 90, 90, 90),
                          ),
                        ),

                        Container(width: 1, height: 22, color: Colors.white12),

                        IconButton(
                          tooltip: 'Redo',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          onPressed: historyManager.canRedo ? redo : null,
                          icon: Icon(
                            Icons.redo_rounded,
                            size: 21,
                            color: historyManager.canRedo
                                ? const Color.fromARGB(255, 215, 215, 215)
                                : const Color.fromARGB(255, 90, 90, 90),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(width: 10),

              // =====================================================
              // DIVIDER
              // =====================================================
              Container(width: 1, height: 28, color: Colors.white12),

              const SizedBox(width: 10),

              // =====================================================
              // RUN BUTTON
              // =====================================================
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 38, 48, 58),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color.fromARGB(255, 65, 105, 140),
                  ),
                ),
                child: IconButton(
                  tooltip: 'Run',
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Run run = new Run(
                      objectsNotifier.value,
                      nodesNotifier.value,
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  color: const Color.fromARGB(255, 120, 175, 225),
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // CANVAS
        // ======================================================
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: valueListenable,

            builder: (context, value, _) {
              return Stack(
                children: [
                  // ==================================================
                  // INTERACTIVE CANVAS
                  // ==================================================
                  ValueListenableBuilder(
                    valueListenable: isConnecting,

                    builder: (context, connecting, _) {
                      return InteractiveViewer(
                        constrained: false,

                        minScale: 0.5,

                        maxScale: 4.0,

                        scaleEnabled: value && !connecting,

                        panEnabled: value && !connecting,

                        transformationController: transformationController,

                        child: Container(
                          color: const Color.fromARGB(255, 30, 30, 30),

                          width: 900,

                          height: 1273,

                          child: Listener(
                            // ==================================================
                            // POINTER DOWN
                            // ==================================================
                            onPointerDown: (event) {
                              final scenePosition = event.localPosition;

                              // ==========================================================
                              // CHECK COMPONENT
                              // ==========================================================

                              selectObject(scenePosition);

                              if (selectedObject != null) {
                                selectedSegment = null;
                                selectedNode = null;

                                lastPointerPosition = scenePosition;

                                return;
                              }
                              // ==========================================================
                              // CHECK WIRE FIRST
                              // ==========================================================

                              final wireResult = findWireAtPosition(
                                scenePosition,
                              );

                              if (wireResult != null) {
                                selectedObject = null;
                                selectedSegment = wireResult.segment;
                                selectedNode = wireResult.node;

                                showEditPanel.value = false;
                                valueListenable.value = false;

                                lastPointerPosition = null;

                                print('Selected wire segment');

                                objectsNotifier.value = [
                                  ...objectsNotifier.value,
                                ];

                                return;
                              }

                              // ==========================================================
                              // CHECK TERMINAL
                              // ==========================================================

                              checkTerminal(scenePosition);

                              if (isConnecting.value) {
                                selectedObject = null;
                                selectedSegment = null;
                                selectedNode = null;
                                lastPointerPosition = null;

                                return;
                              }
                              // ==========================================================
                              // EMPTY CANVAS
                              // ==========================================================

                              selectedObject = null;
                              selectedSegment = null;
                              selectedNode = null;
                              lastPointerPosition = null;

                              valueListenable.value = true;

                              objectsNotifier.value = [
                                ...objectsNotifier.value,
                              ];
                            },

                            // ==================================================
                            // POINTER MOVE
                            // ==================================================
                            onPointerMove: (event) {
                              final scenePosition = event.localPosition;

                              // ==============================================
                              // CONNECTION DRAG
                              // ==============================================

                              if (isConnecting.value) {
                                connectionDragPosition = scenePosition;

                                objectsNotifier.value = [
                                  ...objectsNotifier.value,
                                ];

                                return;
                              }

                              // ==============================================
                              // COMPONENT DRAG
                              // ==============================================

                              if (selectedObject != null) {
                                if (!hasMovedSelectedObject) {
                                  historyManager.save(captureCurrentState());
                                  hasMovedSelectedObject = true;
                                }

                                moveSelectedObject(scenePosition);
                              }
                            },

                            // ==================================================
                            // POINTER UP
                            // ==================================================
                            onPointerUp: (event) {
                              final scenePosition = event.localPosition;

                              // CONNECTION RELEASE
                              if (isConnecting.value) {
                                final startObject = connectionStartObject;

                                final startTerminal = connectionStartTerminal;

                                if (startObject != null &&
                                    startTerminal != null) {
                                  // ----------------------------------------------------------
                                  // FIRST: CHECK IF POINTER IS ON A WIRE
                                  // ----------------------------------------------------------

                                  final wireResult = findWireAtPosition(
                                    scenePosition,
                                  );

                                  // ----------------------------------------------------------
                                  // SECOND: CHECK IF POINTER IS ON A TERMINAL
                                  // ----------------------------------------------------------

                                  final targetTerminal = findTerminal(
                                    scenePosition,
                                  );

                                  // ----------------------------------------------------------
                                  // PRIORITIZE WIRE
                                  // ----------------------------------------------------------

                                  if (wireResult != null) {
                                    connectTerminalToWire(
                                      startObject,
                                      startTerminal,
                                      scenePosition,
                                    );
                                    
                                  } else if (targetTerminal != null) {
                                    createConnection(
                                      startObject,
                                      startTerminal,
                                      targetTerminal.object,
                                      targetTerminal.terminal,
                                    );
                                  }
                                }

                                connectionStartObject = null;
                                connectionStartTerminal = null;
                                connectionDragPosition = null;
                                isConnecting.value = false;

                                nodesNotifier.value = [...nodesNotifier.value];

                                return;
                              }

                              // ==============================================
                              // COMPONENT RELEASE
                              // ==============================================

                              if (selectedObject != null) {
                                final snappedPosition = getSnappedPosition(
                                  selectedObject!,
                                );

                                selectedObject!.x = snappedPosition.dx;

                                selectedObject!.y = snappedPosition.dy;

                                objectsNotifier.value = [
                                  ...objectsNotifier.value,
                                ];

                                lastPointerPosition = null;

                                hasMovedSelectedObject = false;
                                lastPointerPosition = null;
                              }
                            },

                            // ==================================================
                            // POINTER CANCEL
                            // ==================================================
                            onPointerCancel: (event) {
                              selectedObject = null;

                              selectedSegment = null;

                              selectedNode = null;

                              lastPointerPosition = null;

                              connectionStartObject = null;

                              connectionStartTerminal = null;

                              connectionDragPosition = null;

                              isConnecting.value = false;
                            },

                            // ==================================================
                            // PAINTER
                            // ==================================================
                            child: ValueListenableBuilder<List<Component>>(
                              valueListenable: objectsNotifier,

                              builder: (context, objects, _) {
                                return ValueListenableBuilder<
                                  List<ConnectionNode>
                                >(
                                  valueListenable: nodesNotifier,

                                  builder: (context, nodes, _) {
                                    return CustomPaint(
                                      painter: MyCanvasPainter(
                                        objects,
                                        selectedObject,
                                        nodes,
                                        connectionStartObject,
                                        connectionStartTerminal,
                                        connectionDragPosition,
                                        selectedNode,
                                        selectedSegment,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ==========================================================
                  // SELECTION TOOLBAR
                  // ==========================================================
                  if (selectedObject != null || selectedSegment != null)
                    Positioned(
                      top: 20,
                      right: 20,

                      child: ValueListenableBuilder<bool>(
                        valueListenable: isRotating,

                        builder: (context, rotating, _) {
                          return Column(
                            children: [
                              // ==============================================
                              // EDIT COMPONENT
                              // ==============================================
                              if (selectedObject != null)
                                IconButton(
                                  onPressed: () {
                                    if (rotating) {
                                      return;
                                    }

                                    editSelectedObject();
                                  },

                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green,

                                    foregroundColor: Colors.white,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),

                                  icon: const Icon(Icons.edit),
                                ),

                              if (selectedObject != null)
                                const SizedBox(height: 0.5),

                              // ==============================================
                              // ROTATE COMPONENT
                              // ==============================================
                              if (selectedObject != null)
                                IconButton(
                                  onPressed: () {
                                    if (rotating) {
                                      return;
                                    }

                                    rotateSelectedObject();
                                  },

                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue,

                                    foregroundColor: Colors.white,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),

                                  icon: const Icon(Icons.rotate_right),
                                ),

                              const SizedBox(height: 0.5),

                              // ==============================================
                              // DELETE
                              // ==============================================
                              IconButton(
                                onPressed: () {
                                  if (rotating) {
                                    return;
                                  }

                                  // -------------------------------
                                  // DELETE COMPONENT
                                  // -------------------------------

                                  if (selectedObject != null) {
                                    deleteSelectedObject();
                                  }
                                  // -------------------------------
                                  // DELETE WIRE SEGMENT
                                  // -------------------------------
                                  else if (selectedSegment != null) {
                                    deleteSelectedSegment();
                                  }
                                },

                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,

                                  foregroundColor: Colors.white,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),

                                icon: const Icon(Icons.delete),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // ==========================================================
                  // EDIT PANEL
                  // ==========================================================
                  ValueListenableBuilder<bool>(
                    valueListenable: showEditPanel,

                    builder: (context, show, _) {
                      if (!show || selectedObject == null) {
                        return const SizedBox();
                      }

                      return Positioned(
                        top: 100,

                        left: (screenWidth - 280) / 2,

                        right: 20,

                        child: _buildEditPanel(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),

        // ==============================================================
        // COMPONENT BUTTONS
        // ==============================================================
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

          child: Row(
            children: [
              // ==========================================================
              // RESISTOR
              // ==========================================================
              _buildComponentButton(
                label: 'Resistor',
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 0));
                },
              ),

              const SizedBox(width: 8),

              // ==========================================================
              // VOLTAGE SOURCE
              // ==========================================================
              _buildComponentButton(
                label: 'Voltage Source',
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 1));
                },
              ),

              const SizedBox(width: 8),

              // ==========================================================
              // CURRENT SOURCE
              // ==========================================================
              _buildComponentButton(
                label: 'Current Source',
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 2));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
