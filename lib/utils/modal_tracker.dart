import 'package:flutter/foundation.dart';

import 'keyboard_guard.dart';

/// Compte les fenêtres modales ouvertes (dialogues, etc.).
class ModalTracker {
  ModalTracker._();

  static final openCount = ValueNotifier<int>(0);

  static bool get hasModal => openCount.value > 0;

  static void onShow() => openCount.value++;

  static void onHide() {
    if (openCount.value > 0) openCount.value--;
  }

  static Future<T> track<T>(Future<T> future) {
    onShow();
    return future.whenComplete(() {
      onHide();
      KeyboardGuard.suppress();
    });
  }
}
