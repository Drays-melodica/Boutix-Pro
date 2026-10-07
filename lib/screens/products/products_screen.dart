import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/barcode_print_service.dart';
import '../../services/permissions.dart';
import '../../utils/keyboard_guard.dart';
import '../../utils/nav_utils.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart';
import '../../widgets/dos_table.dart';
import 'product_form_screen.dart';
import '../stock/adjust_stock_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  final _tableKey = GlobalKey<DosTableState>();
  List<Product> _products = [];
  List<String> _categories = [];
  String _filterCategory = '';
  bool _lowStockOnly = false;
  String _status = '';
  int _selected = 0;
  final _fmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _categories = await DatabaseHelper.instance.getCategories();
      final rows = await DatabaseHelper.instance.getProducts(
        search: _searchCtrl.text,
        category: _filterCategory,
        lowStockOnly: _lowStockOnly,
      );
      rows.sort((a, b) => b.id!.compareTo(a.id!));
      if (!mounted) return;
      setState(() {
        _products = rows;
        _status = '${rows.length} article(s).';
        _selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tableKey.currentState?.focusTable();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _status = 'Erreur chargement: $e';
      });
    }
  }

  Future<void> _add() async {
    if (!Permissions.canEditProducts) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    KeyboardGuard.suppress();
    if (ok == true) {
      _searchCtrl.clear();
      _filterCategory = '';
      _lowStockOnly = false;
      await _load();
      if (!mounted) return;
      setState(() => _status = 'Article ajouté.');
      _tableKey.currentState?.focusTable();
    }
  }

  Future<void> _edit() async {
    if (!Permissions.canEditProducts || _products.isEmpty) return;
    final p = _products[_selected];
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(productId: p.id)),
    );
    KeyboardGuard.suppress();
    if (ok == true) {
      await _load();
      if (!mounted) return;
      setState(() => _status = 'Article mis à jour.');
      _tableKey.currentState?.focusTable();
    }
  }

  Future<void> _delete() async {
    if (!Permissions.canDeleteProducts || _products.isEmpty) return;
    final p = _products[_selected];
    final ok = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer « ${p.name} » ?',
    );
    if (ok != true) return;
    KeyboardGuard.suppress();
    try {
      await DatabaseHelper.instance.deleteProduct(p.id!);
      await _load();
      setState(() => _status = 'Article supprimé.');
      _tableKey.currentState?.focusTable();
    } catch (e) {
      await DosDialog.error(context, title: 'Erreur', message: e.toString());
    }
  }

  Future<void> _adjustStock() async {
    if (!Permissions.canAdjustStock || _products.isEmpty) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdjustStockScreen(productId: _products[_selected].id),
      ),
    );
    KeyboardGuard.suppress();
    if (ok == true) await _load();
  }

  Future<void> _printBarcode() async {
    if (_products.isEmpty) return;
    final p = _products[_selected];
    if (p.barcode.trim().isEmpty) {
      await DosDialog.error(
        context,
        title: 'Impression',
        message: 'Cet article n\'a pas de code-barres.',
      );
      return;
    }
    final currency = await DatabaseHelper.instance.getCurrency();
    try {
      setState(() => _status = 'Impression étiquette…');
      await BarcodePrintService.instance.printBarcode(
        productName: p.name,
        barcode: p.barcode,
        salePrice: p.salePrice,
        currency: currency,
      );
      if (!mounted) return;
      setState(() => _status = 'Étiquette imprimée: ${p.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur impression: $e');
      await DosDialog.error(
        context,
        title: 'Impression',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
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
        _delete();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        _adjustStock();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f11:
        _printBarcode();
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
      title: 'ARTICLES / CATALOGUE',
      subtitle: 'Catalogue, fournisseurs, stock et codes-barres',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'RECH> ↓ : tableau | F2: Ajouter | F3: Modifier | F4: Supprimer',
        'F5: Actualiser | F6: Ajuster stock | F11: Impr. code-barres | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'LISTE DES ARTICLES',
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
            Row(
              children: [
                Text('Catégorie:', style: DosTheme.dim(size: 12)),
                const SizedBox(width: 8),
                Text(
                  _filterCategory.isEmpty ? 'Toutes' : _filterCategory,
                  style: DosTheme.text(size: 12),
                ),
                const SizedBox(width: 16),
                Text(
                  _lowStockOnly ? '[FILTRE: stock bas]' : '',
                  style: DosTheme.dim(size: 12),
                ),
              ],
            ),
            Expanded(
              child: DosTable(
                key: _tableKey,
                headers: const ['NOM', 'CAT.', 'PRIX', 'STOCK', 'CODE-BARRES'],
                rows: _products
                    .map((p) => [
                          p.name,
                          p.category,
                          _fmt.format(p.salePrice),
                          '${p.stock}',
                          p.barcode,
                        ])
                    .toList(),
                initialIndex: _selected,
                onSelectionChanged: (i) {
                  if (_selected == i) return;
                  setState(() => _selected = i);
                },
                onSelect: (_) => _edit(),
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
