import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';

class DosPickerOption<T> {
  const DosPickerOption({required this.value, required this.label});

  final T? value;
  final String label;
}

/// Liste déroulante clavier (↑↓) — valeur optionnelle.
class DosOptionalPicker<T> extends StatefulWidget {
  const DosOptionalPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.emptyHint = 'Aucune option disponible.',
    this.onEscape,
  });

  final String label;
  final List<DosPickerOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final FocusNode? focusNode;
  final String emptyHint;
  final VoidCallback? onEscape;

  @override
  State<DosOptionalPicker<T>> createState() => DosOptionalPickerState<T>();
}

class DosOptionalPickerState<T> extends State<DosOptionalPicker<T>> {
  late FocusNode _focus;
  late bool _ownsFocus;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode(debugLabel: 'DosOptionalPicker');
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _active = _focus.hasFocus);
  }

  void requestFocus() => _focus.requestFocus();

  int get _selectedIndex {
    if (widget.options.isEmpty) return 0;
    final idx = widget.options.indexWhere((o) => o.value == widget.value);
    return idx < 0 ? 0 : idx;
  }

  void _move(int delta) {
    if (widget.options.isEmpty) return;
    final next = (_selectedIndex + delta).clamp(0, widget.options.length - 1);
    widget.onChanged(widget.options[next].value);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
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
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onEscape?.call();
        return widget.onEscape != null
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.options.isEmpty
        ? widget.emptyHint
        : widget.options[_selectedIndex].label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              ' ${widget.label}:',
              style: DosTheme.text(
                weight: _active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Focus(
              focusNode: _focus,
              onKeyEvent: _onKey,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _active
                      ? DosColors.highlight
                      : DosColors.backgroundAlt,
                  border: Border.all(
                    color: _active ? DosColors.text : DosColors.border,
                    width: _active ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel,
                        style: DosTheme.text(
                          color: _active
                              ? DosColors.highlightText
                              : DosColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '[↑↓]',
                      style: DosTheme.text(
                        size: 11,
                        color: _active
                            ? DosColors.highlightText
                            : DosColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
