/// Bloque brièvement les raccourcis de navigation après une fermeture de
/// dialogue ou d'écran, pour éviter un double « pop » vers le menu général.
class KeyboardGuard {
  KeyboardGuard._();

  static DateTime? _until;

  static void suppress([Duration duration = const Duration(milliseconds: 500)]) {
    final next = DateTime.now().add(duration);
    if (_until == null || next.isAfter(_until!)) {
      _until = next;
    }
  }

  static bool get isActive {
    final until = _until;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _until = null;
    return false;
  }
}
