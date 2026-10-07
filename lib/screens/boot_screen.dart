import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_version.dart';
import '../database/database_helper.dart';
import '../theme/boutix_brand.dart';
import '../theme/dos_theme.dart';
import '../widgets/dos_dialog.dart';
import '../widgets/dos_screen.dart';
import '../widgets/boutix_logo.dart';
import 'auth/first_run_setup_screen.dart';
import 'auth/login_screen.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final List<String> _lines = [];
  int _lineIndex = 0;
  Timer? _timer;
  late final FocusNode _focusNode;
  bool _bootComplete = false;
  bool _continuing = false;
  String? _statusLine;

  static const _bootLines = [
    AppVersion.bootLine,
    'Copyright (C) 2026 IDRISS EL-HIMER',
    '',
    BoutixBrand.licenseTitle,
    ...BoutixBrand.licenseLines,
    '',
    'Initialisation du système...',
    'Vérification mémoire.................. OK',
    'Chargement base de données locale..... ...',
    'Module authentification............... OK',
    'Configuration clavier................. OK',
    'Mode plein écran...................... OK',
    '',
    'Appuyez sur une touche pour continuer...',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'BootScreen');
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    // Pré-charge la base pendant l'animation BIOS.
    unawaited(_warmupDatabase());

    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_lineIndex < _bootLines.length) {
        setState(() {
          _lines.add(_bootLines[_lineIndex]);
          _lineIndex++;
        });
        if (_lineIndex >= _bootLines.length) {
          _timer?.cancel();
          _markBootComplete();
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _warmupDatabase() async {
    try {
      await DatabaseHelper.instance.database;
      if (!mounted) return;
      setState(() => _statusLine = 'Base de données prête.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = 'Erreur base: $e');
    }
  }

  void _markBootComplete() {
    setState(() => _bootComplete = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  bool _onGlobalKey(KeyEvent event) {
    if (!_bootComplete || _continuing) return false;
    if (event is! KeyDownEvent) return false;
    unawaited(_continue());
    return true;
  }

  KeyEventResult _onFocusKey(FocusNode node, KeyEvent event) {
    if (!_bootComplete || _continuing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    unawaited(_continue());
    return KeyEventResult.handled;
  }

  Future<void> _continue() async {
    if (!_bootComplete || _continuing) return;
    _continuing = true;
    setState(() => _statusLine = 'Chargement...');

    try {
      await DatabaseHelper.instance.database;
      if (!mounted) return;
      final needsSetup = await DatabaseHelper.instance.needsFirstRunSetup();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => needsSetup
              ? const FirstRunSetupScreen()
              : const LoginScreen(),
        ),
      );
    } catch (e) {
      _continuing = false;
      if (!mounted) return;
      setState(() => _statusLine = 'Erreur: $e');
      await DosDialog.error(
        context,
        title: 'Démarrage',
        message: 'Impossible d\'initialiser la base de données:\n$e',
      );
      if (mounted) _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onFocusKey,
      child: DosScreen(
        title: 'SYSTEM BOOT',
        captureKeyboard: false,
        helpLines: [
          if (_bootComplete)
            'ENTRÉE / ESPACE : continuer'
          else
            'Initialisation en cours...',
        ],
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BoutixLogo(height: 96, alignment: Alignment.centerLeft),
              const SizedBox(height: 12),
              Text('BOUTIX PRO', style: DosTheme.title(size: 32)),
              const SizedBox(height: 24),
              ..._lines.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l, style: DosTheme.text()),
                ),
              ),
              if (_bootComplete) const _BlinkingCursor(),
              if (_statusLine != null) ...[
                const SizedBox(height: 8),
                Text(_statusLine!, style: DosTheme.dim(size: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _visible ? '_' : ' ',
      style: DosTheme.text(size: 18),
    );
  }
}
