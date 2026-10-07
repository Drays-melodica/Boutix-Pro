import 'package:flutter/material.dart';

import '../../services/app_exit.dart';
import '../../services/auth_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/boutix_logo.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../main_menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _quitApp() async {
    final quit = await DosDialog.confirm(
      context,
      title: 'Quitter',
      message: 'Voulez-vous vraiment quitter BOUTIX PRO ?',
    );
    if (quit == true) await AppExit.quit();
  }

  Future<void> _submit(Map<String, String> values) async {
    try {
      await AuthService.instance.login(
        values['IDENTIFIANT']!,
        values['MOT DE PASSE']!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    } catch (e) {
      if (mounted) {
        await DosDialog.error(
          context,
          title: 'Connexion',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'CONNEXION BOUTIX PRO',
      subtitle: 'Authentification requise — Cyber Ops Console',
      captureKeyboard: false,
      helpLines: const [
        'Saisissez vos identifiants | F10: Connexion | ECHAP: Quitter',
      ],
      child: DosBox(
        title: 'IDENTIFICATION',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BoutixLogo(height: 72),
            const SizedBox(height: 12),
            Text(
              'Système sécurisé — gestion boutique & caisse.',
              style: DosTheme.dim(),
            ),
            const SizedBox(height: 16),
            DosForm(
              submitLabel: 'SE CONNECTER',
              onSubmit: _submit,
              onCancel: _quitApp,
              fields: [
                DosFormField(
                  label: 'IDENTIFIANT',
                  controller: _usernameCtrl,
                  required: true,
                ),
                DosFormField(
                  label: 'MOT DE PASSE',
                  controller: _passwordCtrl,
                  required: true,
                  obscure: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
