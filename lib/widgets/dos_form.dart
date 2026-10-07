import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../utils/keyboard_guard.dart';

class DosFormField {
  DosFormField({
    required this.label,
    required this.controller,
    this.required = false,
    this.obscure = false,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.digitsOnly = false,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final bool obscure;
  final int? maxLength;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Chiffres uniquement (0-9), y compris sur clavier physique Windows.
  final bool digitsOnly;

  /// Texte d'aide quand le champ est vide.
  final String? hint;
}

/// Formulaire navigable Tab/↑↓ Entrée Échap.
class DosForm extends StatefulWidget {
  const DosForm({
    super.key,
    required this.fields,
    required this.onSubmit,
    this.onCancel,
    this.submitLabel = 'VALIDER [ENTRÉE]',
    this.onExtraKey,
  });

  final List<DosFormField> fields;
  final void Function(Map<String, String> values) onSubmit;
  final VoidCallback? onCancel;
  final String submitLabel;
  /// Callback pour les touches non gérées par le formulaire (ex: F5–F9).
  /// Retourne true si la touche a été traitée.
  final bool Function(LogicalKeyboardKey key)? onExtraKey;

  @override
  State<DosForm> createState() => _DosFormState();
}

class _DosFormState extends State<DosForm> {
  int _activeIndex = 0;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.fields.length, (i) {
      final node = FocusNode(
        onKeyEvent: (node, event) => _handleFieldKey(i, event),
      );
      node.addListener(() {
        if (node.hasFocus && mounted) {
          setState(() => _activeIndex = i);
        }
      });
      return node;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = <String, String>{};
    for (final field in widget.fields) {
      final v = field.controller.text.trim();
      if (field.required && v.isEmpty) {
        _showError('Champ obligatoire: ${field.label}');
        return;
      }
      values[field.label] = v;
    }
    KeyboardGuard.suppress();
    widget.onSubmit(values);
  }

  void _cancel() {
    KeyboardGuard.suppress();
    widget.onCancel?.call();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: DosTheme.text()),
        backgroundColor: DosColors.backgroundAlt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _moveField(int delta) {
    final next = (_activeIndex + delta).clamp(0, widget.fields.length - 1);
    setState(() => _activeIndex = next);
    _focusNodes[next].requestFocus();
  }

  KeyEventResult _handleFieldKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.f10) {
      _submit();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveField(-1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveField(1);
      return KeyEventResult.handled;
    }

    // Tab : laisser Flutter passer au champ suivant (1 seul FocusNode = 1 Tab)
    // Entrée : même comportement que Tab / valider
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (index == widget.fields.length - 1) {
        _submit();
        return KeyEventResult.handled;
      }
      _moveField(1);
      return KeyEventResult.handled;
    }

    // Déléguer au parent les touches non gérées (ex: F5–F9 d'une page).
    if (widget.onExtraKey != null) {
      final handled = widget.onExtraKey!(event.logicalKey);
      if (handled) return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(widget.fields.length, (i) {
          final field = widget.fields[i];
          final active = i == _activeIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    '${field.required ? '*' : ' '}${field.label}:',
                    style: DosTheme.text(
                      weight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    focusNode: _focusNodes[i],
                    controller: field.controller,
                    obscureText: field.obscure,
                    maxLength: field.maxLength,
                    keyboardType: field.keyboardType,
                    inputFormatters: field.inputFormatters ??
                        (field.digitsOnly
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null),
                    textInputAction: i == widget.fields.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onTap: () => setState(() => _activeIndex = i),
                    onEditingComplete: () {
                      if (i == widget.fields.length - 1) {
                        _submit();
                      } else {
                        _moveField(1);
                      }
                    },
                    style: DosTheme.text(),
                    cursorColor: DosColors.text,
                    decoration: InputDecoration(
                      hintText: field.hint,
                      hintStyle: DosTheme.dim(size: 14),
                      counterText: '',
                      filled: true,
                      fillColor: active
                          ? DosColors.highlight
                          : DosColors.backgroundAlt,
                      enabledBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: DosColors.border, width: 1),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: DosColors.text, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(widget.submitLabel, style: DosTheme.dim()),
        Text('ÉCHAP: Annuler | TAB/↑↓: Champs | F10: Valider',
            style: DosTheme.dim(size: 12)),
      ],
    );
  }
}
