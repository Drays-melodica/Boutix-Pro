import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/keyboard_guard.dart';

typedef DosMenuCallback = void Function(int index);

/// Menu vertical navigable au clavier (↑↓ Entrée Échap).
class DosMenu extends StatefulWidget {
  const DosMenu({
    super.key,
    required this.items,
    required this.onSelect,
    this.onCancel,
    this.selectedIndex = 0,
  });

  final List<String> items;
  final DosMenuCallback onSelect;
  final VoidCallback? onCancel;
  final int selectedIndex;

  @override
  State<DosMenu> createState() => DosMenuState();
}

class DosMenuState extends State<DosMenu> {
  late int _selected;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.isEmpty
        ? 0
        : widget.selectedIndex.clamp(0, widget.items.length - 1);
    _focusNode = FocusNode(debugLabel: 'DosMenu');
    WidgetsBinding.instance.addPostFrameCallback((_) => focusMenu());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Remet le focus clavier sur ce menu (après la barre BIOS, retour d'écran…).
  void focusMenu() {
    if (!mounted) return;
    if (!_focusNode.canRequestFocus) return;
    _focusNode.requestFocus();
  }

  void _move(int delta) {
    if (widget.items.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, widget.items.length - 1);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (KeyboardGuard.isActive) return KeyEventResult.handled;
        widget.onSelect(_selected);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (KeyboardGuard.isActive) return KeyEventResult.handled;
        widget.onCancel?.call();
        return KeyEventResult.handled;
      default:
        final label = event.logicalKey.keyLabel;
        if (label.length == 1) {
          final n = int.tryParse(label);
          if (n != null && n >= 1 && n <= widget.items.length) {
            widget.onSelect(n - 1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.items.length, (i) {
          final selected = i == _selected;
          return Container(
            width: double.infinity,
            color: selected ? DosColors.highlight : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${selected ? '►' : ' '} ${i + 1}. ${widget.items[i]}',
              style: DosTheme.text(
                color: selected ? DosColors.highlightText : DosColors.text,
                weight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
    );
  }
}
