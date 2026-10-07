import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../theme/dos_theme.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';

class AdjustStockScreen extends StatefulWidget {
  const AdjustStockScreen({super.key, this.productId});

  final int? productId;

  @override
  State<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends State<AdjustStockScreen> {
  final _stockCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Product> _products = [];
  int _productIndex = 0;
  String _productLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _products = await DatabaseHelper.instance.getProducts();
    if (widget.productId != null) {
      final i = _products.indexWhere((p) => p.id == widget.productId);
      _productIndex = i >= 0 ? i : 0;
    } else {
      _productIndex = 0;
    }
    await _refreshLabel();
    if (mounted) setState(() {});
  }

  int? get _selectedProductId =>
      _products.isEmpty ? null : _products[_productIndex.clamp(0, _products.length - 1)].id;

  Future<void> _refreshLabel() async {
    final id = _selectedProductId;
    if (id == null) {
      _productLabel = '';
      _stockCtrl.text = '0';
      return;
    }
    final p = await DatabaseHelper.instance.getProductById(id);
    if (p != null) {
      _productLabel = '${p.name} (actuel: ${p.stock})';
      _stockCtrl.text = p.stock.toString();
    }
  }

  Future<void> _cycleProduct(int delta) async {
    if (_products.length <= 1) return;
    setState(() {
      _productIndex = (_productIndex + delta) % _products.length;
      if (_productIndex < 0) _productIndex += _products.length;
    });
    await _refreshLabel();
    if (mounted) setState(() {});
  }

  Future<void> _submit(Map<String, String> values) async {
    final id = _selectedProductId;
    if (id == null) return;
    final newStock = int.tryParse(values['NOUVEAU STOCK'] ?? '') ?? 0;
    final user = AuthService.instance.currentUser;
    await DatabaseHelper.instance.adjustStock(
      productId: id,
      newStock: newStock,
      userId: user?.id,
      note: values['NOTE'] ?? '',
    );
    if (mounted) guardedPop(context, true);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f7:
        _cycleProduct(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f8:
        _cycleProduct(1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'AJUSTEMENT DE STOCK',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: false,
      onKey: _handleKey,
      helpLines: const [
        'F7/F8: Article précédent/suivant | F10: Valider | ECHAP: Annuler',
      ],
      child: DosBox(
        title: 'AJUSTEMENT MANUEL',
        expand: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _products.isEmpty
                  ? 'Aucun article.'
                  : 'Article: $_productLabel',
              style: DosTheme.text(weight: FontWeight.bold),
            ),
            if (_products.length > 1)
              Text(
                'Article ${_productIndex + 1}/${_products.length}',
                style: DosTheme.dim(size: 12),
              ),
            const SizedBox(height: 12),
            DosForm(
              submitLabel: 'VALIDER AJUSTEMENT',
              onSubmit: _submit,
              onCancel: () => guardedPop(context),
              fields: [
                DosFormField(
                  label: 'NOUVEAU STOCK',
                  controller: _stockCtrl,
                  required: true,
                  digitsOnly: true,
                ),
                DosFormField(label: 'NOTE', controller: _noteCtrl),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
