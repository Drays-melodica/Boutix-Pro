import 'package:flutter/material.dart';

/// Indique si le focus est sur un champ de saisie (TextField, etc.).
bool isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null) return false;

  final context = focus.context;
  if (context == null) return false;

  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}
