import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/focus_utils.dart';
import '../utils/nav_utils.dart';
import 'dos_status_bar.dart';

/// Écran de base plein écran style BIOS/DOS.
class DosScreen extends StatefulWidget {
  const DosScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.helpLines = const [],
    this.onKey,
    this.focusNode,
    this.captureKeyboard = true,
    this.popOnEscape = false,
    this.requestScreenFocus,
    this.menuBar,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<String> helpLines;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKey;
  final FocusNode? focusNode;
  /// Si false, ne déclenche pas onKey (sauf ECHAP si [popOnEscape]).
  final bool captureKeyboard;
  /// ECHAP revient à l'écran précédent (sauf champ de saisie actif).
  final bool popOnEscape;
  /// Demande le focus clavier au montage. Par défaut: true si raccourcis actifs.
  final bool? requestScreenFocus;
  final Widget? menuBar;

  bool get shouldRequestScreenFocus =>
      requestScreenFocus ?? (captureKeyboard && onKey != null);

  @override
  State<DosScreen> createState() => _DosScreenState();
}

class _DosScreenState extends State<DosScreen> {
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  bool get _needsKeyboard =>
      widget.popOnEscape || (widget.captureKeyboard && widget.onKey != null);

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode(debugLabel: 'DosScreen');
      _ownsFocusNode = true;
    }
    if (_needsKeyboard && widget.shouldRequestScreenFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (isTextInputFocused()) return KeyEventResult.ignored;

    if (widget.captureKeyboard && widget.onKey != null) {
      final result = widget.onKey!(node, event);
      if (result != KeyEventResult.ignored) return result;
    }

    if (widget.popOnEscape && event.logicalKey == LogicalKeyboardKey.escape) {
      guardedPopRoute(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Scaffold(
      backgroundColor: DosColors.background,
      body: Column(
        children: [
          _Header(
            title: widget.title,
            subtitle: widget.subtitle,
            menuBar: widget.menuBar,
          ),
          Expanded(child: widget.child),
          DosStatusBar(helpLines: widget.helpLines),
        ],
      ),
    );

    if (widget.popOnEscape) {
      body = Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DosEscapePopIntent(),
        },
        child: Actions(
          actions: {
            DosEscapePopIntent: DosEscapePopAction(context),
          },
          child: body,
        ),
      );
    }

    if (!_needsKeyboard) return body;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.shouldRequestScreenFocus,
      canRequestFocus: widget.shouldRequestScreenFocus,
      skipTraversal: !widget.shouldRequestScreenFocus,
      onKeyEvent: _handleKey,
      child: body,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.menuBar});

  final String title;
  final String? subtitle;
  final Widget? menuBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DosColors.backgroundAlt,
        border: Border(
          bottom: BorderSide(color: DosColors.border, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '╔══ BOUTIX PRO ════════════════════════════════════════════════════════╗',
              style: DosTheme.dim(size: 12),
            ),
          ),
          if (menuBar != null) menuBar!,
          Padding(
            padding: EdgeInsets.fromLTRB(16, menuBar != null ? 4 : 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: DosTheme.title(size: 22),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: DosTheme.dim(size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cadre avec bordure ASCII.
class DosBox extends StatelessWidget {
  const DosBox({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(12),
    this.expand = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: DosColors.border, width: 1),
        color: DosColors.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: DosColors.border, width: 1),
                ),
              ),
              child: Text(' $title ',
                  style: DosTheme.text(weight: FontWeight.bold)),
            ),
          if (expand) Expanded(child: body) else body,
        ],
      ),
    );
  }
}
