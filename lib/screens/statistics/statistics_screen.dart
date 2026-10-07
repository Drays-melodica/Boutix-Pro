import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? _kpis;
  List<Map<String, Object?>> _topProducts = [];
  List<Map<String, Object?>> _lowStock = [];
  List<Map<String, Object?>> _lastSales = [];
  String _currency = 'DA';
  final _fmt = NumberFormat('#,##0.00', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    _currency = await db.getCurrency();
    final kpis = await db.getDashboardKpis();
    final top = await db.getTopProducts30d();
    final low = await db.getLowStockProducts();
    final sales = await db.listSales(limit: 10);

    setState(() {
      _kpis = kpis;
      _topProducts = top;
      _lowStock = low;
      _lastSales = sales;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      _load();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final k = _kpis;
    final ventesToday = k?['ventes_today'] as int? ?? 0;
    final caToday = (k?['ca_today'] as num?)?.toDouble() ?? 0;
    final panierMoyen = ventesToday > 0 ? caToday / ventesToday : 0.0;

    return DosScreen(
      title: 'STATISTIQUES',
      subtitle: 'Vue admin : KPI, top produits, alertes stock',
      captureKeyboard: true,
      requestScreenFocus: true,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const ['F5: Actualiser | ECHAP: Retour'],
      child: Row(
        children: [
          Expanded(
            child: DosBox(
              title: 'INDICATEURS CLÉS',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('CA aujourd\'hui', '${_fmt.format(caToday)} $_currency'),
                    _line('Ventes aujourd\'hui', '$ventesToday'),
                    _line('Panier moyen', '${_fmt.format(panierMoyen)} $_currency'),
                    _line('CA du mois', '${_fmt.format(k?['ca_month'] ?? 0)} $_currency'),
                    _line('Ventes du mois', '${k?['ventes_month'] ?? 0}'),
                    _line('Articles catalogue', '${k?['products_count'] ?? 0}'),
                    _line('Alertes stock bas', '${k?['low_stock_count'] ?? 0}',
                        alert: (k?['low_stock_count'] as int? ?? 0) > 0),
                    const SizedBox(height: 12),
                    Text('TOP PRODUITS (30j)',
                        style: DosTheme.text(weight: FontWeight.bold)),
                    ..._topProducts.map((p) => Text(
                          '• ${p['name']} — ${p['qty']} unités',
                          style: DosTheme.dim(size: 12),
                        )),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: DosBox(
              title: 'ALERTES & DERNIÈRES VENTES',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STOCKS FAIBLES',
                        style: DosTheme.text(weight: FontWeight.bold)),
                    ..._lowStock.map((p) => Text(
                          '⚠ ${p['name']} — ${p['stock']} restant(s)',
                          style: DosTheme.text(
                            size: 12,
                            color: DosColors.warning,
                          ),
                        )),
                    if (_lowStock.isEmpty)
                      Text('Aucune alerte.', style: DosTheme.dim(size: 12)),
                    const SizedBox(height: 12),
                    Text('DERNIÈRES VENTES',
                        style: DosTheme.text(weight: FontWeight.bold)),
                    ..._lastSales.map((s) => Text(
                          '#${s['id']} — ${_dateFmt.format(DateTime.parse(s['created_at'] as String))} — ${_fmt.format(s['total_ttc'])} $_currency',
                          style: DosTheme.dim(size: 12),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool alert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text('$label:', style: DosTheme.text(size: 13))),
          Text(
            value,
            style: DosTheme.text(
              size: 13,
              weight: FontWeight.bold,
              color: alert ? DosColors.warning : DosColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
