import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Implements "pressing Enter inherits the current inline formatting" for the
/// note editor.
///
/// Extracted from `NoteViewModel` (Recipe R3): it operates purely on a
/// [QuillController] and holds no note or presentation state. The owner wires
/// [onFocusChanged] to the editor's focus node and calls [detach] on dispose.
class NoteEditorKeyHandler {
  NoteEditorKeyHandler(this._controller);

  final QuillController _controller;
  bool _isHandlingKeyEvent = false;

  /// Attach the hardware-keyboard handler while the editor has focus; detach
  /// when it loses focus.
  void onFocusChanged(bool hasFocus) {
    if (hasFocus) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
  }

  /// Remove the handler unconditionally (call from the owner's dispose).
  void detach() => HardwareKeyboard.instance.removeHandler(_handleKeyEvent);

  bool _handleKeyEvent(KeyEvent event) {
    if (_isHandlingKeyEvent) return false;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _isHandlingKeyEvent = true;
      // Handle the event after the current frame.
      Future.microtask(() {
        _handleEnterKey();
        _isHandlingKeyEvent = false;
      });
    }
    return false; // Never consume the event.
  }

  void _handleEnterKey() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final index = selection.baseOffset;
    final currentLine = _getCurrentLine(index);
    if (currentLine == null) return;

    final currentAttributes = currentLine.style.attributes;

    final isInList =
        currentAttributes.containsKey(Attribute.ul.key) ||
        currentAttributes.containsKey(Attribute.ol.key) ||
        currentAttributes.containsKey(Attribute.checked.key);

    // In a list, let Quill handle continuation naturally; otherwise inherit
    // inline formatting onto the new line.
    if (!isInList) {
      _handleFormattingInheritance(index, currentAttributes);
    }
  }

  Node? _getCurrentLine(int index) {
    try {
      final lines = _controller.document.root.children;
      var currentOffset = 0;
      for (final line in lines) {
        final lineLength = line.length;
        if (currentOffset <= index && index <= currentOffset + lineLength) {
          return line;
        }
        currentOffset += lineLength;
      }
    } catch (_) {
      // Handle any errors gracefully.
    }
    return null;
  }

  void _handleFormattingInheritance(int index, Map<String, Attribute> currentAttributes) {
    // Only inherit text-level formatting, not block-level.
    final textFormatting = <String, Attribute>{};
    void inherit(Attribute attr) {
      if (currentAttributes.containsKey(attr.key)) {
        textFormatting[attr.key] = currentAttributes[attr.key] ?? attr;
      }
    }

    inherit(Attribute.bold);
    inherit(Attribute.italic);
    inherit(Attribute.underline);
    inherit(Attribute.strikeThrough);
    inherit(Attribute.color);
    inherit(Attribute.background);

    // Insert newline and let Quill handle the rest naturally.
    _controller.document.insert(index, '\n');

    for (final attribute in textFormatting.values) {
      _controller.formatSelection(attribute);
    }
  }
}
