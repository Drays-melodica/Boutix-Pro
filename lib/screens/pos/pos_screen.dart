import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app_version.dart';
import 'checkout_dialog.dart';
import '../../database/database_helper.dart';
import '../../models/cart_line.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/pos_cart_session.dart';
import '../../services/receipt_print_service.dart';
import '../../services/sound_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_barcode_field.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_screen.dart';
import '../../utils/modal_tracker.dart';
import '../../widgets/dos_table.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode(debugLabel: 'PosBarcode');
  final _barcodeFieldKey = GlobalKey<DosBarcodeFieldState>();

  List<Product> _catalog = [];
  Map<String, Product> _byBarcode = {};
  List<Product> _searchResults = [];
  List<Product> _quickProducts = [];
  final List<CartLine> _cart = [];

  String _payment = 'cash';
  String _currency = 'DA';
  double _tvaRate = 0.20;
  String _status = '';
  bool _statusIsError = false;
  int _shortcutSelected = 0;
  bool _shortcutArmed = false;
  bool _processingScan = false;
  bool _checkingOut = false;

  double _subtotalHt = 0;
  double _tvaAmount = 0;
  double _totalTtc = 0;

  final _money = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    _restoreCart();
    _loadSettings();
    _loadCatalog();
  }

  void _restoreCart() {
    final session = PosCartSession.instance;
    if (!session.hasItems) return;
    _cart
      ..clear()
      ..addAll(
        session.lines.map(
          (c) => CartLine(
            productId: c.productId,
            name: c.name,
            barcode: c.barcode,
            priceTtc: c.priceTtc,
            qty: c.qty,
          ),
        ),
      );
    _payment = session.payment;
    _status = 'Ticket repris — ${_cart.length} ligne(s).';
    // Recalcul sans setState (appelé depuis initState).
    final denom = 1 + _tvaRate;
    double subtotalHt = 0;
    for (final c in _cart) {
      subtotalHt += (c.priceTtc / denom) * c.qty;
    }
    _subtotalHt = subtotalHt;
    _tvaAmount = subtotalHt * _tvaRate;
    _totalTtc = subtotalHt + _tvaAmount;
  }

  void _persistCart() {
    PosCartSession.instance.save(cart: _cart, paymentMethod: _payment);
  }

  @override
  void dispose() {
    _persistCart();
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  bool get _dialogOpen {
    if (!mounted) return false;
    return ModalRoute.of(context)?.isCurrent != true;
  }

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'[\s\r\n\t]'), '').trim();

  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || _dialogOpen || ModalTracker.hasModal) {
      return false;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.f5:
        if (!_checkingOut) _checkout();
        return true;
      case LogicalKeyboardKey.f7:
        _removeLastItem();
        return true;
      case LogicalKeyboardKey.f8:
        _clearCart();
        return true;
      case LogicalKeyboardKey.f9:
        _setPayment('cash');
        return true;
      case LogicalKeyboardKey.f10:
        _setPayment('card');
        return true;
      case LogicalKeyboardKey.f11:
        _setPayment('mobile');
        return true;
      default:
        return false;
    }
  }

  void _focusBarcode() => _barcodeFieldKey.currentState?.requestFocus();

  void _setStatus(String msg, {bool error = false}) {
    setState(() {
      _status = msg;
      _statusIsError = error;
    });
  }

  Future<void> _loadSettings() async {
    _tvaRate = await DatabaseHelper.instance.getTvaRate();
    _currency = await DatabaseHelper.instance.getCurrency();
    if (mounted) setState(() {});
  }

  Future<void> _loadCatalog() async {
    final all = await DatabaseHelper.instance.getProducts();
    final byBarcode = <String, Product>{};
    for (final p in all) {
      final code = _norm(p.barcode);
      if (code.isNotEmpty) byBarcode[code] = p;
    }
    all.sort((a, b) {
      final sa = a.stock > 0 ? 0 : 1;
      final sb = b.stock > 0 ? 0 : 1;
      if (sa != sb) return sa - sb;
      return a.name.compareTo(b.name);
    });
    if (!mounted) return;
    setState(() {
      _catalog = all;
      _byBarcode = byBarcode;
      _quickProducts = all.take(12).toList();
      _shortcutSelected = _quickProducts.isEmpty
          ? 0
          : _shortcutSelected.clamp(0, _quickProducts.length - 1);
    });
    _focusBarcode();
  }

  void _moveShortcut(int delta) {
    if (_quickProducts.isEmpty) return;
    _shortcutArmed = true;
    setState(() {
      _shortcutSelected =
          (_shortcutSelected + delta).clamp(0, _quickProducts.length - 1);
    });
    _focusBarcode();
  }

  Product? _lookupBarcode(String raw) {
    final q = _norm(raw);
    if (q.isEmpty) return null;
    return _byBarcode[q];
  }

  void _processScan(String raw) {
    if (_processingScan) return;
    final q = _norm(raw);
    if (q.isEmpty) return;

    _processingScan = true;
    try {
      final product = _lookupBarcode(q);
      if (product != null) {
        _shortcutArmed = false;
        // Scan code-barres : pas de bip (le lecteur externe sonne déjà).
        _addProduct(product, playSound: false);
        _clearBarcode(silent: true);
        return;
      }

      final lower = q.toLowerCase();
      final results = _catalog
          .where((p) =>
              p.barcode.toLowerCase().contains(lower) ||
              p.name.toLowerCase().contains(lower))
          .take(12)
          .toList();

      if (results.length == 1) {
        _shortcutArmed = false;
        _addProduct(results.first, playSound: false);
        _clearBarcode(silent: true);
        return;
      }

      if (results.isNotEmpty) {
        _shortcutArmed = false;
        _addProduct(results.first, playSound: false);
        _clearBarcode(silent: true);
        return;
      }

      _setStatus('ARTICLE INTROUVABLE: $q', error: true);
      _clearBarcode(silent: true);
    } finally {
      _processingScan = false;
    }
  }

  void _onBarcodeChanged(String raw) {
    final q = _norm(raw);
    if (q.isNotEmpty) _shortcutArmed = false;

    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final lower = q.toLowerCase();
    final results = _catalog
        .where((p) =>
            p.barcode.toLowerCase().contains(lower) ||
            p.name.toLowerCase().contains(lower))
        .take(12)
        .toList();
    setState(() => _searchResults = results);

    if (_lookupBarcode(q) != null) {
      _processScan(q);
    }
  }

  void _onBarcodeSubmitted(String raw) {
    final q = _norm(raw);
    if (q.isEmpty) {
      if (_shortcutArmed && _quickProducts.isNotEmpty) {
        // Ajout manuel depuis la liste raccourcis → bip.
        _addProduct(_quickProducts[_shortcutSelected], playSound: true);
        _shortcutArmed = false;
      }
      _focusBarcode();
      return;
    }
    _processScan(q);
  }

  void _clearBarcode({bool silent = false}) {
    _barcodeCtrl.clear();
    setState(() => _searchResults = []);
    if (!silent) _setStatus('');
    _focusBarcode();
  }

  void _addProduct(Product p, {required bool playSound}) {
    if (p.stock <= 0) {
      _setStatus('RUPTURE DE STOCK: ${p.name}', error: true);
      _focusBarcode();
      return;
    }
    final existing = _cart.where((c) => c.productId == p.id).firstOrNull;
    if (existing != null) {
      if (existing.qty >= p.stock) {
        _setStatus('STOCK MAX ATTEINT: ${p.name}', error: true);
        _focusBarcode();
        return;
      }
      existing.qty++;
    } else {
      _cart.add(CartLine(
        productId: p.id!,
        name: p.name,
        barcode: p.barcode,
        priceTtc: p.salePrice,
      ));
    }
    if (playSound) {
      SoundService.instance.beepOk();
    }
    _setStatus('Ajouté: ${p.name}');
    _recalculate();
    _persistCart();
    _focusBarcode();
  }

  void _removeLastItem() {
    if (_cart.isEmpty) {
      _setStatus('Panier déjà vide.', error: true);
      _focusBarcode();
      return;
    }
    final removed = _cart.removeLast();
    _setStatus('Retiré: ${removed.name}');
    _recalculate();
    _persistCart();
    _focusBarcode();
  }

  void _clearCart() {
    setState(() => _cart.clear());
    PosCartSession.instance.clear();
    _setStatus('Panier vidé.');
    _recalculate();
    _focusBarcode();
  }

  void _setPayment(String method) {
    setState(() => _payment = method);
    _persistCart();
    _setStatus('Paiement: ${_paymentLabel(method)}');
    _focusBarcode();
  }

  String _paymentLabel(String m) => switch (m) {
        'cash' => 'Espèces',
        'card' => 'Carte',
        'mobile' => 'Mobile',
        _ => m,
      };

  void _recalculate() {
    final denom = 1 + _tvaRate;
    double subtotalHt = 0;
    for (final c in _cart) {
      final unitHt = c.priceTtc / denom;
      subtotalHt += unitHt * c.qty;
    }
    final tva = subtotalHt * _tvaRate;
    setState(() {
      _subtotalHt = subtotalHt;
      _tvaAmount = tva;
      _totalTtc = subtotalHt + tva;
    });
  }

  List<({int productId, int qty, double unitPriceHt, double lineTotalHt})>
      _toSaleLines() {
    final denom = 1 + _tvaRate;
    return _cart.map((c) {
      final unitHt = c.priceTtc / denom;
      return (
        productId: c.productId,
        qty: c.qty,
        unitPriceHt: unitHt,
        lineTotalHt: unitHt * c.qty,
      );
    }).toList();
  }

  Future<void> _checkout() async {
    if (_checkingOut) return;
    if (_cart.isEmpty) {
      await DosDialog.error(context, title: 'Caisse', message: 'Panier vide.');
      _focusBarcode();
      return;
    }

    // Ouvrir la mini-fenêtre modale d'encaissement.
    final result = await CheckoutDialog.show(
      context,
      subtotalTtc: _totalTtc,
      currency: _currency,
      initialPayment: _payment,
    );

    // L'utilisateur a annulé.
    if (result == null) {
      _focusBarcode();
      return;
    }

    _checkingOut = true;
    _setStatus('Encaissement… impression du ticket…');

    // Recalcul du net après remise (identique à la modale).
    final base = _totalTtc;
    final byPct = (base * (result.discountPct / 100)).clamp(0.0, base);
    final byAmt = result.discountAmount.clamp(0.0, base - byPct);
    final netTtc = (base - byPct - byAmt).clamp(0.0, double.infinity);
    final changeDue = result.payment == 'cash'
        ? (result.received - netTtc).clamp(0.0, double.infinity)
        : 0.0;

    final saleLines = _toSaleLines();
    final receiptLines = _cart
        .map(
          (c) => ReceiptLine(
            name: c.name,
            qty: c.qty,
            unitPriceTtc: c.priceTtc,
            lineTotalTtc: c.lineTtc,
          ),
        )
        .toList();
    final soldAt = DateTime.now();

    try {
      final user = AuthService.instance.currentUser;
      if (user?.id == null) throw Exception('Session invalide.');

      final saleId = await DatabaseHelper.instance.createSale(
        userId: user!.id!,
        lines: saleLines,
        tvaRate: _tvaRate,
        discountPct: result.discountPct,
        discountAmount: result.discountAmount,
        paymentMethod: result.payment,
      );

      try {
        await ReceiptPrintService.instance.printSaleReceipt(
          saleId: saleId,
          createdAt: soldAt,
          lines: receiptLines,
          subtotalTtc: base,
          discountAmount: base - netTtc,
          totalTtc: netTtc,
          paymentMethod: result.payment,
          received: result.received,
          changeDue: changeDue,
        );
      } catch (e) {
        if (mounted) {
          await DosDialog.error(
            context,
            title: 'Impression',
            message:
                'Vente #$saleId enregistrée, mais le ticket n\'a pas pu être imprimé:\n$e',
          );
        }
      }

      _cart.clear();
      PosCartSession.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
      _focusBarcode();
    } finally {
      _checkingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'CAISSE — POINT DE VENTE',
      subtitle: 'Scan code-barres · clavier uniquement · v${AppVersion.label}',
      captureKeyboard: false,
      requestScreenFocus: false,
      popOnEscape: false,
      helpLines: const [
        'SCAN> : focus permanent | Scan auto → ticket',
        '↓↑ + ENTREE : raccourci | F7: Retirer dernier | ECHAP: Menu',
        'F5: Encaisser + ticket | F9/F10/F11: Paiement | ECHAP: Menu',
      ],
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'TICKET EN COURS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_status.isNotEmpty)
                    Text(
                      _status,
                      style: DosTheme.text(
                        color:
                            _statusIsError ? DosColors.error : DosColors.success,
                        size: 13,
                        weight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    'Paiement: ${_paymentLabel(_payment)}',
                    style: DosTheme.dim(size: 12),
                  ),
                  Expanded(
                    child: DosTable(
                      headers: const ['ARTICLE', 'QTÉ', 'P.U.', 'TOTAL'],
                      autofocus: false,
                      rows: _cart
                          .map((c) => [
                                c.name,
                                '${c.qty}',
                                _money.format(c.priceTtc),
                                _money.format(c.lineTtc),
                              ])
                          .toList(),
                      emptyMessage: 'Panier vide — scannez un code-barres.',
                      onCancel: () => Navigator.pop(context),
                    ),
                  ),
                  const Divider(color: DosColors.border),
                  _totalLine('Sous-total HT', _subtotalHt),
                  _totalLine('TVA', _tvaAmount),
                  _totalLine('TOTAL TTC', _totalTtc, bold: true),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'SCAN CODE-BARRES',
              expand: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DosBarcodeField(
                    key: _barcodeFieldKey,
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocus,
                    keepFocus: true,
                    onChanged: _onBarcodeChanged,
                    onSubmitted: _onBarcodeSubmitted,
                    onArrowUp: () => _moveShortcut(-1),
                    onArrowDown: () => _moveShortcut(1),
                    onEscapeEmpty: () => Navigator.maybePop(context),
                  ),
                  if (_searchResults.isNotEmpty) ...[
                    Text('Résultats:',
                        style: DosTheme.text(weight: FontWeight.bold, size: 13)),
                    ..._searchResults.take(6).map(
                          (p) => Text(
                            '  ${p.barcode.isNotEmpty ? p.barcode : '—'} | ${p.name} | stk:${p.stock}',
                            style: DosTheme.dim(size: 12),
                          ),
                        ),
                    const SizedBox(height: 8),
                  ],
                  Text('Raccourcis [↓↑ puis ENTREE]:',
                      style: DosTheme.text(weight: FontWeight.bold, size: 13)),
                  ...List.generate(_quickProducts.length, (i) {
                    final p = _quickProducts[i];
                    final selected = i == _shortcutSelected;
                    return Container(
                      color:
                          selected ? DosColors.highlight : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 4),
                      child: Text(
                        '${selected ? '►' : ' '} ${i + 1}. ${p.name} — ${_money.format(p.salePrice)} (stk:${p.stock})',
                        style: DosTheme.text(
                          size: 12,
                          color: selected
                              ? DosColors.highlightText
                              : DosColors.text,
                        ),
                      ),
                    );
                  }),
                  if (_quickProducts.isEmpty)
                    Text('Aucun article — ajoutez-en dans Articles.',
                        style: DosTheme.dim(size: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DosTheme.text(size: 13))),
          Text(
            '${_money.format(value)} $_currency',
            style: DosTheme.text(
              size: 13,
              weight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? DosColors.warning : DosColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
