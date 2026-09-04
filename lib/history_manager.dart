import 'package:flutter/foundation.dart';
import 'package:coelab/history.dart';

class HistoryManager extends ChangeNotifier {
  final List<CircuitSnapshot> _undoStack = [];
  final List<CircuitSnapshot> _redoStack = [];

  // ============================================================
  // SAVE
  // ============================================================

  void save(CircuitSnapshot snapshot) {
    _undoStack.add(snapshot);

    // A new action invalidates the redo history.
    _redoStack.clear();

    notifyListeners();
  }

  // ============================================================
  // UNDO
  // ============================================================

  CircuitSnapshot? undo(
    CircuitSnapshot currentState,
  ) {
    if (_undoStack.isEmpty) {
      return null;
    }

    final previousState = _undoStack.removeLast();

    _redoStack.add(currentState);

    notifyListeners();

    return previousState;
  }

  // ============================================================
  // REDO
  // ============================================================

  CircuitSnapshot? redo(
    CircuitSnapshot currentState,
  ) {
    if (_redoStack.isEmpty) {
      return null;
    }

    final nextState = _redoStack.removeLast();

    _undoStack.add(currentState);

    notifyListeners();

    return nextState;
  }

  // ============================================================
  // CHECKS
  // ============================================================

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    _undoStack.clear();
    _redoStack.clear();

    notifyListeners();
  }
}