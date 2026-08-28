import 'dart:ui';

import 'package:flutter/material.dart';

class Component{
  int type;
  double x;
  double y;
   double rotation;

  Component({
    required this.x,
    required this.y,
    required this.type,
    this.rotation=0,
  });
  Rect get hitbox {
    return Rect.fromCenter(
      center: Offset( x+50,y),
      width: 50,
      height: 50,
    );
  }
  bool contains(Offset position) {
    return hitbox.contains(position);
  }
  void draw(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.blue;

    canvas.drawCircle(
      Offset(x, y),
      20,
      paint,
    );
  }
}