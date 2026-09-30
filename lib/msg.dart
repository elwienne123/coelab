import 'package:flutter/material.dart';

class Message extends StatelessWidget {
  final String msg;
  final bool isHeading;
  const Message({super.key, required this.msg, required this.isHeading});

  @override
  Widget build(BuildContext context) {
    return Text(msg, style: TextStyle(color: const Color.fromARGB(255, 202, 202, 202), fontSize: 14, fontWeight: (isHeading)?FontWeight.bold:FontWeight.normal),);
  }
}