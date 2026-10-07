import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/permissions.dart';
import '../../theme/dos_theme.dart';
import '../../utils/keyboard_guard.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart';
import '../../widgets/dos_table.dart';
import 'adjust_stock_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _searchCtrl = TextEditingController();
  final _tableKey = GlobalKey<DosTableState>();
  List<Product> _products = [];
  bool _lowStockOnly = false;
  int _threshold = 5;
  int _selected = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _threshold = await DatabaseHelper.instance.getLowStockThreshold();
    final rows = await DatabaseHelper.instance.getProducts(
      search: _searchCtrl.text,
      lowStockOnly: _lowStockOnly,
    );
    rows.sort((a, b) {
      final c = a.stock.compareTo(b.stock);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    setState(() {
      _products = rows;
      _status =
          '${rows.length} article(s) — seuil: $_threshold — filtre stock bas: ${_lowStockOnly ? 'OUI' : 'NON'}';
      _selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.focusTable();
    });
  }

  Future<void> _adjust() async {
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

  void _toggleLowStock() {
    setState(() => _lowStockOnly = !_lowStockOnly);
    _load();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f3:
        _toggleLowStock();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        _adjust();
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
      title: 'STOCK RÉEL',
      subtitle: 'Quantités actuelles et ajustements — clavier uniquement',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'F3: Filtre stock bas | F6: Ajuster | F5: Actualiser | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'NIVEAUX DE STOCK',
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
                headers: const ['ARTICLE', 'CATÉGORIE', 'STOCK', 'CODE-BARRES'],
                rows: _products
                    .map((p) => [
                          p.name,
                          p.category,
                          '${p.stock}',
                          p.barcode,
                        ])
                    .toList(),
                onSelectionChanged: (i) {
                  if (_selected == i) return;
                  setState(() => _selected = i);
                },
                onSelect: (_) => _adjust(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
