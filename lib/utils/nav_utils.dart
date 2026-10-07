import 'package:flutter/material.dart';

import 'focus_utils.dart';
import 'keyboard_guard.dart';
import 'modal_tracker.dart';

/// Ferme l'écran courant en bloquant la propagation clavier résiduelle.
void guardedPop<T>(BuildContext context, [T? result]) {
  KeyboardGuard.suppress();
  Navigator.pop(context, result);
}

/// Retour menu précédent (liste) — une seule fois, sans double pop.
void guardedPopRoute(BuildContext context) {
  if (ModalTracker.hasModal || KeyboardGuard.isActive) return;
  if (isTextInputFocused()) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return;
  guardedPop(context);
}

class DosEscapePopIntent extends Intent {
  const DosEscapePopIntent();
}

/// Raccourci ECHAP pour revenir en arrière sans double navigation.
class DosEscapePopAction extends Action<DosEscapePopIntent> {
  DosEscapePopAction(this.context);

  final BuildContext context;

  @override
  Object? invoke(DosEscapePopIntent intent) {
    guardedPopRoute(context);
    return null;
  }
}
