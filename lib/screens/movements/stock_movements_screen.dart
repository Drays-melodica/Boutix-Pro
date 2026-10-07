import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../services/permissions.dart';
import '../../theme/dos_theme.dart';
import '../../utils/keyboard_guard.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';
import '../stock/adjust_stock_screen.dart';

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final _tableKey = GlobalKey<DosTableState>();
  List<Map<String, Object?>> _rows = [];
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getStockMovements();
    setState(() {
      _rows = rows;
      _status = '${rows.length} mouvement(s).';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.focusTable();
    });
  }

  Future<void> _adjust() async {
    if (!Permissions.canAdjustStock) return;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdjustStockScreen()),
    );
    KeyboardGuard.suppress();
    if (ok == true) await _load();
  }

  String _formatReason(String reason) {
    if (reason == 'sale') return 'Vente';
    if (reason.startsWith('adjust:')) return 'Ajustement: ${reason.substring(7)}';
    if (reason == 'adjust') return 'Ajustement';
    return reason;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
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
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'MOUVEMENTS DE STOCK',
      subtitle: 'Historique des mouvements — clavier uniquement',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'F6: Ajustement manuel | F5: Actualiser | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'JOURNAL DES MOUVEMENTS',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status.isNotEmpty) Text(_status, style: DosTheme.dim(size: 13)),
            Expanded(
              child: DosTable(
                key: _tableKey,
                headers: const ['DATE', 'ARTICLE', 'DELTA', 'MOTIF', 'VENTE'],
                rows: _rows
                    .map((m) => [
                          _dateFmt.format(
                              DateTime.parse(m['created_at'] as String)),
                          m['product_name'] as String? ?? '?',
                          '${m['qty_delta']}',
                          _formatReason(m['reason'] as String),
                          '${m['ref_sale_id'] ?? ''}',
                        ])
                    .toList(),
                emptyMessage: 'Aucun mouvement enregistré.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
