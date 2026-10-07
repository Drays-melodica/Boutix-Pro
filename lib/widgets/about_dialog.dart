import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_version.dart';
import '../theme/boutix_brand.dart';
import '../theme/dos_theme.dart';
import '../utils/dos_modal_route.dart';
import '../utils/keyboard_guard.dart';
import 'boutix_logo.dart';

class BoutixAboutDialog {
  static Future<void> show(BuildContext context) {
    return pushDosModal<void>(
      context,
      (_) => const _AboutDialogBody(),
    );
  }
}

class _AboutDialogBody extends StatefulWidget {
  const _AboutDialogBody();

  @override
  State<_AboutDialogBody> createState() => _AboutDialogBodyState();
}

class _AboutDialogBodyState extends State<_AboutDialogBody> {
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

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    KeyboardGuard.suppress();
    Navigator.of(context, rootNavigator: true).pop();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.escape:
        _close();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560,
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(color: DosColors.border, width: 2),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BoutixLogo(height: 80),
                const SizedBox(height: 12),
                Text('À PROPOS — ${BoutixBrand.name}',
                    style: DosTheme.title(size: 18)),
                Text('Version ${AppVersion.label}',
                    style: DosTheme.text(color: DosColors.warning)),
                const SizedBox(height: 12),
                Text(BoutixBrand.slogan, style: DosTheme.text()),
                Text(BoutixBrand.tagline, style: DosTheme.dim()),
                const SizedBox(height: 12),
                Text(BoutixBrand.licenseTitle,
                    style: DosTheme.text(color: DosColors.warning)),
                ...BoutixBrand.licenseLines.map(
                  (l) => Text('• $l', style: DosTheme.dim(size: 13)),
                ),
                const SizedBox(height: 12),
                Text('Développeur: ${BoutixBrand.developer}',
                    style: DosTheme.dim()),
                Text(BoutixBrand.website,
                    style: DosTheme.text(color: DosColors.success)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: DosColors.backgroundAlt,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Text('[ENTRÉE] Fermer', style: DosTheme.text()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ENTRÉE ou ECHAP pour fermer.',
                  style: DosTheme.dim(size: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
