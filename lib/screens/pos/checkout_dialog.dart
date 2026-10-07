import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/dos_theme.dart';
import '../../utils/dos_modal_route.dart';
import '../../utils/keyboard_guard.dart';

/// Résultat retourné par [CheckoutDialog.show].
class CheckoutResult {
  const CheckoutResult({
    required this.payment,
    required this.received,
    required this.discountAmount,
    required this.discountPct,
  });

  final String payment; // 'cash' | 'card' | 'mobile'
  final double received; // montant reçu (espèces)
  final double discountAmount; // remise fixe en monnaie
  final double discountPct; // remise en % (0–100)
}

/// Mini-fenêtre modale style DOS pour confirmer un encaissement.
/// Remplace l'ancien CheckoutScreen plein-écran.
class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.subtotalTtc,
    required this.currency,
    required this.initialPayment,
  });

  final double subtotalTtc;
  final String currency;
  final String initialPayment;

  /// Ouvre la fenêtre et retourne [CheckoutResult] ou null si annulé.
  static Future<CheckoutResult?> show(
    BuildContext context, {
    required double subtotalTtc,
    required String currency,
    required String initialPayment,
  }) {
    return pushDosModal<CheckoutResult>(
      context,
      (_) => CheckoutDialog(
        subtotalTtc: subtotalTtc,
        currency: currency,
        initialPayment: initialPayment,
      ),
    );
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  late String _payment;
  final _discAmtCtrl = TextEditingController(text: '0');
  final _discPctCtrl = TextEditingController(text: '0');
  final _receivedCtrl = TextEditingController();

  final _fmt = NumberFormat('#,##0.00', 'fr_FR');

  // Nœuds de focus pour navigation Tab / Shift+Tab
  final _focusPayment = FocusNode(debugLabel: 'PaymentChip');
  final _focusDiscAmt = FocusNode(debugLabel: 'DiscAmt');
  final _focusDiscPct = FocusNode(debugLabel: 'DiscPct');
  final _focusReceived = FocusNode(debugLabel: 'Received');
  final _focusConfirm = FocusNode(debugLabel: 'Confirm');

  bool _closing = false;

  // ── Calculs ──────────────────────────────────────────────────────────────

  double get _discountAmount =>
      double.tryParse(_discAmtCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _discountPct =>
      double.tryParse(_discPctCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _netTtc {
    final base = widget.subtotalTtc;
    final byPct = (base * (_discountPct / 100)).clamp(0, base);
    final byAmt = _discountAmount.clamp(0, base - byPct);
    return (base - byPct - byAmt).clamp(0, double.infinity);
  }

  double get _received =>
      double.tryParse(_receivedCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _change =>
      _payment == 'cash' ? (_received - _netTtc).clamp(0, double.infinity) : 0;

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setPayment(String m) {
    setState(() {
      _payment = m;
      if (m == 'cash' && _receivedCtrl.text.trim().isEmpty) {
        _receivedCtrl.text = _netTtc.toStringAsFixed(2);
      }
    });
  }

  void _recalc() => setState(() {
        if (_payment == 'cash') {
          _receivedCtrl.text = _netTtc.toStringAsFixed(2);
        }
      });

  void _confirm() {
    if (_closing) return;
    if (_payment == 'cash' && _received < _netTtc) {
      // Montant insuffisant — on ne ferme pas, on secoue visuellement.
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      // Message d'erreur inline (pas de snackbar dans modale DOS).
      setState(() {}); // force rebuild pour afficher l'erreur
      _insufficientAmount = true;
      return;
    }
    _insufficientAmount = false;
    _closing = true;
    KeyboardGuard.suppress();
    Navigator.of(context, rootNavigator: true).pop(
      CheckoutResult(
        payment: _payment,
        received: _payment == 'cash' ? _received : _netTtc,
        discountAmount: _discountAmount,
        discountPct: _discountPct,
      ),
    );
  }

  void _cancel() {
    if (_closing) return;
    _closing = true;
    KeyboardGuard.suppress();
    Navigator.of(context, rootNavigator: true).pop(null);
  }

  bool _insufficientAmount = false;

  // ── Clavier global de la modale ──────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _cancel();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f9:
        _setPayment('cash');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f11:
        _setPayment('card');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f12:
        _setPayment('mobile');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f10:
        _confirm();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _payment = widget.initialPayment;
    if (_payment == 'cash') {
      _receivedCtrl.text = widget.subtotalTtc.toStringAsFixed(2);
    }
    _discAmtCtrl.addListener(() => setState(() {
          _insufficientAmount = false;
          if (_payment == 'cash') {
            _receivedCtrl.text = _netTtc.toStringAsFixed(2);
          }
        }));
    _discPctCtrl.addListener(() => setState(() {
          _insufficientAmount = false;
          if (_payment == 'cash') {
            _receivedCtrl.text = _netTtc.toStringAsFixed(2);
          }
        }));
    _receivedCtrl.addListener(() => setState(() => _insufficientAmount = false));
  }

  @override
  void dispose() {
    _discAmtCtrl.dispose();
    _discPctCtrl.dispose();
    _receivedCtrl.dispose();
    _focusPayment.dispose();
    _focusDiscAmt.dispose();
    _focusDiscPct.dispose();
    _focusReceived.dispose();
    _focusConfirm.dispose();
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(color: DosColors.border, width: 2),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Titre ──
                Text(
                  'ENCAISSEMENT',
                  style: DosTheme.title(size: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sous-total : ${_fmt.format(widget.subtotalTtc)} ${widget.currency}',
                  style: DosTheme.dim(size: 12),
                ),
                const Divider(color: DosColors.border, height: 20),

                // ── Mode de paiement ──
                Text('MODE DE PAIEMENT', style: DosTheme.text(weight: FontWeight.bold, size: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _PayChip('Espèces', 'cash', _payment, _setPayment, 'F9'),
                    const SizedBox(width: 8),
                    _PayChip('Carte', 'card', _payment, _setPayment, 'F11'),
                    const SizedBox(width: 8),
                    _PayChip('Mobile', 'mobile', _payment, _setPayment, 'F12'),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Remise ──
                Text('REMISE (optionnel)', style: DosTheme.text(weight: FontWeight.bold, size: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _DosInput(
                        label: 'Montant fixe (${widget.currency})',
                        controller: _discAmtCtrl,
                        focusNode: _focusDiscAmt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DosInput(
                        label: 'Pourcentage (%)',
                        controller: _discPctCtrl,
                        focusNode: _focusDiscPct,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Montant reçu (espèces) ──
                if (_payment == 'cash') ...[
                  Text('MONTANT REÇU', style: DosTheme.text(weight: FontWeight.bold, size: 12)),
                  const SizedBox(height: 6),
                  _DosInput(
                    label: 'Montant reçu (${widget.currency})',
                    controller: _receivedCtrl,
                    focusNode: _focusReceived,
                    autofocus: false,
                  ),
                  const SizedBox(height: 6),
                  if (_insufficientAmount)
                    Text(
                      '⚠ Montant insuffisant.',
                      style: DosTheme.text(color: DosColors.error, size: 12),
                    ),
                  const SizedBox(height: 4),
                ],

                // ── Récapitulatif ──
                const Divider(color: DosColors.border, height: 16),
                if (_discountAmount > 0 || _discountPct > 0) ...[
                  _SummaryRow('Remise', '-${_fmt.format(widget.subtotalTtc - _netTtc)} ${widget.currency}',
                      color: DosColors.warning),
                ],
                _SummaryRow(
                  'NET À PAYER',
                  '${_fmt.format(_netTtc)} ${widget.currency}',
                  bold: true,
                  color: DosColors.success,
                ),
                if (_payment == 'cash' && _received > 0)
                  _SummaryRow(
                    'Monnaie à rendre',
                    '${_fmt.format(_change)} ${widget.currency}',
                    color: _change < 0 ? DosColors.error : DosColors.text,
                  ),

                const SizedBox(height: 14),

                // ── Boutons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DosButton(
                      label: 'ANNULER [ECHAP]',
                      selected: false,
                      onTap: _cancel,
                    ),
                    const SizedBox(width: 8),
                    _DosButton(
                      label: 'CONFIRMER [F10]',
                      selected: true,
                      onTap: _confirm,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'F9 Espèces | F11 Carte | F12 Mobile | F10 Confirmer | ECHAP Annuler',
                  style: DosTheme.dim(size: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _PayChip extends StatelessWidget {
  const _PayChip(this.label, this.value, this.current, this.onTap, this.shortcut);
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DosColors.highlight : DosColors.backgroundAlt,
          border: Border.all(
            color: selected ? DosColors.highlight : DosColors.border,
          ),
        ),
        child: Text(
          '$label [$shortcut]',
          style: DosTheme.text(
            size: 12,
            weight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? DosColors.highlightText : DosColors.text,
          ),
        ),
      ),
    );
  }
}

class _DosInput extends StatelessWidget {
  const _DosInput({
    required this.label,
    required this.controller,
    required this.focusNode,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DosTheme.dim(size: 11)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          style: DosTheme.text(size: 13),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            filled: true,
            fillColor: DosColors.backgroundAlt,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: DosColors.border),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: DosColors.highlight, width: 2),
              borderRadius: BorderRadius.zero,
            ),
          ),
          onSubmitted: (_) {
            // Tab vers champ suivant géré automatiquement
          },
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DosTheme.text(size: 13, weight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: DosTheme.text(
                  size: 13,
                  weight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}

class _DosButton extends StatelessWidget {
  const _DosButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: selected ? DosColors.highlight : DosColors.backgroundAlt,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label,
          style: DosTheme.text(
            weight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? DosColors.highlightText : DosColors.text,
            size: 13,
          ),
        ),
      ),
    );
  }
}
