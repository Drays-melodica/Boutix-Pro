import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/supplier.dart';
import '../../services/permissions.dart';
import '../../theme/dos_theme.dart';
import '../../utils/keyboard_guard.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart';
import '../../widgets/dos_table.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  final _tableKey = GlobalKey<DosTableState>();
  List<Supplier> _suppliers = [];
  int _selected = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var rows = await DatabaseHelper.instance.getSuppliers();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              (s.phone ?? '').toLowerCase().contains(q) ||
              (s.email ?? '').toLowerCase().contains(q))
          .toList();
    }
    setState(() {
      _suppliers = rows;
      _status = '${rows.length} fournisseur(s).';
      _selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.focusTable();
    });
  }

  Future<void> _openForm({Supplier? supplier}) async {
    if (!Permissions.canEditProducts) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SupplierFormScreen(supplier: supplier),
      ),
    );
    KeyboardGuard.suppress();
    if (ok == true) await _load();
  }

  Future<void> _delete() async {
    if (!Permissions.canEditProducts || _suppliers.isEmpty) return;
    final s = _suppliers[_selected];
    final ok = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer le fournisseur « ${s.name} » ?',
    );
    if (ok != true) return;
    KeyboardGuard.suppress();
    await DatabaseHelper.instance.deleteSupplier(s.id!);
    await _load();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f2:
        _openForm();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f3:
        if (_suppliers.isNotEmpty) {
          _openForm(supplier: _suppliers[_selected]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f4:
        _delete();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'FOURNISSEURS',
      subtitle: 'Contacts et informations fournisseurs — clavier uniquement',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'F2: Ajouter | F3: Modifier | F4: Supprimer | F5: Actualiser | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'LISTE FOURNISSEURS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status.isNotEmpty) Text(_status, style: DosTheme.dim(size: 13)),
            DosSearchBar(
              controller: _searchCtrl,
              onChanged: (_) => _load(),
              onMoveDown: () => _tableKey.currentState?.focusTable(),
              onEscape: () => guardedPopRoute(context),
            ),
            Expanded(
              child: DosTable(
                key: _tableKey,
                headers: const ['NOM', 'TÉLÉPHONE', 'EMAIL', 'ADRESSE'],
                rows: _suppliers
                    .map((s) => [
                          s.name,
                          s.phone ?? '',
                          s.email ?? '',
                          s.address ?? '',
                        ])
                    .toList(),
                onSelectionChanged: (i) {
                  if (_selected == i) return;
                  setState(() => _selected = i);
                },
                onSelect: (_) => _openForm(supplier: _suppliers[_selected]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierFormScreen extends StatefulWidget {
  const _SupplierFormScreen({this.supplier});
  final Supplier? supplier;

  @override
  State<_SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<_SupplierFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.address ?? '';
      _notesCtrl.text = s.notes ?? '';
    }
  }

  Future<void> _submit(Map<String, String> values) async {
    final supplier = Supplier(
      id: widget.supplier?.id,
      name: values['NOM']!,
      phone: values['TÉLÉPHONE'],
      email: values['EMAIL'],
      address: values['ADRESSE'],
      notes: values['NOTES'],
      createdAt: widget.supplier?.createdAt ?? DateTime.now(),
    );
    if (widget.supplier == null) {
      await DatabaseHelper.instance.insertSupplier(supplier);
    } else {
      await DatabaseHelper.instance.updateSupplier(supplier);
    }
    if (mounted) guardedPop(context, true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: widget.supplier == null ? 'NOUVEAU FOURNISSEUR' : 'MODIFIER FOURNISSEUR',
      captureKeyboard: false,
      popOnEscape: false,
      helpLines: const ['F10: Enregistrer | ECHAP: Annuler'],
      child: DosBox(
        title: 'FICHE FOURNISSEUR',
        expand: false,
        child: DosForm(
          submitLabel: 'ENREGISTRER',
          onSubmit: _submit,
          onCancel: () => guardedPop(context),
          fields: [
            DosFormField(label: 'NOM', controller: _nameCtrl, required: true),
            DosFormField(label: 'TÉLÉPHONE', controller: _phoneCtrl),
            DosFormField(label: 'EMAIL', controller: _emailCtrl),
            DosFormField(label: 'ADRESSE', controller: _addressCtrl),
            DosFormField(label: 'NOTES', controller: _notesCtrl),
          ],
        ),
      ),
    );
  }
}
