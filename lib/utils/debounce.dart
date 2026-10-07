import 'dart:async';

/// Retarde une action répétée (ex. recherche live).
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 280)});

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
