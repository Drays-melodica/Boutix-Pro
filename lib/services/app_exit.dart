import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Ferme proprement STORA sur Windows (et autres plateformes desktop).
class AppExit {
  AppExit._();

  static Future<void> quit() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.setFullScreen(false);
        await windowManager.close();
        await windowManager.destroy();
      } catch (_) {
        // Ignorer si la fenêtre est déjà fermée.
      }
      exit(0);
    } else {
      await SystemNavigator.pop();
    }
  }
}
