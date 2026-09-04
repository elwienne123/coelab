import 'package:flutter/material.dart';
import 'package:coelab/component.dart';
import 'package:coelab/connection.dart';

class CircuitSnapshot {
  final List<ComponentSnapshot> components;
  final List<NodeSnapshot> nodes;

  CircuitSnapshot({
    required this.components,
    required this.nodes,
  });

  // ============================================================
  // CAPTURE CURRENT CIRCUIT
  // ============================================================

  factory CircuitSnapshot.capture(
    List<Component> objects,
    List<ConnectionNode> nodes,
  ) {
    // ----------------------------------------------------------
    // COMPONENTS
    // ----------------------------------------------------------

    final componentSnapshots = objects.map((object) {
      return ComponentSnapshot(
        type: object.type,
        x: object.x,
        y: object.y,
        rotation: object.rotation,
        name: object.name,
        resistance: object.resistance,
        voltage: object.voltage,
        current: object.current,
      );
    }).toList();

    // ----------------------------------------------------------
    // GIVE EVERY WIRE SEGMENT AN ID
    // ----------------------------------------------------------

    final segmentIds = <WireSegment, int>{};

    int nextSegmentId = 0;

    for (final node in nodes) {
      for (final segment in node.segments) {
        segmentIds.putIfAbsent(
          segment,
          () => nextSegmentId++,
        );
      }
    }

    // ----------------------------------------------------------
    // NODES
    // ----------------------------------------------------------

    final nodeSnapshots = <NodeSnapshot>[];

    for (final node in nodes) {
      final terminalSnapshots = node.terminals.map((terminal) {
        return TerminalSnapshot(
          objectIndex: objects.indexOf(terminal.object),
          terminal: terminal.terminal,
        );
      }).toList();

      final segmentSnapshots = node.segments.map((segment) {
        return SegmentSnapshot(
          id: segmentIds[segment]!,
          start: PointSnapshot.fromNodePoint(
            segment.start,
            objects,
            segmentIds,
          ),
          end: PointSnapshot.fromNodePoint(
            segment.end,
            objects,
            segmentIds,
          ),
        );
      }).toList();

      nodeSnapshots.add(
        NodeSnapshot(
          terminals: terminalSnapshots,
          segments: segmentSnapshots,
        ),
      );
    }

    return CircuitSnapshot(
      components: componentSnapshots,
      nodes: nodeSnapshots,
    );
  }

  // ============================================================
  // RESTORE CIRCUIT
  // ============================================================

  RestoredCircuit restore() {
    // ----------------------------------------------------------
    // 1. RESTORE COMPONENTS
    // ----------------------------------------------------------

    final objects = components.map((snapshot) {
      return Component(
        type: snapshot.type,
        x: snapshot.x,
        y: snapshot.y,
        rotation: snapshot.rotation,
        name: snapshot.name,
        resistance: snapshot.resistance,
        voltage: snapshot.voltage,
        current: snapshot.current,
      );
    }).toList();

    // ----------------------------------------------------------
    // 2. CREATE EMPTY NODES
    // ----------------------------------------------------------

    final restoredNodes = nodes.map((_) {
      return ConnectionNode.empty();
    }).toList();

    // ----------------------------------------------------------
    // 3. CREATE SEGMENTS
    //
    // We cannot create a NodePoint.onWire() yet because it may
    // refer to another segment that hasn't been created.
    //
    // So first create every segment using temporary point data.
    // ----------------------------------------------------------

    final segmentMap = <int, WireSegment>{};

    final segmentSnapshots = <SegmentSnapshot>[];

    for (final node in nodes) {
      segmentSnapshots.addAll(node.segments);
    }

    // We need to create segments in dependency order.
    //
    // A segment can depend on another segment through a
    // NodePoint.onWire(). Therefore, repeatedly create segments
    // whose parent segments already exist.
    //
    // Normal component-to-component wires have no dependency and
    // will therefore be created immediately.

    final remaining =
        List<SegmentSnapshot>.from(segmentSnapshots);

    while (remaining.isNotEmpty) {
      bool createdSomething = false;

      for (int i = remaining.length - 1; i >= 0; i--) {
        final snapshot = remaining[i];

        final startReady =
            snapshot.start.parentSegmentIndex == null ||
                segmentMap.containsKey(
                  snapshot.start.parentSegmentIndex,
                );

        final endReady =
            snapshot.end.parentSegmentIndex == null ||
                segmentMap.containsKey(
                  snapshot.end.parentSegmentIndex,
                );

        if (!startReady || !endReady) {
          continue;
        }

        final start = snapshot.start.toNodePoint(
          objects,
          segmentMap,
        );

        final end = snapshot.end.toNodePoint(
          objects,
          segmentMap,
        );

        final segment = WireSegment(
          start: start,
          end: end,
        );

        segmentMap[snapshot.id] = segment;

        remaining.removeAt(i);

        createdSomething = true;
      }

      // --------------------------------------------------------
      // SAFETY CHECK
      // --------------------------------------------------------

      if (!createdSomething) {
        throw StateError(
          'Unable to restore circuit wire dependencies.',
        );
      }
    }

    // ----------------------------------------------------------
    // 4. RESTORE NODE TERMINALS AND SEGMENTS
    // ----------------------------------------------------------

    for (int i = 0; i < nodes.length; i++) {
      final snapshot = nodes[i];
      final node = restoredNodes[i];

      // --------------------------------------------------------
      // TERMINALS
      // --------------------------------------------------------

      for (final terminal in snapshot.terminals) {
        if (terminal.objectIndex < 0 ||
            terminal.objectIndex >= objects.length) {
          continue;
        }

        node.addTerminal(
          objects[terminal.objectIndex],
          terminal.terminal,
        );
      }

      // --------------------------------------------------------
      // SEGMENTS
      // --------------------------------------------------------

      for (final segmentSnapshot
          in snapshot.segments) {
        final segment =
            segmentMap[segmentSnapshot.id];

        if (segment != null) {
          node.segments.add(segment);
        }
      }
    }

    return RestoredCircuit(
      objects: objects,
      nodes: restoredNodes,
    );
  }
}

// ============================================================
// COMPONENT SNAPSHOT
// ============================================================

class ComponentSnapshot {
  final int type;
  final double x;
  final double y;
  final double rotation;
  final String name;

  final double resistance;
  final double voltage;
  final double current;

  ComponentSnapshot({
    required this.type,
    required this.x,
    required this.y,
    required this.rotation,
    required this.name,
    required this.resistance,
    required this.voltage,
    required this.current,
  });
}

// ============================================================
// TERMINAL SNAPSHOT
// ============================================================

class TerminalSnapshot {
  final int objectIndex;
  final int terminal;

  TerminalSnapshot({
    required this.objectIndex,
    required this.terminal,
  });
}

// ============================================================
// POINT SNAPSHOT
// ============================================================

enum PointSnapshotType {
  component,
  wire,
  fixed,
}

class PointSnapshot {
  final PointSnapshotType type;

  // Component point
  final int? objectIndex;
  final int? terminal;

  // Wire point
  final int? parentSegmentIndex;
  final double? position;
  final WireLeg? wireLeg;

  // Fixed point
  final double? fixedX;
  final double? fixedY;

  // ============================================================
  // COMPONENT
  // ============================================================

  PointSnapshot.component({
    required this.objectIndex,
    required this.terminal,
  })  : type = PointSnapshotType.component,
        parentSegmentIndex = null,
        position = null,
        wireLeg = null,
        fixedX = null,
        fixedY = null;

  // ============================================================
  // WIRE
  // ============================================================

  PointSnapshot.wire({
    required this.parentSegmentIndex,
    required this.position,
    required this.wireLeg,
  })  : type = PointSnapshotType.wire,
        objectIndex = null,
        terminal = null,
        fixedX = null,
        fixedY = null;

  // ============================================================
  // FIXED
  // ============================================================

  PointSnapshot.fixed({
    required this.fixedX,
    required this.fixedY,
  })  : type = PointSnapshotType.fixed,
        objectIndex = null,
        terminal = null,
        parentSegmentIndex = null,
        position = null,
        wireLeg = null;

  // ============================================================
  // CREATE SNAPSHOT FROM NODE POINT
  // ============================================================

  factory PointSnapshot.fromNodePoint(
    NodePoint point,
    List<Component> objects,
    Map<WireSegment, int> segmentIds,
  ) {
    // ----------------------------------------------------------
    // COMPONENT TERMINAL
    // ----------------------------------------------------------

    if (point.object != null &&
        point.terminal != null) {
      return PointSnapshot.component(
        objectIndex:
            objects.indexOf(point.object!),
        terminal: point.terminal!,
      );
    }

    // ----------------------------------------------------------
    // POINT ON WIRE
    // ----------------------------------------------------------

    if (point.parentSegment != null &&
        point.position != null &&
        point.wireLeg != null) {
      return PointSnapshot.wire(
        parentSegmentIndex:
            segmentIds[point.parentSegment],
        position: point.position!,
        wireLeg: point.wireLeg!,
      );
    }

    // ----------------------------------------------------------
    // FIXED POINT
    // ----------------------------------------------------------

    return PointSnapshot.fixed(
      fixedX: point.fixedPosition!.dx,
      fixedY: point.fixedPosition!.dy,
    );
  }

  // ============================================================
  // RESTORE NODE POINT
  // ============================================================

  NodePoint toNodePoint(
    List<Component> objects,
    Map<int, WireSegment> segmentMap,
  ) {
    switch (type) {
      case PointSnapshotType.component:
        return NodePoint.component(
          object: objects[objectIndex!],
          terminal: terminal!,
        );

      case PointSnapshotType.wire:
        final parent =
            segmentMap[parentSegmentIndex!];

        if (parent == null) {
          throw StateError(
            'Parent wire segment was not restored.',
          );
        }

        return NodePoint.onWire(
          parentSegment: parent,
          position: position!,
          wireLeg: wireLeg!,
        );

      case PointSnapshotType.fixed:
        return NodePoint.fixed(
          fixedPosition: Offset(
            fixedX!,
            fixedY!,
          ),
        );
    }
  }
}

// ============================================================
// SEGMENT SNAPSHOT
// ============================================================

class SegmentSnapshot {
  final int id;
  final PointSnapshot start;
  final PointSnapshot end;

  SegmentSnapshot({
    required this.id,
    required this.start,
    required this.end,
  });
}

// ============================================================
// NODE SNAPSHOT
// ============================================================

class NodeSnapshot {
  final List<TerminalSnapshot> terminals;
  final List<SegmentSnapshot> segments;

  NodeSnapshot({
    required this.terminals,
    required this.segments,
  });
}

// ============================================================
// RESTORED CIRCUIT
// ============================================================

class RestoredCircuit {
  final List<Component> objects;
  final List<ConnectionNode> nodes;

  RestoredCircuit({
    required this.objects,
    required this.nodes,
  });
}