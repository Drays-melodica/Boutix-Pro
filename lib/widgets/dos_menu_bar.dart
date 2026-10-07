import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';

/// Entrée de la barre de menus horizontale (style setup BIOS).
class DosMenuBarItem {
  const DosMenuBarItem({
    required this.label,
    required this.onSelect,
    this.hotkey,
  });

  final String label;
  final VoidCallback onSelect;

  /// Lettre soulignée pour Alt+lettre (ex. 'S' pour Société).
  final String? hotkey;
}

/// Barre de menus horizontale façon CMOS/BIOS (Main │ Advanced │ …).
class DosMenuBar extends StatefulWidget {
  const DosMenuBar({
    super.key,
    required this.items,
    this.hint = 'F10: barre | ←→ Entrée | Alt+lettre',
    this.onBlur,
  });

  final List<DosMenuBarItem> items;
  final String hint;

  /// Appelé quand la barre rend le focus (Esc, sélection, clic).
  final VoidCallback? onBlur;

  @override
  State<DosMenuBar> createState() => DosMenuBarState();
}

class DosMenuBarState extends State<DosMenuBar> {
  late final FocusNode _focus;
  int _selected = 0;
  bool _active = false;

  bool get isActive => _active;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(debugLabel: 'DosMenuBar');
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Active la barre (évite le nom `activate` réservé par State).
  void focusBar({int index = 0}) {
    if (widget.items.isEmpty) return;
    setState(() {
      _active = true;
      _selected = index.clamp(0, widget.items.length - 1);
    });
    _focus.requestFocus();
  }

  /// Désactive la barre et libère le focus pour le menu principal.
  void blurBar({bool notify = true}) {
    final hadControl = _active || _focus.hasFocus;
    if (_active) {
      setState(() => _active = false);
    }
    if (_focus.hasFocus) {
      _focus.unfocus();
    }
    if (notify && hadControl) {
      widget.onBlur?.call();
    }
  }

  bool tryHotkey(LogicalKeyboardKey key, {required bool altPressed}) {
    if (!altPressed || widget.items.isEmpty) return false;
    final label = key.keyLabel;
    if (label.length != 1) return false;
    final letter = label.toUpperCase();
    for (final item in widget.items) {
      if (item.hotkey?.toUpperCase() == letter) {
        final action = item.onSelect;
        blurBar();
        action();
        return true;
      }
    }
    return false;
  }

  void _move(int delta) {
    if (widget.items.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % widget.items.length;
      if (_selected < 0) _selected += widget.items.length;
    });
  }

  void _selectCurrent() {
    if (widget.items.isEmpty) return;
    final action = widget.items[_selected].onSelect;
    blurBar();
    action();
  }

  KeyEventResult handleKey(KeyEvent event) {
    if (!_active || event is! KeyDownEvent) return KeyEventResult.ignored;
    if (widget.items.isEmpty) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _selectCurrent();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        blurBar();
        return KeyEventResult.handled;
      default:
        final label = event.logicalKey.keyLabel;
        if (label.length == 1) {
          final letter = label.toUpperCase();
          for (var i = 0; i < widget.items.length; i++) {
            if (widget.items[i].hotkey?.toUpperCase() == letter) {
              setState(() => _selected = i);
              _selectCurrent();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) => handleKey(event);

  Widget _buildLabel(DosMenuBarItem item, bool selected) {
    final hot = item.hotkey?.toUpperCase();
    final label = item.label.toUpperCase();
    final baseColor = selected ? DosColors.highlightText : DosColors.text;
    final style = DosTheme.text(
      size: 14,
      weight: FontWeight.bold,
      color: baseColor,
    );

    if (hot == null || hot.isEmpty) {
      return Text(' $label ', style: style);
    }

    final idx = label.indexOf(hot);
    if (idx < 0) {
      return Text(' $label ', style: style);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: ' '),
          if (idx > 0) TextSpan(text: label.substring(0, idx)),
          TextSpan(
            text: label[idx],
            style: const TextStyle(
              color: DosColors.warning,
              decoration: TextDecoration.underline,
              decorationColor: DosColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (idx + 1 < label.length)
            TextSpan(text: label.substring(idx + 1)),
          const TextSpan(text: ' '),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onFocusKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          color: DosColors.backgroundAlt,
          border: Border(
            top: BorderSide(color: DosColors.border, width: 1),
            bottom: BorderSide(color: DosColors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < widget.items.length; i++) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: (_active && i == _selected)
                    ? DosColors.highlight
                    : Colors.transparent,
                child: _buildLabel(
                  widget.items[i],
                  _active && i == _selected,
                ),
              ),
              if (i < widget.items.length - 1)
                Text('│', style: DosTheme.dim(size: 14)),
            ],
            const Spacer(),
            Text(
              _active ? '←→ Entrée  Esc' : widget.hint,
              style: DosTheme.dim(size: 11),
            ),
          ],
        ),
      ),
    );
  }
}
