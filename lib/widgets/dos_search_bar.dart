import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/debounce.dart';

/// Barre de recherche live (filtre à chaque frappe, sans bouton).
class DosSearchBar extends StatefulWidget {
  const DosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher…',
    this.focusNode,
    this.onMoveDown,
    this.onEscape,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final FocusNode? focusNode;

  /// Flèche ↓ : passer au tableau en dessous.
  final VoidCallback? onMoveDown;
  final VoidCallback? onEscape;

  @override
  State<DosSearchBar> createState() => _DosSearchBarState();
}

class _DosSearchBarState extends State<DosSearchBar> {
  late FocusNode _focus;
  late bool _ownsFocus;
  final _debouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _focus.onKeyEvent = _onKey;
    _focus.addListener(_onFocusChange);
    widget.controller.addListener(_onText);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _notifyChanged(String value) {
    _debouncer.run(() {
      if (mounted) widget.onChanged(value);
    });
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debouncer.dispose();
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocusChange);
    _focus.onKeyEvent = null;
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onEscape != null) {
      widget.onEscape!();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onMoveDown != null) {
      widget.onMoveDown!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveDown() {
    widget.onMoveDown?.call();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;

    return CallbackShortcuts(
      bindings: {
        if (widget.onMoveDown != null)
          const SingleActivator(LogicalKeyboardKey.arrowDown): _moveDown,
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              'RECH> ',
              style: DosTheme.text(
                weight: FontWeight.bold,
                size: 14,
                color: focused ? DosColors.highlightText : DosColors.text,
              ),
            ),
            Expanded(
              child: TextField(
                focusNode: _focus,
                controller: widget.controller,
                style: DosTheme.text(
                  size: 14,
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
                onChanged: _notifyChanged,
                onTapOutside: (_) {},
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              Text(
                '[DEL efface]',
                style: DosTheme.text(
                  size: 11,
                  color: focused ? DosColors.highlightText : DosColors.textDim,
                ),
              ),
            Text(
              '  ↓',
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

/// Filtre générique insensible à la casse sur plusieurs champs texte.
bool dosMatchesQuery(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final f in fields) {
    if (f != null && f.toLowerCase().contains(q)) return true;
  }
  return false;
}
