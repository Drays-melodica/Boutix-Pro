import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import '../../services/app_exit.dart';
import '../../services/auth_service.dart';
import '../../services/password_hasher.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/boutix_logo.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../auth/login_screen.dart';
import '../main_menu_screen.dart';

/// Première utilisation : créer admin OU restaurer une base exportée.
class FirstRunSetupScreen extends StatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  State<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends State<FirstRunSetupScreen> {
  /// null = choix, 'create' = formulaire admin+boutique
  String? _mode;

  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _shopNameCtrl = TextEditingController(text: 'Ma Boutique');
  final _shopPhoneCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'DA');
  final _tvaCtrl = TextEditingController(text: '0');

  String _status = '';
  bool _busy = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _currencyCtrl.dispose();
    _tvaCtrl.dispose();
    super.dispose();
  }

  Future<void> _quit() async {
    final quit = await DosDialog.confirm(
      context,
      title: 'Quitter',
      message: 'Quitter sans terminer la configuration ?',
    );
    if (quit == true) await AppExit.quit();
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Sélection du fichier .db…';
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Restaurer une base BOUTIX',
        type: FileType.custom,
        allowedExtensions: const ['db'],
      );
      final path = result?.files.single.path;
      if (path == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _status = '';
          });
        }
        return;
      }

      setState(() => _status = 'Restauration en cours…');
      await DatabaseHelper.instance.restoreDatabase(path);

      final stillEmpty = await DatabaseHelper.instance.needsFirstRunSetup();
      if (!mounted) return;
      if (stillEmpty) {
        setState(() {
          _busy = false;
          _status =
              'Base restaurée mais aucun utilisateur trouvé. Créez un admin.';
          _mode = 'create';
        });
        await DosDialog.error(
          context,
          title: 'Restauration',
          message:
              'Le fichier a été restauré, mais aucun compte n\'existe. Créez l\'administrateur.',
        );
        return;
      }

      await DosDialog.info(
        context,
        title: 'Restauration',
        message:
            'Base restaurée avec succès.\nConnectez-vous avec un compte existant.',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Erreur: $e';
      });
      await DosDialog.error(
        context,
        title: 'Restauration',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _submit(Map<String, String> values) async {
    final username = (values['IDENTIFIANT'] ?? '').trim();
    final password = values['MOT DE PASSE'] ?? '';
    final password2 = values['CONFIRMER MDP'] ?? '';
    final shopName = (values['NOM BOUTIQUE'] ?? '').trim();

    if (username.length < 3) {
      await DosDialog.error(
        context,
        title: 'Configuration',
        message: 'Identifiant trop court (3 caractères min.).',
      );
      return;
    }
    if (password.length < 4) {
      await DosDialog.error(
        context,
        title: 'Configuration',
        message: 'Mot de passe trop court (4 caractères min.).',
      );
      return;
    }
    if (password != password2) {
      await DosDialog.error(
        context,
        title: 'Configuration',
        message: 'Les mots de passe ne correspondent pas.',
      );
      return;
    }
    if (shopName.isEmpty) {
      await DosDialog.error(
        context,
        title: 'Configuration',
        message: 'Le nom de la boutique est obligatoire.',
      );
      return;
    }

    try {
      final (hash, salt) = PasswordHasher.create(password);
      final user = AppUser(
        username: username,
        passwordHash: hash,
        passwordSalt: salt,
        role: 'admin',
        fullName: (values['NOM COMPLET'] ?? '').trim().isEmpty
            ? null
            : values['NOM COMPLET']!.trim(),
        active: true,
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertUser(user);

      final db = DatabaseHelper.instance;
      await db.setSetting('shop_name', shopName);
      await db.setSetting('shop_phone', (values['TÉLÉPHONE'] ?? '').trim());
      await db.setSetting('shop_address', (values['ADRESSE'] ?? '').trim());
      await db.setSetting(
        'currency_label',
        (values['DEVISE'] ?? 'DA').trim().isEmpty
            ? 'DA'
            : (values['DEVISE'] ?? 'DA').trim(),
      );
      final tvaPct =
          double.tryParse((values['TVA %'] ?? '0').replaceAll(',', '.')) ?? 0;
      await db.setSetting('tva_rate', (tvaPct / 100).toString());
      await db.setSetting('setup_completed', '1');

      await AuthService.instance.login(username, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur: $e');
      await DosDialog.error(
        context,
        title: 'Configuration',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  KeyEventResult _handleChoiceKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _busy) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f2:
        setState(() => _mode = 'create');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f7:
        _restoreBackup();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _quit();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == null) {
      return DosScreen(
        title: 'CONFIGURATION INITIALE',
        subtitle: 'Première utilisation — nouvelle boutique ou restauration',
        captureKeyboard: true,
        requestScreenFocus: true,
        popOnEscape: false,
        onKey: _handleChoiceKey,
        helpLines: const [
          'F2: Nouvelle configuration | F7: Restaurer une base | ECHAP: Quitter',
        ],
        child: DosBox(
          title: 'CHOIX DE DÉMARRAGE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BoutixLogo(height: 72),
              const SizedBox(height: 16),
              Text(
                'Aucun compte trouvé sur ce PC.',
                style: DosTheme.text(weight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('NOUVELLE CONFIGURATION', style: DosTheme.text()),
              Text(
                '    Créer l\'administrateur et les infos boutique.',
                style: DosTheme.dim(size: 13),
              ),
              const SizedBox(height: 10),
              Text('RESTAURER UNE BASE EXPORTÉE', style: DosTheme.text()),
              Text(
                '    Après formatage / nouveau PC — fichier .db BOUTIX.',
                style: DosTheme.dim(size: 13),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_status, style: DosTheme.dim(size: 13)),
              ],
            ],
          ),
        ),
      );
    }

    return DosScreen(
      title: 'NOUVELLE CONFIGURATION',
      subtitle: 'Créez l\'administrateur et la boutique',
      captureKeyboard: false,
      popOnEscape: false,
      helpLines: const [
        'F10: Valider et démarrer | ECHAP: Retour au choix',
      ],
      child: DosBox(
        title: 'ASSISTANT DE DÉMARRAGE',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BoutixLogo(height: 64),
              const SizedBox(height: 8),
              if (_status.isNotEmpty) ...[
                Text(_status,
                    style: DosTheme.text(color: DosColors.error, size: 13)),
                const SizedBox(height: 8),
              ],
              Text('── COMPTE ADMINISTRATEUR + BOUTIQUE ──',
                  style: DosTheme.text(weight: FontWeight.bold, size: 13)),
              const SizedBox(height: 8),
              DosForm(
                submitLabel: 'TERMINER LA CONFIGURATION',
                onSubmit: _submit,
                onCancel: () => setState(() {
                  _mode = null;
                  _status = '';
                }),
                fields: [
                  DosFormField(
                    label: 'IDENTIFIANT',
                    controller: _usernameCtrl,
                    required: true,
                  ),
                  DosFormField(
                    label: 'NOM COMPLET',
                    controller: _fullNameCtrl,
                  ),
                  DosFormField(
                    label: 'MOT DE PASSE',
                    controller: _passwordCtrl,
                    required: true,
                    obscure: true,
                  ),
                  DosFormField(
                    label: 'CONFIRMER MDP',
                    controller: _password2Ctrl,
                    required: true,
                    obscure: true,
                  ),
                  DosFormField(
                    label: 'NOM BOUTIQUE',
                    controller: _shopNameCtrl,
                    required: true,
                  ),
                  DosFormField(
                    label: 'TÉLÉPHONE',
                    controller: _shopPhoneCtrl,
                  ),
                  DosFormField(
                    label: 'ADRESSE',
                    controller: _shopAddressCtrl,
                  ),
                  DosFormField(
                    label: 'DEVISE',
                    controller: _currencyCtrl,
                  ),
                  DosFormField(
                    label: 'TVA %',
                    controller: _tvaCtrl,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
