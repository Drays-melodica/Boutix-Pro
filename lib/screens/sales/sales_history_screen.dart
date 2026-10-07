import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/database_helper.dart';
import '../../services/permissions.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _tableKey = GlobalKey<DosTableState>();
  List<Map<String, Object?>> _rows = [];
  int _selected = 0;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  String _status = '';
  String _currency = 'DA';
  bool _exporting = false;
  final _fmt = NumberFormat('#,##0.00', 'fr_FR');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _dayFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _currency = await DatabaseHelper.instance.getCurrency();
    final rows = await DatabaseHelper.instance.listSales(
      from: _dateFrom,
      to: _dateTo,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _status = '${rows.length} ticket(s) — ${_dayFmt.format(_dateFrom)} → ${_dayFmt.format(_dateTo)}';
      _selected = rows.isEmpty ? 0 : _selected.clamp(0, rows.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableKey.currentState?.focusTable();
    });
  }

  String _formatPayment(String m) => switch (m) {
        'cash' => 'Espèces',
        'card' => 'Carte',
        'mobile' => 'Mobile',
        _ => m,
      };

  Future<void> _editDateRange() async {
    final fromCtrl = TextEditingController(text: _dayFmt.format(_dateFrom));
    final toCtrl = TextEditingController(text: _dayFmt.format(_dateTo));
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: DosColors.background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PÉRIODE', style: DosTheme.title(size: 16)),
              const SizedBox(height: 8),
              Text('Format: jj/mm/aaaa', style: DosTheme.dim(size: 12)),
              const SizedBox(height: 8),
              DosForm(
                submitLabel: 'APPLIQUER',
                onSubmit: (values) {
                  Navigator.of(ctx).pop(true);
                },
                onCancel: () => Navigator.of(ctx).pop(false),
                fields: [
                  DosFormField(label: 'DU', controller: fromCtrl, required: true),
                  DosFormField(label: 'AU', controller: toCtrl, required: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) {
      fromCtrl.dispose();
      toCtrl.dispose();
      return;
    }

    DateTime? parseDay(String s) {
      try {
        return _dayFmt.parseStrict(s.trim());
      } catch (_) {
        return null;
      }
    }

    final from = parseDay(fromCtrl.text);
    final to = parseDay(toCtrl.text);
    fromCtrl.dispose();
    toCtrl.dispose();

    if (from == null || to == null) {
      if (!mounted) return;
      await DosDialog.error(
        context,
        title: 'Période',
        message: 'Dates invalides. Utilisez jj/mm/aaaa.',
      );
      return;
    }
    setState(() {
      _dateFrom = from;
      _dateTo = to;
    });
    await _load();
  }

  Future<void> _showDetail() async {
    if (_rows.isEmpty) return;
    final row = _rows[_selected];
    final saleId = (row['id'] as num).toInt();
    final data = await DatabaseHelper.instance.getSaleWithItems(saleId);
    if (!mounted) return;
    if (data == null) {
      await DosDialog.error(
        context,
        title: 'Détail vente',
        message: 'Vente introuvable (n° $saleId).',
      );
      return;
    }

    final sale = data['sale'] as Map<String, Object?>;
    final items = data['items'] as List<Map<String, Object?>>;
    final subtotalHt = (sale['subtotal_ht'] as num?)?.toDouble() ?? 0;
    final totalTtc = (sale['total_ttc'] as num?)?.toDouble() ?? 0;
    final discountAmount = (sale['discount_amount'] as num?)?.toDouble() ?? 0;
    final discountPct = (sale['discount_pct'] as num?)?.toDouble() ?? 0;

    // Sous-total TTC avant remise (reconstitué depuis les lignes HT + TVA)
    final tvaRate = (sale['tva_rate'] as num?)?.toDouble() ?? 0;
    final subtotalTtc = subtotalHt * (1 + tvaRate);

    final sb = StringBuffer();
    sb.writeln(
        'Ticket n° $saleId — ${_dateFmt.format(DateTime.parse(sale['created_at'] as String))}');
    sb.writeln('Caissier : ${row['username'] ?? '?'}');
    sb.writeln(
        'Paiement : ${_formatPayment(sale['payment_method'] as String)}');
    sb.writeln();
    sb.writeln('── ARTICLES ACHETÉS ──');
    if (items.isEmpty) {
      sb.writeln('(aucun article enregistré)');
    } else {
      for (final it in items) {
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        final name = it['product_name'] as String? ?? 'Article';
        final lineHt = (it['line_total_ht'] as num?)?.toDouble() ?? 0;
        final unitHt = (it['unit_price_ht'] as num?)?.toDouble() ?? 0;
        final lineTtc =
            subtotalHt > 0 ? lineHt / subtotalHt * subtotalTtc : lineHt;
        final unitTtc = qty > 0 ? lineTtc / qty : unitHt;
        sb.writeln('$qty x $name');
        sb.writeln(
          '  PU ${_fmt.format(unitTtc)} | Ligne ${_fmt.format(lineTtc)} $_currency TTC',
        );
      }
    }
    sb.writeln();
    if (discountAmount > 0 || discountPct > 0) {
      sb.writeln('Sous-total : ${_fmt.format(subtotalTtc)} $_currency');
      final discLabel = discountPct > 0
          ? 'Remise ${discountPct.toStringAsFixed(1)}%'
          : 'Remise';
      sb.writeln('$discLabel : -${_fmt.format(discountAmount)} $_currency');
    }
    sb.writeln('TOTAL TTC : ${_fmt.format(totalTtc)} $_currency');
    if (!mounted) return;
    await DosDialog.info(context, title: 'Détail vente', message: sb.toString());
  }

  String _csvCell(Object? value) {
    final s = (value ?? '').toString().replaceAll('"', '""');
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"$s"';
    }
    return s;
  }

  Future<void> _exportCsv() async {
    if (!Permissions.canExport || _exporting) return;
    if (_rows.isEmpty) {
      await DosDialog.error(
        context,
        title: 'Export',
        message: 'Aucune vente à exporter sur cette période.',
      );
      return;
    }

    setState(() {
      _exporting = true;
      _status = 'Export CSV en cours…';
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'Boutix', 'exports'));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = p.join(dir.path, 'ventes_$stamp.csv');

      final buf = StringBuffer();
      // BOM UTF-8 pour Excel Windows
      buf.write('\uFEFF');
      buf.writeln('id;date;caissier;total_ttc;devise;paiement;client');
      for (final r in _rows) {
        final created = r['created_at'] as String?;
        final dateLabel = created == null
            ? ''
            : _dateFmt.format(DateTime.parse(created));
        buf.writeln([
          _csvCell(r['id']),
          _csvCell(dateLabel),
          _csvCell(r['username'] ?? ''),
          _csvCell(r['total_ttc']),
          _csvCell(_currency),
          _csvCell(_formatPayment('${r['payment_method'] ?? ''}')),
          _csvCell(r['customer_name'] ?? ''),
        ].join(';'));
      }

      final file = File(filePath);
      await file.writeAsBytes(utf8.encode(buf.toString()), flush: true);

      if (!mounted) return;
      setState(() {
        _exporting = false;
        _status = 'Export OK — ${file.path}';
      });
      await DosDialog.info(
        context,
        title: 'Export CSV',
        message: '${_rows.length} ligne(s) exportée(s).\n\n${file.path}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _status = 'Erreur export: $e';
      });
      await DosDialog.error(
        context,
        title: 'Export',
        message: e.toString(),
      );
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f2:
        _editDateRange();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f3:
        _showDetail();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _load();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f7:
        _exportCsv();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'HISTORIQUE DES VENTES',
      subtitle: 'Historique, détails, export — clavier uniquement',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: true,
      onKey: _handleKey,
      helpLines: const [
        'F2: Période | F3: Détail | F5: Actualiser | F7: Export CSV | ECHAP: Retour',
      ],
      child: DosBox(
        title: 'VENTES',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status.isNotEmpty) Text(_status, style: DosTheme.dim(size: 13)),
            Text(
              'Période: ${_dayFmt.format(_dateFrom)} → ${_dayFmt.format(_dateTo)}',
              style: DosTheme.text(size: 13),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: DosTable(
                key: _tableKey,
                headers: const [
                  'N°',
                  'DATE',
                  'CAISSIER',
                  'REMISE',
                  'TOTAL TTC',
                  'PAIEMENT',
                ],
                rows: _rows
                    .map((r) {
                      final disc = (r['discount_amount'] as num?)?.toDouble() ?? 0;
                      return [
                        '#${r['id']}',
                        _dateFmt.format(
                            DateTime.parse(r['created_at'] as String)),
                        '${r['username'] ?? '?'}',
                        disc > 0 ? '-${_fmt.format(disc)} $_currency' : '—',
                        '${_fmt.format(r['total_ttc'])} $_currency',
                        _formatPayment(r['payment_method'] as String),
                      ];
                    })
                    .toList(),
                onSelectionChanged: (i) {
                  if (_selected == i) return;
                  setState(() => _selected = i);
                },
                onSelect: (_) => _showDetail(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
