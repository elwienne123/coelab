import 'package:coelab/component.dart';

class Connection {
  final Component startObject;
  final int startTerminal;

  final Component endObject;
  final int endTerminal;

  Connection({
    required this.startObject,
    required this.startTerminal,
    required this.endObject,
    required this.endTerminal,
  });
}