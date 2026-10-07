import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/keyboard_guard.dart';
import '../utils/modal_tracker.dart';
import '../utils/nav_utils.dart';

/// Tableau scrollable navigable au clavier.
class DosTable extends StatefulWidget {
  const DosTable({
    super.key,
    required this.headers,
    required this.rows,
    this.onSelect,
    this.onCancel,
    this.onSelectionChanged,
    this.emptyMessage = 'Aucune donnée.',
    this.initialIndex = 0,
    this.autofocus = true,
    this.onMoveUpFromTop,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final void Function(int index)? onSelect;
  final VoidCallback? onCancel;
  final void Function(int index)? onSelectionChanged;
  final String emptyMessage;
  final int initialIndex;
  final bool autofocus;

  /// Flèche ↑ sur la 1re ligne : remonter vers la barre de recherche.
  final VoidCallback? onMoveUpFromTop;

  @override
  State<DosTable> createState() => DosTableState();
}

class DosTableState extends State<DosTable> {
  static const double _rowExtent = 28.0;

  late int _selected;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  int? _lastNotifiedIndex;

  @override
  void initState() {
    super.initState();
    _selected = _clampSelected(widget.initialIndex, widget.rows.length);
    _scrollController = ScrollController();
    _focusNode = FocusNode(debugLabel: 'DosTable');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autofocus) {
        _focusNode.requestFocus();
      }
      _notifySelection();
    });
  }

  static int _clampSelected(int index, int length) {
    if (length <= 0) return 0;
    return index.clamp(0, length - 1);
  }

  /// Donne le focus clavier au tableau (depuis la barre RECH>).
  void focusTable() {
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  int get selectedIndex => _selected;

  @override
  void didUpdateWidget(DosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _selected;
    _selected = _clampSelected(_selected, widget.rows.length);
    if (previous == _selected && oldWidget.rows.length == widget.rows.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelected(jump: true);
      if (previous != _selected) {
        _notifySelection();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _notifySelection() {
    if (_lastNotifiedIndex == _selected) return;
    _lastNotifiedIndex = _selected;
    widget.onSelectionChanged?.call(_selected);
  }

  void _move(int delta) {
    if (widget.rows.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, widget.rows.length - 1);
    });
    _scrollToSelected();
    _notifySelection();
  }

  void _scrollToSelected({bool jump = false}) {
    if (!_scrollController.hasClients || widget.rows.isEmpty) return;

    final position = _scrollController.position;
    final viewportHeight = position.viewportDimension;
    if (viewportHeight <= 0) return;

    final itemTop = _selected * _rowExtent;
    final itemBottom = itemTop + _rowExtent;
    final viewTop = position.pixels;
    final viewBottom = viewTop + viewportHeight;

    double? target;
    if (itemTop < viewTop) {
      target = itemTop;
    } else if (itemBottom > viewBottom) {
      target = itemBottom - viewportHeight;
    }

    if (target == null) return;

    target = target.clamp(0.0, position.maxScrollExtent);
    if (jump) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        if (_selected == 0 && widget.onMoveUpFromTop != null) {
          widget.onMoveUpFromTop!();
          return KeyEventResult.handled;
        }
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _move(-10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _move(10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() => _selected = 0);
        _scrollToSelected();
        _notifySelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() => _selected = widget.rows.length - 1);
        _scrollToSelected();
        _notifySelection();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (KeyboardGuard.isActive) return KeyEventResult.handled;
        if (widget.rows.isNotEmpty) {
          widget.onSelect?.call(_selected);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (ModalTracker.hasModal || KeyboardGuard.isActive) {
          return KeyEventResult.handled;
        }
        guardedPopRoute(context);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(),
          const Divider(color: DosColors.border, height: 1),
          Expanded(
            child: widget.rows.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        widget.emptyMessage,
                        style: DosTheme.text(),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemExtent: _rowExtent,
                    physics: const ClampingScrollPhysics(),
                    itemCount: widget.rows.length,
                    itemBuilder: (context, i) {
                      final selected = i == _selected;
                      return Container(
                        color:
                            selected ? DosColors.highlight : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                selected ? '►' : '',
                                style: DosTheme.text(size: 14),
                              ),
                            ),
                            Expanded(
                              child: _buildDataRow(widget.rows[i], selected),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Text(
            widget.rows.isEmpty
                ? '0 ligne'
                : 'Ligne ${_selected + 1}/${widget.rows.length}',
            style: DosTheme.dim(size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: Row(
        children: widget.headers
            .map(
              (h) => Expanded(
                child: Text(
                  h,
                  style: DosTheme.text(weight: FontWeight.bold, size: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDataRow(List<String> cells, bool selected) {
    return Row(
      children: cells
          .map(
            (c) => Expanded(
              child: Text(
                c,
                style: DosTheme.text(
                  size: 14,
                  color: selected ? DosColors.highlightText : DosColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }
}
