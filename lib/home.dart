import 'package:coelab/component.dart';
import 'package:coelab/painter.dart';
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin{
  late AnimationController rotationController;
  final ValueNotifier<bool> isRotating =
    ValueNotifier<bool>(false);
    static const double gridSize = 25.0;
    final TransformationController transformationController =TransformationController();
  @override
  initState() {
    super.initState();
    rotationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  }
  final ValueNotifier<List<Component>> objectsNotifier =ValueNotifier<List<Component>>([]);
  final ValueNotifier<bool> valueListenable = ValueNotifier<bool>(true);
  Component? selectedObject;
  Offset? lastPointerPosition;
  


  void addObject(Component object) {
  
 final position = getTopCenterOfCanvas();
  final newObject = Component(
    x: position.dx,
    y: position.dy,
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
      }else{
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
  newX = newX.clamp(
    25.0,
    canvasWidth - componentLength-25,
  );

  newY = newY.clamp(
   75.0,
    canvasHeight-75,
  );

  selectedObject!.x = newX;
  selectedObject!.y = newY;

  lastPointerPosition = position;

  objectsNotifier.value = [
    ...objectsNotifier.value,
  ];
}

  void rotateSelectedObject() async {
  if (selectedObject == null || isRotating.value) return;

  isRotating.value = true;

  final double startRotation =
      selectedObject!.rotation;

  final double endRotation =
      startRotation + (3.14159265359 / 2);

  final animation = Tween<double>(
    begin: startRotation,
    end: endRotation,
  ).animate(
    CurvedAnimation(
      parent: rotationController,
      curve: Curves.easeOutCubic,
    ),
  );

  animation.addListener(() {

    if (selectedObject != null) {

      selectedObject!.rotation =
          animation.value;

      objectsNotifier.value = [
        ...objectsNotifier.value,
      ];
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
  final screenPoint = Offset(
    (screenSize.width / 2)-100/2,
    100,
  );

  // Convert screen coordinate to canvas coordinate
  final canvasPoint =
      transformationController.toScene(screenPoint);

  return canvasPoint;
}
  @override
  Widget build(BuildContext context) {
    return Column(
      children:[
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: valueListenable,
            builder: (context, value, _) {
              return Stack(
                children: [InteractiveViewer(
                    constrained:false,
                     minScale: 0.5,
                    maxScale: 4.0,
                    scaleEnabled: value,
                    panEnabled: value,
                     transformationController: transformationController,
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
                      
                        if (selectedObject != null) {

                      final snappedPosition =
                          getSnappedPosition(selectedObject!);

                      selectedObject!.x =
                          snappedPosition.dx;

                      selectedObject!.y =
                          snappedPosition.dy;

                      objectsNotifier.value = [
                        ...objectsNotifier.value,
                      ];
                    }
  
                      },
                                  
                      onPointerCancel: (event) {
                                  
                        selectedObject = null;
                                  
                        lastPointerPosition = null;
                        
                      },
                        child: ValueListenableBuilder<List<Component>>(
                        valueListenable: objectsNotifier,
                        builder: (context, objects, _) {
                          return CustomPaint(
                            painter: MyCanvasPainter(objects, selectedObject),
                          );
                        },
                                  ),
                      ),
                    ),
                  ),
                  if (selectedObject != null)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isRotating, 
                      builder: (context,rotating, _) {  
                        return IconButton(
                        onPressed:  (){
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
                      
                        icon: const Icon(
                          Icons.rotate_right,
                        ),
                      );
                      }, 
                    )
                  ),
                  ]
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