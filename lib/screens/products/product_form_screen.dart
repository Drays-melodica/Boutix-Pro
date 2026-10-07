import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/barcode_print_service.dart';
import '../../services/product_barcode_helper.dart';
import '../../theme/dos_theme.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_optional_picker.dart';
import '../../widgets/dos_screen.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _purchaseCtrl = TextEditingController();
  final _saleCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _supplierPickerKey = GlobalKey<DosOptionalPickerState<int>>();

  int? _supplierId;
  List<({int id, String name})> _suppliers = [];

  bool _isNew = true;
  String _existingBarcode = '';

  List<DosPickerOption<int>> get _supplierOptions => [
        const DosPickerOption<int>(value: null, label: '— Aucun —'),
        ..._suppliers.map(
          (s) => DosPickerOption<int>(value: s.id, label: s.name),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _isNew = widget.productId == null;
    _load();
  }

  Future<void> _load() async {
    final sups = await DatabaseHelper.instance.getSuppliers();
    _suppliers = sups.map((s) => (id: s.id!, name: s.name)).toList();

    if (widget.productId != null) {
      final p = await DatabaseHelper.instance.getProductById(widget.productId!);
      if (p != null) {
        _nameCtrl.text = p.name;
        _categoryCtrl.text = p.category;
        _sizeCtrl.text = p.size;
        _colorCtrl.text = p.color;
        _purchaseCtrl.text = p.purchasePrice.toString();
        _saleCtrl.text = p.salePrice.toString();
        _stockCtrl.text = p.stock.toString();
        _existingBarcode = p.barcode;
        _barcodeCtrl.text = p.barcode;
        _supplierId = p.supplierId;
      }
    } else {
      _categoryCtrl.text = 'Général';
      _stockCtrl.text = '0';
      _barcodeCtrl.text = await ProductBarcodeHelper.nextUniqueBarcode();
    }

    if (_supplierId != null &&
        !_suppliers.any((s) => s.id == _supplierId)) {
      _supplierId = null;
    }

    if (mounted) setState(() {});
  }

  Future<void> _submit(Map<String, String> values) async {
    final now = DateTime.now();
    var barcode = _isNew
        ? (values['CODE-BARRES'] ?? '').trim()
        : _existingBarcode;
    if (_isNew && barcode.isEmpty) {
      barcode = await ProductBarcodeHelper.nextUniqueBarcode();
    }

    final product = Product(
      id: widget.productId,
      name: values['NOM']!,
      category: values['CATÉGORIE'] ?? '',
      size: values['TAILLE'] ?? '',
      color: values['COULEUR'] ?? '',
      purchasePrice:
          double.tryParse(values['PRIX ACHAT']?.replaceAll(',', '.') ?? '0') ??
              0,
      salePrice:
          double.tryParse(values['PRIX VENTE']?.replaceAll(',', '.') ?? '0') ??
              0,
      stock: int.tryParse(values['STOCK'] ?? '0') ?? 0,
      barcode: barcode,
      supplierId: _supplierId,
      createdAt: now,
      updatedAt: now,
    );

    if (widget.productId == null) {
      final dup = await DatabaseHelper.instance.getProductByBarcode(barcode);
      if (dup != null) {
        if (!mounted) return;
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: 'Le code-barres existe déjà. Réessayez.',
        );
        _barcodeCtrl.text = await ProductBarcodeHelper.nextUniqueBarcode();
        setState(() {});
        return;
      }
      int? newId;
      try {
        newId = await DatabaseHelper.instance.insertProduct(product);
      } catch (e) {
        if (!mounted) return;
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
        return;
      }

      // Proposer l'impression du code-barres
      if (mounted && barcode.isNotEmpty) {
        final print = await DosDialog.confirm(
          context,
          title: 'Étiquette code-barres',
          message:
              'Article enregistré.\n\n'
              'Imprimer l\'étiquette code-barres de « ${product.name} » ?',
          confirmLabel: 'OUI [O]',
          cancelLabel: 'NON [N]',
        );
        if (print == true && mounted) {
          try {
            final currency = await DatabaseHelper.instance.getCurrency();
            await BarcodePrintService.instance.printBarcode(
              productName: product.name,
              barcode: barcode,
              salePrice: product.salePrice,
              currency: currency,
            );
          } catch (e) {
            if (mounted) {
              await DosDialog.error(
                context,
                title: 'Impression',
                message: e.toString().replaceFirst('Exception: ', ''),
              );
            }
          }
        }
      }
    } else {
      final existing =
          await DatabaseHelper.instance.getProductById(widget.productId!);
      await DatabaseHelper.instance.updateProduct(product.copyWith(
        id: widget.productId,
        barcode: _existingBarcode,
        createdAt: existing?.createdAt ?? now,
        supplierId: _supplierId,
        clearSupplier: _supplierId == null,
      ));
    }
    if (mounted) guardedPop(context, true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _sizeCtrl.dispose();
    _colorCtrl.dispose();
    _purchaseCtrl.dispose();
    _saleCtrl.dispose();
    _stockCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: widget.productId == null ? 'NOUVEL ARTICLE' : 'MODIFIER ARTICLE',
      captureKeyboard: false,
      popOnEscape: false,
      helpLines: const [
        'FOURNISSEUR: optionnel | ↑↓ pour choisir',
        'F10: Enregistrer | ECHAP: Annuler',
      ],
      child: DosBox(
        title: 'FICHE ARTICLE',
        expand: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isNew)
                Text(
                  'Code-barres auto: ${_barcodeCtrl.text}',
                  style: DosTheme.text(color: DosColors.success, size: 13),
                )
              else
                Text(
                  'Code-barres: $_existingBarcode (lecture seule)',
                  style: DosTheme.dim(size: 13),
                ),
              const SizedBox(height: 8),
              DosOptionalPicker<int>(
                key: _supplierPickerKey,
                label: 'FOURNISSEUR',
                options: _supplierOptions,
                value: _supplierId,
                onChanged: (v) => setState(() => _supplierId = v),
                onEscape: () => guardedPop(context),
                emptyHint: '— Aucun — (ajoutez des fournisseurs au menu Fournisseurs)',
              ),
              if (_suppliers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Aucun fournisseur en base — le champ reste optionnel.',
                    style: DosTheme.dim(size: 12),
                  ),
                ),
              DosForm(
                submitLabel: 'ENREGISTRER',
                onSubmit: _submit,
                onCancel: () => guardedPop(context),
                fields: [
                  DosFormField(label: 'NOM', controller: _nameCtrl, required: true),
                  DosFormField(label: 'CATÉGORIE', controller: _categoryCtrl),
                  DosFormField(label: 'TAILLE', controller: _sizeCtrl),
                  DosFormField(label: 'COULEUR', controller: _colorCtrl),
                  DosFormField(label: 'PRIX ACHAT', controller: _purchaseCtrl),
                  DosFormField(
                    label: 'PRIX VENTE',
                    controller: _saleCtrl,
                    required: true,
                  ),
                  DosFormField(
                    label: 'STOCK',
                    controller: _stockCtrl,
                    digitsOnly: true,
                  ),
                  if (_isNew)
                    DosFormField(
                      label: 'CODE-BARRES',
                      controller: _barcodeCtrl,
                      hint: 'Généré automatiquement si vide',
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
