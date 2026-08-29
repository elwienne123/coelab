import 'package:coelab/component.dart';
import 'package:flutter/material.dart';

class MyCanvasPainter extends CustomPainter {
  final List<Component> objects;
  final Component? selectedObject;
  MyCanvasPainter(this.objects, this.selectedObject);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

      final paintComp = Paint()
      ..color = const Color.fromARGB(255, 0, 179, 255)
      ..style = PaintingStyle.fill;

    const spacing = 25.0;
    const radius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          radius,
          paint,
        );
      }
    }

    // Draw your components after the dots
    for (final object in objects) {
       canvas.save();

        final center = Offset(
          object.x+50,
          object.y,
        );
       canvas.translate(
        center.dx,
        center.dy,
      );
      canvas.rotate(
      object.rotation,
      );
      canvas.translate(
      -center.dx,
      -center.dy,
    );
    if (object == selectedObject) {

        final selectionPaint = Paint()
          ..color = Colors.white.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

              final selectionBox = RRect.fromRectAndRadius(
        object.hitbox.inflate(1),
        const Radius.circular(2),
      );

      canvas.drawRRect(
        selectionBox,
        selectionPaint,
      );
      }
     if(object.type==2){

      drawCurrentSource(canvas, Offset(object.x, object.y), paintComp);
     }
     else if(object.type==1)
     {
      drawVoltageSource(canvas, Offset(object.x, object.y), paintComp);
     }
     else
     {
      drawResistor(canvas, Offset(object.x, object.y), paintComp);
      
     }
      drawComponentLabel(
  canvas,
  object,
);
    canvas.restore();
    }
    
   
  }
    void drawCurrentSource(
    Canvas canvas,
    Offset position,
    Paint paint,
        ) {
        const double leadLength = 25;
        const double bodyRadius = 25;
        const double terminalRadius = 5;

        final double x = position.dx;
        final double y = position.dy;

        // -------------------------
        // Metal leads
        // -------------------------

        final leadPaint = Paint()
          ..color = Colors.grey.shade600
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

        // Left lead
        canvas.drawLine(
          Offset(x, y),
          Offset(x + leadLength, y),
          leadPaint,
        );

        // Right lead
        canvas.drawLine(
          Offset(
            x + leadLength + bodyRadius * 2,
            y,
          ),
          Offset(
            x + leadLength + bodyRadius * 2 + leadLength,
            y,
          ),
          leadPaint,
        );

        // -------------------------
        // Current source body
        // -------------------------

        final center = Offset(
          x + leadLength + bodyRadius,
          y,
        );

        final bodyPaint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          center,
          bodyRadius,
          bodyPaint,
        );

        // -------------------------
        // Current direction arrow →
        // -------------------------

        final arrowPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        // Arrow shaft
        canvas.drawLine(
          Offset(center.dx - 12, center.dy),
          Offset(center.dx + 12, center.dy),
          arrowPaint,
        );

        // Arrow head
        canvas.drawLine(
          Offset(center.dx + 12, center.dy),
          Offset(center.dx + 5, center.dy - 6),
          arrowPaint,
        );

        canvas.drawLine(
          Offset(center.dx + 12, center.dy),
          Offset(center.dx + 5, center.dy + 6),
          arrowPaint,
        );

        // -------------------------
        // Connection terminals
        // -------------------------

        final terminalPaint = Paint()
          ..color = Colors.grey.shade600
          ..style = PaintingStyle.fill;
          final terminalPaintHole = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        // Left terminal
        canvas.drawCircle(
          Offset(x, y),
          terminalRadius,
          terminalPaint,
        );
      canvas.drawCircle(
          Offset(x, y),
          terminalRadius-2.5,
          terminalPaintHole,
        );
        // Right terminal
        canvas.drawCircle(
          Offset(
            x + leadLength + bodyRadius * 2 + leadLength,
            y,
          ),
          terminalRadius,
          terminalPaint,
        );
        canvas.drawCircle(
          Offset(
            x + leadLength + bodyRadius * 2 + leadLength,
            y,
          ),
          terminalRadius-2.5,
          terminalPaintHole,
        );
      }
    void drawVoltageSource(
  Canvas canvas,
  Offset position,
  Paint paint,
) {
  const double leadLength = 25;
  const double bodyWidth = 50;
  const double bodyHeight = 35;
  const double terminalRadius = 5;

  final double x = position.dx;
  final double y = position.dy;

  // -------------------------
  // Metal leads
  // -------------------------

  final leadPaint = Paint()
    ..color = Colors.grey.shade600
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  // Left lead
  canvas.drawLine(
    Offset(x, y),
    Offset(x + leadLength, y),
    leadPaint,
  );

  // Right lead
  canvas.drawLine(
    Offset(
      x + leadLength + bodyWidth,
      y,
    ),
    Offset(
      x + leadLength + bodyWidth + leadLength,
      y,
    ),
    leadPaint,
  );

  // -------------------------
  // Voltage source body
  // -------------------------

  final bodyRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(
        x + leadLength + bodyWidth / 2,
        y,
      ),
      width: bodyWidth,
      height: bodyHeight,
    ),
    const Radius.circular(6),
  );

  final bodyPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;

  canvas.drawRRect(
    bodyRect,
    bodyPaint,
  );

  // -------------------------
  // + and - symbols
  // -------------------------

  final symbolPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  final centerX = x + leadLength + bodyWidth / 2;

  // Plus
  canvas.drawLine(
    Offset(centerX - 12, y - 7),
    Offset(centerX - 12, y + 7),
    symbolPaint,
  );

  canvas.drawLine(
    Offset(centerX - 19, y),
    Offset(centerX - 5, y),
    symbolPaint,
  );

  // Minus
  canvas.drawLine(
    Offset(centerX + 5, y),
    Offset(centerX + 19, y),
    symbolPaint,
  );

  // -------------------------
  // Connection terminals
  // -------------------------

  final terminalPaint = Paint()
    ..color = Colors.grey.shade600
    ..style = PaintingStyle.fill;
final terminalPaintHole = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  // Left terminal
  canvas.drawCircle(
    Offset(x, y),
    terminalRadius,
    terminalPaint,
  );

  canvas.drawCircle(
    Offset(x, y),
    terminalRadius-2.5,
    terminalPaintHole ,
  );

  // Right terminal
  canvas.drawCircle(
    Offset(
      x + leadLength + bodyWidth + leadLength,
      y,
    ),
    terminalRadius,
    terminalPaint,
  );
  canvas.drawCircle(
    Offset(
      x + leadLength + bodyWidth + leadLength,
      y,
    ),
    terminalRadius-2.5,
    terminalPaintHole ,
  );
}
    void drawResistor(
          Canvas canvas,
          Offset position,
          Paint paint,
        ) {
          const double leadLength = 25;
          const double bodyWidth = 50;
          const double bodyHeight = 20;
          const double terminalRadius = 5;

          final double x = position.dx;
          final double y = position.dy;

          // -------------------------
          // Metal leads
          // -------------------------

          final leadPaint = Paint()
            ..color = Colors.grey.shade600
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke;

          // Left lead
          canvas.drawLine(
            Offset(x, y),
            Offset(x + leadLength, y),
            leadPaint,
          );

          // Right lead
          canvas.drawLine(
            Offset(x + leadLength + bodyWidth, y),
            Offset(
              x + leadLength + bodyWidth + leadLength,
              y,
            ),
            leadPaint,
          );

          // -------------------------
          // Resistor body
          // -------------------------

          final bodyRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(
                x + leadLength + bodyWidth / 2,
                y,
              ),
              width: bodyWidth,
              height: bodyHeight,
            ),
            const Radius.circular(6),
          );

          final bodyPaint = Paint()
            ..color = const Color(0xFFD6B27C)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(
            bodyRect,
            bodyPaint,
          );

          // -------------------------
          // Color bands
          // -------------------------

          const double bandWidth = 5;

          final bands = [
            const Color(0xFF8B4513), // Brown
            Colors.black,
            const Color(0xFFD32F2F), // Red
            const Color(0xFFFFD54F), // Gold
          ];

          final bandPositions = [
            x + leadLength + 6,
            x + leadLength + 16,
            x + leadLength + 26,
            x + leadLength + 38,
          ];

          for (int i = 0; i < bands.length; i++) {
            final bandPaint = Paint()
              ..color = bands[i]
              ..style = PaintingStyle.fill;

            canvas.drawRect(
              Rect.fromLTWH(
                bandPositions[i],
                y - bodyHeight / 2,
                bandWidth,
                bodyHeight,
              ),
              bandPaint,
            );
          }

          // -------------------------
          // Connection points
          // -------------------------

          final terminalPaint = Paint()
            ..color = Colors.grey.shade600
            ..style = PaintingStyle.fill;

            final terminalPaintHole = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

          // Left connection point
          canvas.drawCircle(
            Offset(x, y),
            terminalRadius,
            terminalPaint,
          );
          canvas.drawCircle(
            Offset(x, y),
            terminalRadius-2.5,
            terminalPaintHole,
          );

          // Right connection point
          canvas.drawCircle(
            Offset(
              x + leadLength + bodyWidth + leadLength,
              y,
            ),
            terminalRadius,
            terminalPaint,
          );
          canvas.drawCircle(
            Offset(
              x + leadLength + bodyWidth + leadLength,
              y,
            ),
            terminalRadius-2.5,
            terminalPaintHole,
          );


        }
  String getComponentValue(Component object) {

  if (object.type == 0) {
    return '${object.resistance} Ω';
  }

  if (object.type == 1) {
    return '${object.voltage} V';
  }

  return '${object.current} A';
}


void drawComponentLabel(
  Canvas canvas,
  Component object,
) {
  final namePainter = TextPainter(
    text: TextSpan(
      text: object.name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  final valuePainter = TextPainter(
    text: TextSpan(
      text: getComponentValue(object),
      style: const TextStyle(
        color: Colors.white70,
        fontSize:14,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  namePainter.layout();
  valuePainter.layout();

  final center = Offset(
    object.x + 50,
    object.y,
  );

  final pi = 3.14159265359;

  // Normalize rotation between 0 and 2π
  double rotation =
      object.rotation % (2 * pi);

  if (rotation < 0) {
    rotation += 2 * pi;
  }

  // Determine whether the component is vertical.
  final bool isVertical =
      (rotation - pi / 2).abs() < pi / 4 ||
      (rotation - 3 * pi / 2).abs() < pi / 4;

  double nameX;
  double nameY;

  double valueX;
  double valueY;

  if (!isVertical) {

    // =========================
    // HORIZONTAL
    // =========================

    nameX =
        center.dx -
        namePainter.width / 2;

    nameY =
        center.dy -
        60;

    valueX =
        center.dx -
        valuePainter.width / 2;

    valueY =
        nameY +
        namePainter.height +
        2;

  } else {

    // =========================
    // VERTICAL
    // =========================

    final totalHeight =
        namePainter.height +
        valuePainter.height +
        2;

    nameX =
        center.dx -
        30 -
        namePainter.width;

    nameY =
        center.dy -
        totalHeight / 2;

    valueX =
        center.dx -
        30 -
        valuePainter.width;

    valueY =
        nameY +
        namePainter.height +
        2;
  }

  canvas.save();

  // Keep the label readable regardless
  // of the component's rotation.
  canvas.translate(
    center.dx,
    center.dy,
  );

  canvas.rotate(
    -object.rotation,
  );

  canvas.translate(
    -center.dx,
    -center.dy,
  );

  // Draw component name
  namePainter.paint(
    canvas,
    Offset(nameX, nameY),
  );

  // Draw component value
  valuePainter.paint(
    canvas,
    Offset(valueX, valueY),
  );

  canvas.restore();
}



  @override
  bool shouldRepaint(covariant MyCanvasPainter oldDelegate) {
    return oldDelegate.objects != objects;
  }
}
