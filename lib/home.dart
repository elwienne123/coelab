import 'package:coelab/component.dart';
import 'package:coelab/painter.dart';
import 'package:flutter/material.dart';
import 'package:coelab/connection.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late AnimationController rotationController;
  final ValueNotifier<bool> isRotating = ValueNotifier<bool>(false);
  static const double gridSize = 25.0;
  final ValueNotifier<List<Connection>> connectionsNotifier =
      ValueNotifier<List<Connection>>([]);
  final ValueNotifier<bool> showEditPanel = ValueNotifier<bool>(false);

  final TextEditingController editValueController = TextEditingController();
  final TransformationController transformationController =
      TransformationController();
  @override
  initState() {
    super.initState();
    rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    editValueController.dispose();
    rotationController.dispose();
    isConnecting.dispose();
    rotationController.dispose();
    super.dispose();
  }

  final ValueNotifier<List<Component>> objectsNotifier =
      ValueNotifier<List<Component>>([]);
  final ValueNotifier<bool> valueListenable = ValueNotifier<bool>(true);
  Component? selectedObject;
  Offset? lastPointerPosition;
  final ValueNotifier<bool> isConnecting = ValueNotifier<bool>(false);
  Component? connectionStartObject;
  int? connectionStartTerminal;
  Offset? connectionDragPosition;
  ({Component object, int terminal})? findTerminal(Offset position) {
    for (final object in objectsNotifier.value.reversed) {
      final terminal = object.getTerminalAt(position);

      if (terminal != null) {
        return (object: object, terminal: terminal);
      }
    }

    return null;
  }

  void createConnection(
    Component startObject,
    int startTerminal,
    Component endObject,
    int endTerminal,
  ) {
    // Don't connect a component to itself
    if (startObject == endObject) {
      return;
    }

    // Prevent duplicate connections
    final alreadyConnected = connectionsNotifier.value.any(
      (connection) =>
          (connection.startObject == startObject &&
              connection.startTerminal == startTerminal &&
              connection.endObject == endObject &&
              connection.endTerminal == endTerminal) ||
          (connection.startObject == endObject &&
              connection.startTerminal == endTerminal &&
              connection.endObject == startObject &&
              connection.endTerminal == startTerminal),
    );

    if (alreadyConnected) {
      return;
    }

    final connection = Connection(
      startObject: startObject,
      startTerminal: startTerminal,
      endObject: endObject,
      endTerminal: endTerminal,
    );

    connectionsNotifier.value = [...connectionsNotifier.value, connection];

    print(
      'Connected '
      '${startObject.name} terminal $startTerminal '
      'to '
      '${endObject.name} terminal $endTerminal',
    );
  }

  void addObject(Component object) {
    final position = getTopCenterOfCanvas();

    final snappedX = (position.dx / gridSize).round() * gridSize;

    final snappedY = (position.dy / gridSize).round() * gridSize;

    final newObject = Component(
      x: snappedX,
      y: snappedY,
      type: object.type,
      name: generateComponentName(object.type),
    );

    objectsNotifier.value = [...objectsNotifier.value, newObject];
  }

  String generateComponentName(int type) {
    String prefix;

    if (type == 0) {
      prefix = 'R';
    } else if (type == 1) {
      prefix = 'V';
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

  void selectObject(Offset position) {
    selectedObject = null;
    showEditPanel.value = false;
    for (final object in objectsNotifier.value.reversed) {
      if (object.contains(position)) {
        selectedObject = object;
        valueListenable.value = false;
        break;
      } else {
        selectedObject = null;
        valueListenable.value = false;
        valueListenable.value = true;
      }
    }
  }

  void moveSelectedObject(Offset position) {
    if (selectedObject == null) return;

    if (lastPointerPosition == null) {
      lastPointerPosition = position;
      return;
    }

    final delta = position - lastPointerPosition!;

    double newX = selectedObject!.x + delta.dx;
    double newY = selectedObject!.y + delta.dy;

    // Canvas boundaries
    const double canvasWidth = 900;
    const double canvasHeight = 1500;

    // Component terminal-to-terminal length
    const double componentLength = 100;

    // Keep the component inside the canvas
    newX = newX.clamp(25.0, canvasWidth - componentLength - 25);

    newY = newY.clamp(75.0, canvasHeight - 75);

    selectedObject!.x = newX;
    selectedObject!.y = newY;

    lastPointerPosition = position;

    objectsNotifier.value = [...objectsNotifier.value];
  }

  void checkTerminal(Offset position) {
    for (final object in objectsNotifier.value.reversed) {
      final terminal = object.getTerminalAt(position);

      if (terminal != null) {
        connectionStartObject = object;
        connectionStartTerminal = terminal;

        isConnecting.value = true;

        connectionDragPosition = object.getWorldTerminalPosition(terminal);

        print(
          'Connection started: '
          '${object.name} - Terminal $terminal',
        );

        return;
      }
    }
  }

  void deleteSelectedObject() {
    if (selectedObject == null) return;

    final objectToDelete = selectedObject;

    objectsNotifier.value = objectsNotifier.value
        .where((object) => object != objectToDelete)
        .toList();

    selectedObject = null;

    valueListenable.value = true;
  }

  void rotateSelectedObject() async {
    if (selectedObject == null || isRotating.value) return;

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

  Offset getSnappedPosition(Component object) {
    return Offset(
      (object.x / gridSize).round() * gridSize,
      (object.y / gridSize).round() * gridSize,
    );
  }

  Offset getTopCenterOfCanvas() {
    final screenSize = MediaQuery.of(context).size;

    // Top-center of the phone screen
    final screenPoint = Offset((screenSize.width / 2) - 100 / 2, 100);

    // Convert screen coordinate to canvas coordinate
    final canvasPoint = transformationController.toScene(screenPoint);

    return canvasPoint;
  }

  void editSelectedObject() {
    if (selectedObject == null) return;

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
          // =========================
          // HEADER
          // =========================
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

          // =========================
          // VALUE
          // =========================
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

          // =========================
          // SAVE
          // =========================
          SizedBox(
            width: double.infinity,

            child: ElevatedButton(
              onPressed: () {
                final double? value = double.tryParse(editValueController.text);

                if (value == null) {
                  return;
                }

                // Update selected component

                if (object.type == 0) {
                  object.resistance = value;
                } else if (object.type == 1) {
                  object.voltage = value;
                } else {
                  object.current = value;
                }

                // Repaint canvas

                objectsNotifier.value = [...objectsNotifier.value];

                // Close editor

                showEditPanel.value = false;
              },

              child: const Text('SAVE'),
            ),
          ),
        ],
      ),
    );
  }

  void selectTerminal(Offset position) {
    connectionStartObject = null;
    connectionStartTerminal = null;

    for (final object in objectsNotifier.value.reversed) {
      final terminal = object.getTerminalAt(position);

      if (terminal != null) {
        connectionStartObject = object;
        connectionStartTerminal = terminal;

        print(
          'Terminal selected: '
          '${object.name} - Terminal $terminal',
        );

        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: valueListenable,
            builder: (context, value, _) {
              return Stack(
                children: [
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
                        onInteractionStart: (details) {
                          // Handle interaction start
                        },
                        child: Container(
                          color: const Color.fromARGB(255, 30, 30, 30),
                          width: 900,
                          height: 1500,
                          child: Listener(
  onPointerDown: (event) {
     // Listener is inside InteractiveViewer,
  // so localPosition is already in canvas coordinates.
  final scenePosition = event.localPosition;

  // ==========================================
  // CHECK TERMINAL FIRST
  // ==========================================

  checkTerminal(scenePosition);

  if (isConnecting.value) {
    selectedObject = null;
    lastPointerPosition = null;

    return;
  }

  // ==========================================
  // SELECT COMPONENT
  // ==========================================

  selectObject(scenePosition);

  if (selectedObject != null) {
    lastPointerPosition = scenePosition;
  } else {
    lastPointerPosition = null;
  }
  },

  onPointerMove: (event) {
     // Already in canvas coordinates.
  final scenePosition = event.localPosition;

  // ==========================================
  // CONNECTION DRAG
  // ==========================================

  if (isConnecting.value) {
    connectionDragPosition = scenePosition;

    objectsNotifier.value = [
      ...objectsNotifier.value,
    ];

    return;
  }

  // ==========================================
  // COMPONENT DRAG
  // ==========================================

  if (selectedObject != null) {
    moveSelectedObject(scenePosition);
  }
  },

  onPointerUp: (event) {

  // Already in canvas coordinates.
  final scenePosition = event.localPosition;

  // ==========================================
  // CONNECTION RELEASE
  // ==========================================

  if (isConnecting.value) {
    final target = findTerminal(scenePosition);

    if (target != null) {
      final startObject = connectionStartObject;
      final startTerminal = connectionStartTerminal;

      if (startObject != null &&
          startTerminal != null) {
        createConnection(
          startObject,
          startTerminal,
          target.object,
          target.terminal,
        );
      }
    }

    // Reset connection state
    connectionStartObject = null;
    connectionStartTerminal = null;
    connectionDragPosition = null;

    isConnecting.value = false;

    objectsNotifier.value = [
      ...objectsNotifier.value,
    ];

    return;
  }

  // ==========================================
  // COMPONENT RELEASE
  // ==========================================

  if (selectedObject != null) {
    final snappedPosition =
        getSnappedPosition(selectedObject!);

    selectedObject!.x = snappedPosition.dx;
    selectedObject!.y = snappedPosition.dy;

    objectsNotifier.value = [
      ...objectsNotifier.value,
    ];

    lastPointerPosition = null;
  }
  },

  onPointerCancel: (event) {
    selectedObject = null;

    lastPointerPosition = null;

    connectionStartObject = null;
    connectionStartTerminal = null;
    connectionDragPosition = null;

    isConnecting.value = false;
  },

  child: ValueListenableBuilder<List<Component>>(
    valueListenable: objectsNotifier,
    builder: (context, objects, _) {
      return ValueListenableBuilder<List<Connection>>(
        valueListenable: connectionsNotifier,
        builder: (context, connections, _) {
          return CustomPaint(
            painter: MyCanvasPainter(
              objects,
              selectedObject,
              connections,
              connectionStartObject,
              connectionStartTerminal,
              connectionDragPosition,
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
                  if (selectedObject != null)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isRotating,
                        builder: (context, rotating, _) {
                          return Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (rotating) return;
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
                              IconButton(
                                onPressed: () {
                                  if (rotating) return;

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
                              IconButton(
                                onPressed: () {
                                  if (rotating) return;

                                  deleteSelectedObject();
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 0));
                },
                child: const Text('Resistor'),
              ),
              ElevatedButton(
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 1));
                },
                child: const Text('Voltage Source'),
              ),
              ElevatedButton(
                onPressed: () {
                  addObject(Component(x: 100, y: 100, type: 2));
                },
                child: const Text('Current Source'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
