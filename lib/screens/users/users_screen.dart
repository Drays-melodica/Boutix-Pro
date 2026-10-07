import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/password_hasher.dart';
import '../../theme/dos_theme.dart';
import '../../utils/keyboard_guard.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _tableKey = GlobalKey<DosTableState>();
  final _resetPassCtrl = TextEditingController();
  late final FocusNode _resetPassFocus;
  List<AppUser> _users = [];
  int _selected = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _resetPassFocus = FocusNode(
      debugLabel: 'ResetPasswordField',
      onKeyEvent: _handleResetPasswordKey,
    );
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getAllUsers();
    setState(() {
      _users = rows;
      _selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
      _status = '${rows.length} compte(s).';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.focusTable();
    });
  }

  Future<void> _add() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _UserFormScreen()),
    );
    KeyboardGuard.suppress();
    if (ok == true) await _load();
  }

  Future<void> _edit() async {
    if (_users.isEmpty) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _UserFormScreen(user: _users[_selected])),
    );
    KeyboardGuard.suppress();
    if (ok == true) await _load();
  }

  Future<void> _toggleActive() async {
    if (_users.isEmpty) return;
    final u = _users[_selected];
    if (u.id == AuthService.instance.currentUser?.id) {
      setState(() => _status = 'Vous ne pouvez pas modifier votre propre compte.');
      return;
    }
    await DatabaseHelper.instance.updateUser(u.copyWith(active: !u.active));
    await _load();
    setState(() => _status = 'Statut mis à jour.');
  }

  Future<void> _resetPassword() async {
    if (_users.isEmpty) return;
    if (_resetPassCtrl.text.length < 4) {
      setState(() => _status = 'Mot de passe trop court (4 car. min.).');
      return;
    }
    final u = _users[_selected];
    final (hash, salt) = PasswordHasher.create(_resetPassCtrl.text);
    await DatabaseHelper.instance.updateUser(u.copyWith(
      passwordHash: hash,
      passwordSalt: salt,
    ));
    _resetPassCtrl.clear();
    setState(() => _status = 'Mot de passe mis à jour pour « ${u.username} ».');
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f2:
        _add();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f3:
        _edit();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f4:
        _toggleActive();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        _resetPassword();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleResetPasswordKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        guardedPopRoute(context);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f2:
        _add();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f3:
        _edit();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f4:
        _toggleActive();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        _resetPassword();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _resetPassCtrl.dispose();
    _resetPassFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'UTILISATEURS',
      subtitle: 'Gestion des comptes et sécurité — clavier uniquement',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'F2: Ajouter | F3: Modifier | F4: Activer/Désactiver | F6: Réinit. MDP | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'COMPTES UTILISATEURS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status.isNotEmpty) Text(_status, style: DosTheme.dim(size: 13)),
            Expanded(
              child: DosTable(
                key: _tableKey,
                headers: const ['IDENTIFIANT', 'RÔLE', 'NOM', 'ACTIF'],
                rows: _users
                    .map((u) => [
                          u.username,
                          u.roleLabel,
                          u.fullName ?? '',
                          u.active ? 'OUI' : 'NON',
                        ])
                    .toList(),
                onSelectionChanged: (i) {
                  if (_selected == i) return;
                  setState(() => _selected = i);
                },
                onSelect: (_) => _edit(),
              ),
            ),
            Text('Nouveau MDP:', style: DosTheme.dim(size: 12)),
            TextField(
              focusNode: _resetPassFocus,
              onTapOutside: (_) {},
              controller: _resetPassCtrl,
              obscureText: true,
              onSubmitted: (_) => _resetPassword(),
              style: DosTheme.text(size: 13),
              decoration: const InputDecoration(
                isDense: true,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: DosColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: DosColors.text, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserFormScreen extends StatefulWidget {
  const _UserFormScreen({this.user});
  final AppUser? user;

  @override
  State<_UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<_UserFormScreen> {
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'cashier';

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _usernameCtrl.text = u.username;
      _fullNameCtrl.text = u.fullName ?? '';
      _role = u.role;
    }
  }

  void _toggleRole() {
    setState(() => _role = _role == 'admin' ? 'cashier' : 'admin');
  }

  Future<void> _submit(Map<String, String> values) async {
    if (widget.user == null) {
      if ((values['MOT DE PASSE'] ?? '').length < 4) {
        await DosDialog.error(context, title: 'Erreur', message: 'Mot de passe trop court.');
        return;
      }
      final (hash, salt) = PasswordHasher.create(values['MOT DE PASSE']!);
      final user = AppUser(
        username: values['IDENTIFIANT']!.trim(),
        passwordHash: hash,
        passwordSalt: salt,
        role: _role,
        fullName: values['NOM COMPLET'],
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertUser(user);
    } else {
      final u = widget.user!;
      var updated = u.copyWith(
        username: values['IDENTIFIANT']!.trim(),
        fullName: values['NOM COMPLET'],
        role: _role,
      );
      if ((values['MOT DE PASSE'] ?? '').isNotEmpty) {
        final (hash, salt) = PasswordHasher.create(values['MOT DE PASSE']!);
        updated = updated.copyWith(passwordHash: hash, passwordSalt: salt);
      }
      await DatabaseHelper.instance.updateUser(updated);
    }
    if (mounted) guardedPop(context, true);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.f8) {
      _toggleRole();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: widget.user == null ? 'NOUVEL UTILISATEUR' : 'MODIFIER UTILISATEUR',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: false,
      onKey: _handleKey,
      helpLines: const ['F8: Changer rôle | F10: Enregistrer | ECHAP: Annuler'],
      child: DosBox(
        title: 'FICHE UTILISATEUR',
        expand: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sélecteur de rôle visuel ──
            Text('RÔLE', style: DosTheme.text(weight: FontWeight.bold, size: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                _RoleChip(
                  label: 'Caissier',
                  value: 'cashier',
                  current: _role,
                  onTap: () => setState(() => _role = 'cashier'),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: 'Administrateur',
                  value: 'admin',
                  current: _role,
                  onTap: () => setState(() => _role = 'admin'),
                ),
                const SizedBox(width: 12),
                Text('[F8: basculer]', style: DosTheme.dim(size: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _role == 'admin'
                  ? '⚠ Admin : accès complet à tous les menus et paramètres.'
                  : 'Caissier : accès caisse, articles, stock, ventes. Pas de paramètres.',
              style: DosTheme.dim(size: 11),
            ),
            const SizedBox(height: 14),
            // ── Formulaire ──
            DosForm(
              submitLabel: 'ENREGISTRER',
              onSubmit: _submit,
              onCancel: () => guardedPop(context),
              onExtraKey: (key) {
                if (key == LogicalKeyboardKey.f8) {
                  _toggleRole();
                  return true;
                }
                return false;
              },
              fields: [
                DosFormField(
                  label: 'IDENTIFIANT',
                  controller: _usernameCtrl,
                  required: true,
                ),
                DosFormField(label: 'NOM COMPLET', controller: _fullNameCtrl),
                DosFormField(
                  label: 'MOT DE PASSE',
                  controller: _passwordCtrl,
                  required: widget.user == null,
                  obscure: true,
                  hint: widget.user != null ? '(laisser vide pour ne pas changer)' : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Chip visuel de sélection de rôle
class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? DosColors.highlight : DosColors.backgroundAlt,
          border: Border.all(
            color: selected ? DosColors.highlight : DosColors.border,
          ),
        ),
        child: Text(
          label,
          style: DosTheme.text(
            size: 13,
            weight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? DosColors.highlightText : DosColors.text,
          ),
        ),
      ),
    );
  }
}
