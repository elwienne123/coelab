
import 'package:flutter/material.dart';
import 'package:coelab/component.dart';

class NodeTerminal {
  final Component object;
  final int terminal;

  NodeTerminal({
    required this.object,
    required this.terminal,
  });
}

// ============================================================
// WIRE SEGMENT
// ============================================================

class WireSegment {
  final NodePoint start;
  final NodePoint end;

  WireSegment({
    required this.start,
    required this.end,
  });
}

// ============================================================
// NODE POINT
// ============================================================

/// A point that can exist on a wire network.
///
/// It can be:
/// - a component terminal
/// - a point attached to another wire segment
/// - a fixed point
class NodePoint {
  final Component? object;
  final int? terminal;

  final WireSegment? parentSegment;
  final double? position;

  final Offset? fixedPosition;

  NodePoint.component({
    required this.object,
    required this.terminal,
  })  : parentSegment = null,
        position = null,
        fixedPosition = null;

  NodePoint.onWire({
    required this.parentSegment,
    required this.position,
  })  : object = null,
        terminal = null,
        fixedPosition = null;

  NodePoint.fixed({
    required this.fixedPosition,
  })  : object = null,
        terminal = null,
        parentSegment = null,
        position = null;

  // ============================================================
  // POSITION
  // ============================================================

  Offset getPosition() {
    // Component terminal
    if (object != null && terminal != null) {
      return object!.getWorldTerminalPosition(
        terminal!,
      );
    }

    // Point attached to an existing wire
    if (parentSegment != null && position != null) {
      final start =
          parentSegment!.start.getPosition();

      final end =
          parentSegment!.end.getPosition();

      return Offset(
        start.dx +
            (end.dx - start.dx) *
                position!,
        start.dy +
            (end.dy - start.dy) *
                position!,
      );
    }

    // Fixed point
    return fixedPosition!;
  }
}

// ============================================================
// CONNECTION NODE
// ============================================================

/// Represents ONE electrical node.
///
/// A node is a continuous conductive region.
///
/// Example:
///
/// R1 ─────●───── R2
///         │
///         R3
///
/// R1, R2 and R3 terminals connected to that
/// continuous wire belong to the SAME ConnectionNode.
class ConnectionNode {
  final List<NodeTerminal> terminals = [];

  final List<WireSegment> segments = [];

  ConnectionNode({
    required NodeTerminal start,
    required NodeTerminal end,
  }) {
    terminals.add(start);
    terminals.add(end);

    segments.add(
      WireSegment(
        start: NodePoint.component(
          object: start.object,
          terminal: start.terminal,
        ),
        end: NodePoint.component(
          object: end.object,
          terminal: end.terminal,
        ),
      ),
    );
  }

  // ============================================================
  // TERMINAL CHECKS
  // ============================================================

  bool containsTerminal(
    Component object,
    int terminal,
  ) {
    return terminals.any(
      (item) =>
          item.object == object &&
          item.terminal == terminal,
    );
  }

  bool containsObject(Component object) {
    return terminals.any(
      (item) => item.object == object,
    );
  }

  // ============================================================
  // FIND TERMINAL
  // ============================================================

  NodeTerminal? getTerminal(
    Component object,
    int terminal,
  ) {
    for (final item in terminals) {
      if (item.object == object &&
          item.terminal == terminal) {
        return item;
      }
    }

    return null;
  }

  // ============================================================
  // ADD TERMINAL
  // ============================================================

  void addTerminal(
    Component object,
    int terminal,
  ) {
    if (containsTerminal(
      object,
      terminal,
    )) {
      return;
    }

    terminals.add(
      NodeTerminal(
        object: object,
        terminal: terminal,
      ),
    );
  }

  // ============================================================
  // ADD WIRE BETWEEN TWO TERMINALS
  // ============================================================

  void addTerminalConnection({
    required Component startObject,
    required int startTerminal,
    required Component endObject,
    required int endTerminal,
  }) {
    addTerminal(
      startObject,
      startTerminal,
    );

    addTerminal(
      endObject,
      endTerminal,
    );

    final wire = WireSegment(
      start: NodePoint.component(
        object: startObject,
        terminal: startTerminal,
      ),
      end: NodePoint.component(
        object: endObject,
        terminal: endTerminal,
      ),
    );

    segments.add(wire);
  }

  // ============================================================
  // ADD BRANCH
  // ============================================================

  void addBranch({
    required WireSegment segment,
    required Component object,
    required int terminal,
  }) {
    segments.add(segment);

    addTerminal(
      object,
      terminal,
    );
  }

  // ============================================================
  // MERGE ANOTHER NODE INTO THIS NODE
  // ============================================================

  void mergeWith(
    ConnectionNode other,
  ) {
    // Add all terminals from the other node.
    for (final terminal
        in other.terminals) {
      addTerminal(
        terminal.object,
        terminal.terminal,
      );
    }

    // Add all wire segments from the other node.
    for (final segment
        in other.segments) {
      if (!segments.contains(segment)) {
        segments.add(segment);
      }
    }
  }

  // ============================================================
  // CHECK WHETHER A SEGMENT DEPENDS ON ANOTHER SEGMENT
  // ============================================================

  bool segmentDependsOn(
    WireSegment segment,
    WireSegment parent,
  ) {
    final startDepends =
        segment.start.parentSegment == parent;

    final endDepends =
        segment.end.parentSegment == parent;

    return startDepends || endDepends;
  }

  // ============================================================
  // REMOVE SEGMENT AND DEPENDENT BRANCHES
  // ============================================================

  void removeSegment(
    WireSegment segment,
  ) {
    final segmentsToRemove =
        <WireSegment>{
      segment,
    };

    bool foundDependency = true;

    while (foundDependency) {
      foundDependency = false;

      for (final candidate
          in segments) {

        if (segmentsToRemove
            .contains(candidate)) {
          continue;
        }

        for (final parent
            in segmentsToRemove) {

          if (segmentDependsOn(
            candidate,
            parent,
          )) {
            segmentsToRemove.add(
              candidate,
            );

            foundDependency = true;

            break;
          }
        }
      }
    }

    segments.removeWhere(
      (candidate) =>
          segmentsToRemove.contains(
        candidate,
      ),
    );

    cleanupUnusedTerminals();
  }

  // ============================================================
  // REMOVE TERMINALS THAT NO LONGER HAVE WIRES
  // ============================================================

  void cleanupUnusedTerminals() {
    terminals.removeWhere(
      (terminal) =>
          !_terminalStillConnected(
        terminal.object,
        terminal.terminal,
      ),
    );
  }

  bool _terminalStillConnected(
    Component object,
    int terminal,
  ) {
    for (final segment
        in segments) {

      final startMatches =
          segment.start.object == object &&
          segment.start.terminal == terminal;

      final endMatches =
          segment.end.object == object &&
          segment.end.terminal == terminal;

      if (startMatches ||
          endMatches) {
        return true;
      }
    }

    return false;
  }
}
