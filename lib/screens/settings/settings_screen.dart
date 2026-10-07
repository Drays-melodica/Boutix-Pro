import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:printing/printing.dart';

import '../../database/database_helper.dart';
import '../../services/permissions.dart';
import '../../services/pos_cart_session.dart';
import '../../services/printer_config_service.dart';
import '../../theme/dos_theme.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_optional_picker.dart';
import '../../widgets/dos_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shopNameCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  String _status = '';

  // Imprimantes
  List<Printer> _printers = [];
  String? _receiptPrinterName; // null = auto
  String? _barcodePrinterName; // null = non configurée

  List<DosPickerOption<String>> get _receiptPrinterOptions => [
        const DosPickerOption<String>(
            value: null, label: '(auto — défaut Windows)'),
        ..._printers.map((p) => DosPickerOption<String>(
              value: p.name,
              label:
                  '${p.name}  ${p.isAvailable ? '✓' : '✗'}${p.isDefault ? ' [défaut]' : ''}',
            )),
      ];

  List<DosPickerOption<String>> get _barcodePrinterOptions => [
        const DosPickerOption<String>(
            value: null, label: '(non configurée)'),
        ..._printers.map((p) => DosPickerOption<String>(
              value: p.name,
              label:
                  '${p.name}  ${p.isAvailable ? '✓' : '✗'}${p.isDefault ? ' [défaut]' : ''}',
            )),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    _shopNameCtrl.text = await db.getSetting('shop_name', 'Ma Boutique');
    _shopPhoneCtrl.text = await db.getSetting('shop_phone', '');
    _shopAddressCtrl.text = await db.getSetting('shop_address', '');
    final tva = await db.getTvaRate();
    _tvaCtrl.text = (tva * 100).toString();
    _lowStockCtrl.text = await db.getSetting('low_stock_threshold', '5');
    _currencyCtrl.text = await db.getSetting('currency_label', 'DA');
    _logoCtrl.text = await db.getSetting('logo_path', '');

    final receiptName =
        await PrinterConfigService.instance.getReceiptPrinterName();
    final barcodeName =
        await PrinterConfigService.instance.getBarcodePrinterName();
    _receiptPrinterName = receiptName.isEmpty ? null : receiptName;
    _barcodePrinterName = barcodeName.isEmpty ? null : barcodeName;

    _printers = await Printing.listPrinters();
    if (mounted) setState(() {});
  }

  Future<void> _submit(Map<String, String> values) async {
    final db = DatabaseHelper.instance;
    await db.setSetting('shop_name', values['NOM BOUTIQUE'] ?? '');
    await db.setSetting('shop_phone', values['TÉLÉPHONE'] ?? '');
    await db.setSetting('shop_address', values['ADRESSE'] ?? '');
    final tvaPct =
        double.tryParse(values['TVA %']?.replaceAll(',', '.') ?? '0') ?? 0;
    await db.setSetting('tva_rate', (tvaPct / 100).toString());
    await db.setSetting(
        'low_stock_threshold', values['SEUIL STOCK BAS'] ?? '5');
    await db.setSetting('currency_label', values['DEVISE'] ?? 'DA');
    await db.setSetting('logo_path', values['LOGO (CHEMIN)']?.trim() ?? '');
    _logoCtrl.text = values['LOGO (CHEMIN)']?.trim() ?? '';

    await PrinterConfigService.instance
        .saveReceiptPrinter(_receiptPrinterName ?? '');
    await PrinterConfigService.instance
        .saveBarcodePrinter(_barcodePrinterName ?? '');

    setState(() => _status = 'Paramètres enregistrés.');
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result?.files.single.path != null) {
      setState(() {
        _logoCtrl.text = result!.files.single.path!;
        _status = 'Logo sélectionné — enregistrez avec F10.';
      });
    }
  }

  Future<void> _exportDb() async {
    if (!Permissions.canManageDatabase) return;
    try {
      setState(() => _status = 'Export de la base…');
      final path = await DatabaseHelper.instance.exportDatabaseDefault();
      if (!mounted) return;
      setState(() => _status = 'Export OK — $path');
      await DosDialog.info(
        context,
        title: 'Export base',
        message:
            'Base exportée (conservez ce fichier hors du PC):\n\n$path\n\n'
            'À la 1re utilisation après formatage: F7 Restaurer.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur export: $e');
      await DosDialog.error(context, title: 'Export', message: e.toString());
    }
  }

  Future<void> _restoreDb() async {
    if (!Permissions.canManageDatabase) return;
    final ok = await DosDialog.confirm(
      context,
      title: 'Restaurer la base',
      message:
          'Remplacer TOUTE la base actuelle par un fichier .db exporté ?\n'
          'Cette action est irréversible (sauf si vous avez un autre export).',
    );
    if (ok != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choisir une base BOUTIX (.db)',
        type: FileType.custom,
        allowedExtensions: const ['db'],
      );
      final path = result?.files.single.path;
      if (path == null) return;

      setState(() => _status = 'Restauration…');
      await DatabaseHelper.instance.restoreDatabase(path);
      PosCartSession.instance.clear();
      await _load();
      if (!mounted) return;
      setState(() => _status = 'Base restaurée — $path');
      await DosDialog.info(
        context,
        title: 'Restauration',
        message: 'Base restaurée.\nReconnectez-vous si nécessaire.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur restauration: $e');
      await DosDialog.error(
        context,
        title: 'Restauration',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _purgeSales() async {
    if (!Permissions.canManageDatabase) return;
    final confirm1 = await DosDialog.confirm(
      context,
      title: 'Purge annuelle',
      message:
          'Effacer TOUTES les ventes et recommencer à zéro pour la nouvelle année ?\n\n'
          'Conservé: articles, stocks, fournisseurs, utilisateurs, paramètres.\n'
          'Supprimé: historique des ventes et mouvements liés aux ventes.',
    );
    if (confirm1 != true) return;
    if (!mounted) return;

    final confirm2 = await DosDialog.confirm(
      context,
      title: 'Confirmation',
      message: 'Dernière confirmation: purger les ventes maintenant ?',
      confirmLabel: 'OUI PURGER [O]',
      cancelLabel: 'ANNULER [N]',
    );
    if (confirm2 != true) return;

    try {
      setState(() => _status = 'Purge en cours…');
      final r = await DatabaseHelper.instance.purgeSalesHistory();
      PosCartSession.instance.clear();
      if (!mounted) return;
      setState(() =>
          _status = 'Purge OK — ${r.sales} vente(s), ${r.items} ligne(s).');
      await DosDialog.info(
        context,
        title: 'Purge annuelle',
        message:
            'Ventes effacées: ${r.sales}\n'
            'Lignes effacées: ${r.items}\n'
            'Mouvements vente: ${r.movements}\n\n'
            'Articles et stocks inchangés.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur purge: $e');
      await DosDialog.error(context, title: 'Purge', message: e.toString());
    }
  }

  bool _handleExtraKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.f6:
        _purgeSales();
        return true;
      case LogicalKeyboardKey.f7:
        _restoreDb();
        return true;
      case LogicalKeyboardKey.f8:
        _pickLogo();
        return true;
      case LogicalKeyboardKey.f9:
        _exportDb();
        return true;
      default:
        return false;
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final handled = _handleExtraKey(event.logicalKey);
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _tvaCtrl.dispose();
    _lowStockCtrl.dispose();
    _currencyCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'PARAMÈTRES',
      subtitle: 'Boutique, imprimantes, logo, base de données — clavier',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: false,
      onKey: _handleKey,
      helpLines: const [
        'F10: Enregistrer | F8: Logo | F9: Export DB | F7: Restaurer | F6: Purge',
      ],
      child: DosBox(
        title: 'CONFIGURATION',
        expand: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status.isNotEmpty)
                Text(_status,
                    style: DosTheme.text(color: DosColors.success)),

              // ── Champs boutique ──
              DosForm(
                submitLabel: 'ENREGISTRER',
                onSubmit: _submit,
                onCancel: () => guardedPop(context),
                onExtraKey: _handleExtraKey,
                fields: [
                  DosFormField(
                      label: 'NOM BOUTIQUE',
                      controller: _shopNameCtrl,
                      required: true),
                  DosFormField(
                      label: 'TÉLÉPHONE', controller: _shopPhoneCtrl),
                  DosFormField(
                      label: 'ADRESSE', controller: _shopAddressCtrl),
                  DosFormField(label: 'TVA %', controller: _tvaCtrl),
                  DosFormField(
                      label: 'SEUIL STOCK BAS',
                      controller: _lowStockCtrl,
                      digitsOnly: true),
                  DosFormField(
                      label: 'DEVISE', controller: _currencyCtrl),
                  DosFormField(
                    label: 'LOGO (CHEMIN)',
                    controller: _logoCtrl,
                    hint: 'Vide = logo BOUTIX',
                  ),
                ],
              ),

              // ── Imprimante ticket de caisse (picker ↑↓) ──
              DosOptionalPicker<String>(
                label: 'IMPR. TICKET',
                options: _receiptPrinterOptions,
                value: _receiptPrinterName,
                onChanged: (v) => setState(() => _receiptPrinterName = v),
                onEscape: () => guardedPop(context),
                emptyHint: 'Aucune imprimante détectée',
              ),

              // ── Imprimante code-barres (picker ↑↓) ──
              DosOptionalPicker<String>(
                label: 'IMPR. ÉTIQUETTES',
                options: _barcodePrinterOptions,
                value: _barcodePrinterName,
                onChanged: (v) => setState(() => _barcodePrinterName = v),
                onEscape: () => guardedPop(context),
                emptyHint: 'Aucune imprimante détectée',
              ),

              // ── Base de données ──
              const SizedBox(height: 12),
              Text('── BASE DE DONNÉES ──',
                  style:
                      DosTheme.text(weight: FontWeight.bold, size: 13)),
              Text('Exporter → Documents\\Boutix\\exports',
                  style: DosTheme.dim(size: 12)),
              Text('Restaurer une base .db exportée',
                  style: DosTheme.dim(size: 12)),
              Text(
                  'Purge annuelle (ventes) — conserve articles & stocks',
                  style: DosTheme.dim(size: 12)),
              const SizedBox(height: 8),
              Text(
                'Base: ${DatabaseHelper.instance.databaseFile}',
                style: DosTheme.dim(size: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
