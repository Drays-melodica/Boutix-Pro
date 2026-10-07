import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/modal_tracker.dart';

/// Champ de scan caisse — focus permanent, Entrée = valider.
class DosBarcodeField extends StatefulWidget {
  const DosBarcodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.onArrowUp,
    this.onArrowDown,
    this.onEscapeEmpty,
    this.focusNode,
    this.hint = 'Scanner ou saisir code-barres…',
    this.prefix = 'SCAN>',
    this.keepFocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onEscapeEmpty;
  final FocusNode? focusNode;
  final String hint;
  final String prefix;
  final bool keepFocus;

  @override
  State<DosBarcodeField> createState() => DosBarcodeFieldState();
}

class DosBarcodeFieldState extends State<DosBarcodeField> {
  late FocusNode _focus;
  late bool _ownsFocus;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode(debugLabel: 'DosBarcodeField');
    widget.controller.addListener(_onText);
    if (widget.keepFocus) {
      _focus.addListener(_onFocusChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => requestFocus());
  }

  void _onFocusChange() {
    if (!widget.keepFocus || !mounted || ModalTracker.hasModal) return;
    if (!_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => requestFocus());
    }
  }

  void requestFocus() {
    if (!mounted || ModalTracker.hasModal) return;
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    if (widget.keepFocus) _focus.removeListener(_onFocusChange);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final empty = widget.controller.text.trim().isEmpty;

    if (empty && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onArrowDown?.call();
      return KeyEventResult.handled;
    }
    if (empty && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onArrowUp?.call();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onSubmitted?.call(_normalize(widget.controller.text));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (empty) {
        widget.onEscapeEmpty?.call();
      } else {
        widget.controller.clear();
        widget.onChanged('');
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  static String _normalize(String raw) =>
      raw.replaceAll(RegExp(r'[\r\n\t]'), '').trim();

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: focused ? DosColors.warning : DosColors.border,
            width: focused ? 2 : 1,
          ),
          color: focused ? DosColors.highlight : DosColors.backgroundAlt,
        ),
        child: Row(
          children: [
            Text(
              '${widget.prefix} ',
              style: DosTheme.text(
                weight: FontWeight.bold,
                size: 14,
                color: focused ? DosColors.highlightText : DosColors.text,
              ),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                autofocus: true,
                showCursor: true,
                enableInteractiveSelection: false,
                style: DosTheme.text(
                  size: 16,
                  color: focused ? DosColors.highlightText : DosColors.text,
                ),
                cursorColor: DosColors.text,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: DosTheme.dim(size: 14),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => widget.onChanged(_normalize(v)),
                onSubmitted: (v) => widget.onSubmitted?.call(_normalize(v)),
              ),
            ),
            Text(
              widget.controller.text.isNotEmpty
                  ? '[ECHAP=effacer]'
                  : '[↓↑ raccourcis | ENTREE]',
              style: DosTheme.text(
                size: 11,
                color: focused ? DosColors.highlightText : DosColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
