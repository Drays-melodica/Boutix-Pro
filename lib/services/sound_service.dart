import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

/// Bip système (Windows MessageBeep / fallback Flutter).
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool _ready = false;
  int Function(int)? _messageBeep;

  void _ensureWindows() {
    if (_ready || !Platform.isWindows) return;
    _ready = true;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      _messageBeep = user32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
        'MessageBeep',
      );
    } catch (_) {
      _messageBeep = null;
    }
  }

  /// Bip d'ajout manuel (liste raccourcis).
  void beepOk() {
    _ensureWindows();
    final beep = _messageBeep;
    if (beep != null) {
      // MB_OK = 0 → bip simple Windows
      beep(0);
      return;
    }
    SystemSound.play(SystemSoundType.click);
  }
}
