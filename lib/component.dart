
import 'dart:math' as math;
import 'package:flutter/material.dart';

class Component {
  int type;
  double x;
  double y;
  double rotation;

  String name;

  // Electrical properties
  double resistance;
  double voltage;
  double current;

  Component({
    required this.x,
    required this.y,
    required this.type,
    this.rotation = 0,
    this.name = '',
    this.resistance = 1000,
    this.voltage = 5,
    this.current = 1,
  });

  // ============================================================
  // COMPONENT CENTER
  // ============================================================

  Offset get center {
    return Offset(
      x + 50,
      y,
    );
  }

  // ============================================================
  // TERMINALS
  // ============================================================

  /// Terminal 0 = left terminal
  /// Terminal 1 = right terminal
 
Offset getTerminalPosition(int terminalIndex) {

  if (terminalIndex == 0) {
    // Left terminal
    return Offset(
      x,
      y,
    );
  }

  // Right terminal
  return Offset(
    x + 100,
    y,
  );
}
Offset getWorldTerminalPosition(int terminalIndex) {

  final terminal =
      getTerminalPosition(terminalIndex);

  final centerPoint = center;

  final dx =
      terminal.dx - centerPoint.dx;

  final dy =
      terminal.dy - centerPoint.dy;

  final cosAngle =
      math.cos(rotation);

  final sinAngle =
      math.sin(rotation);

  final rotatedX =
      dx * cosAngle -
      dy * sinAngle;

  final rotatedY =
      dx * sinAngle +
      dy * cosAngle;

  return Offset(
    centerPoint.dx + rotatedX,
    centerPoint.dy + rotatedY,
  );
}
  // ============================================================
  // TERMINAL HIT DETECTION
  // ============================================================

  int? getTerminalAt(
  Offset position, {
  double radius = 25,
}) {

  for (int i = 0; i < 2; i++) {

    final terminal =
        getWorldTerminalPosition(i);

    if ((position - terminal).distance <= radius) {
      return i;
    }
  }

  return null;
}

  // ============================================================
  // HITBOX
  // ============================================================

  Rect get hitbox {
    return Rect.fromCenter(
      center: center,
      width: 50,
      height: 50,
    );
  }

  bool contains(Offset position) {
    return hitbox.contains(position);
  }

 
  
}