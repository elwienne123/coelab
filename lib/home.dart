import 'package:coelab/component.dart';
import 'package:coelab/painter.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ValueNotifier<List<Component>> objectsNotifier =ValueNotifier<List<Component>>([]);
  final ValueNotifier<bool> valueListenable = ValueNotifier<bool>(true);
  Component? selectedObject;
  Offset? lastPointerPosition;



  void addObject(Component object) {
  final index = objectsNotifier.value.length;

  final newObject = Component(
    x: 100 + (index * 20),
    y: 100 + (index * 20),
    type:object.type
  );

  objectsNotifier.value = [
    ...objectsNotifier.value,
    newObject,
  ];
}

void selectObject(Offset position) {

    selectedObject = null;

    for (final object in objectsNotifier.value.reversed) {

      if (object.contains(position)) {
        selectedObject = object; // Disable scaling and panning
        valueListenable.value = false;
        break;
      }
    }
  }
   void moveSelectedObject(Offset position) {

    if (selectedObject == null) return;

    if (lastPointerPosition == null) {
      lastPointerPosition = position;
      valueListenable.value = true; // Re-enable scaling and panning
      return;
    }
    

    final delta = position - lastPointerPosition!;

    selectedObject!.x += delta.dx;
    selectedObject!.y += delta.dy;

    lastPointerPosition = position;

    // Repaint canvas
    objectsNotifier.value = [
      ...objectsNotifier.value,
    ];
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children:[
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: valueListenable,
            builder: (context, value, _) {
              return InteractiveViewer(
                  constrained:false,
                   minScale: 0.5,
                  maxScale: 4.0,
                  scaleEnabled: value,
                  panEnabled: value,
                  
                  onInteractionStart: (details) {
                    // Handle interaction start
                  },
                  child:Container(
                    color:  const Color.fromARGB(255, 30, 30, 30),
                    width:900,
                    height: 1500,
                    child: Listener(
                       onPointerDown: (event) {
                                
                      selectObject(event.localPosition);
                       
                      lastPointerPosition = event.localPosition;
                    },
                                
                    onPointerMove: (event) {
                                
                      if (selectedObject != null) {
                                
                        moveSelectedObject(
                          event.localPosition,
                        );
                  
                      }
                    },
                                
                    onPointerUp: (event) {
                                
                      selectedObject = null;
                                
                      lastPointerPosition = null;
                      valueListenable.value = true; // Re-enable scaling and panning
                    },
                                
                    onPointerCancel: (event) {
                                
                      selectedObject = null;
                                
                      lastPointerPosition = null;
                      
                    },
                      child: ValueListenableBuilder<List<Component>>(
                      valueListenable: objectsNotifier,
                      builder: (context, objects, _) {
                        return CustomPaint(
                          painter: MyCanvasPainter(objects),
                        );
                      },
                                ),
                    ),
                  ),
                );
            }
          ),
        ),
       SingleChildScrollView(
        scrollDirection: Axis.horizontal,
          child: Row(
            children:[
              ElevatedButton(
            onPressed: () {
              addObject(Component(x: 100, y: 100, type:0));
            },
            child: const Text('Resistor'),
          ),
          ElevatedButton(
            onPressed: () {
              addObject(Component(x: 100, y: 100, type:1));
            },
            child: const Text('Voltage Source'),
          ),
          ElevatedButton(
            onPressed: () {
              addObject(Component(x: 100, y: 100, type:2));
            },
            child: const Text('Current Source'),
          ),
          
            ]
          ),
        )
      ]
    );
  }
}