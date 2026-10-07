import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sound_service.dart';
import '../theme/dos_theme.dart';
import '../utils/dos_modal_route.dart';
import '../utils/keyboard_guard.dart';

/// Boîte de dialogue modale style DOS.
class DosDialog {
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OUI [O]',
    String cancelLabel = 'NON [N]',
  }) {
    return pushDosModal<bool>(
      context,
      (_) => _DosDialogWidget(
        title: title,
        message: message,
        actions: [
          _DialogAction('O', confirmLabel, true),
          _DialogAction('N', cancelLabel, false),
        ],
      ),
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return pushDosModal<void>(
      context,
      (_) => _DosDialogWidget(
        title: title,
        message: message,
        actions: [
          _DialogAction('ENTREE', 'OK [ENTRÉE]', null),
        ],
      ),
    );
  }

  /// Confirmation d'ajout / enregistrement : bip puis dialogue.
  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    SoundService.instance.beepOk();
    return info(context, title: title, message: message);
  }

  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return pushDosModal<void>(
      context,
      (_) => _DosDialogWidget(
        title: title,
        message: message,
        isError: true,
        actions: [
          _DialogAction('ENTREE', 'OK [ENTRÉE]', null),
        ],
      ),
    );
  }
}

class _DialogAction {
  _DialogAction(this.key, this.label, this.value);
  final String key;
  final String label;
  final bool? value;
}

class _DosDialogWidget extends StatefulWidget {
  const _DosDialogWidget({
    required this.title,
    required this.message,
    required this.actions,
    this.isError = false,
  });

  final String title;
  final String message;
  final List<_DialogAction> actions;
  final bool isError;

  @override
  State<_DosDialogWidget> createState() => _DosDialogWidgetState();
}

class _DosDialogWidgetState extends State<_DosDialogWidget> {
  int _selected = 0;
  late final FocusNode _focusNode;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _activate(int index) {
    if (_closing || !mounted) return;
    _closing = true;
    KeyboardGuard.suppress();
    final action = widget.actions[index];
    Navigator.of(context, rootNavigator: true).pop(action.value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        setState(() {
          _selected = (_selected - 1).clamp(0, widget.actions.length - 1);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        setState(() {
          _selected = (_selected + 1).clamp(0, widget.actions.length - 1);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _activate(_selected);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_closing || !mounted) return KeyEventResult.handled;
        _closing = true;
        KeyboardGuard.suppress();
        Navigator.of(context, rootNavigator: true).pop(false);
        return KeyEventResult.handled;
      default:
        final label = event.logicalKey.keyLabel.toUpperCase();
        for (var i = 0; i < widget.actions.length; i++) {
          final key = widget.actions[i].key;
          if (key == label ||
              (label == 'O' && key == 'O') ||
              (label == 'N' && key == 'N')) {
            _activate(i);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final singleAction = widget.actions.length == 1;

    return Center(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(
                color: widget.isError ? DosColors.error : DosColors.border,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: DosTheme.title(
                    size: 18,
                  ).copyWith(
                    color: widget.isError ? DosColors.error : DosColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.message, style: DosTheme.text()),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(widget.actions.length, (i) {
                    final selected = i == _selected;
                    return _DialogButton(
                      label: widget.actions[i].label,
                      selected: selected,
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    singleAction
                        ? 'ENTRÉE: fermer | ECHAP: fermer'
                        : '←→: choix | ENTRÉE: valider | O/N | ECHAP: annuler',
                    style: DosTheme.dim(size: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        color: selected ? DosColors.highlight : DosColors.backgroundAlt,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          style: DosTheme.text(
            weight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? DosColors.highlightText : DosColors.text,
          ),
        ),
      ),
    );
  }
}

/// Message flash en bas d'écran.
class DosMessage extends StatelessWidget {
  const DosMessage({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: DosColors.backgroundAlt,
      child: Text(
        text,
        style: DosTheme.text(color: color ?? DosColors.success),
      ),
    );
  }
}
