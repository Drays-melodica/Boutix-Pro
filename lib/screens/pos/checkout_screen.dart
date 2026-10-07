import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/dos_theme.dart';
import '../../utils/nav_utils.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.totalTtc,
    required this.currency,
    required this.payment,
  });

  final double totalTtc;
  final String currency;
  final String payment;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _receivedCtrl = TextEditingController();
  final _dummyCtrl = TextEditingController();
  String _payment = 'cash';
  final _fmt = NumberFormat('#,##0.00', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    if (_payment == 'cash') {
      _receivedCtrl.text = widget.totalTtc.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    _dummyCtrl.dispose();
    super.dispose();
  }

  void _setPayment(String method) {
    setState(() {
      _payment = method;
      if (method == 'cash' && _receivedCtrl.text.trim().isEmpty) {
        _receivedCtrl.text = widget.totalTtc.toStringAsFixed(2);
      }
    });
  }

  void _submit(Map<String, String> values) {
    if (_payment == 'cash') {
      final received = double.tryParse(
              (values['MONTANT REÇU'] ?? _receivedCtrl.text)
                  .replaceAll(',', '.')) ??
          0;
      if (received < widget.totalTtc) {
        DosDialog.error(
          context,
          title: 'Paiement',
          message: 'Montant insuffisant.',
        );
        return;
      }
    }
    guardedPop(context, {'payment': _payment, 'received': _receivedCtrl.text});
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.f9:
        _setPayment('cash');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f11:
        _setPayment('card');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f12:
        _setPayment('mobile');
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  String _paymentLabel(String m) => switch (m) {
        'cash' => 'Espèces',
        'card' => 'Carte',
        'mobile' => 'Mobile',
        _ => m,
      };

  @override
  Widget build(BuildContext context) {
    final received =
        double.tryParse(_receivedCtrl.text.replaceAll(',', '.')) ?? 0;
    final change = _payment == 'cash'
        ? (received - widget.totalTtc).clamp(0, double.infinity)
        : 0.0;

    return DosScreen(
      title: 'ENCAISSEMENT',
      subtitle: 'Total: ${_fmt.format(widget.totalTtc)} ${widget.currency}',
      captureKeyboard: true,
      requestScreenFocus: false,
      popOnEscape: false,
      onKey: _handleKey,
      helpLines: const [
        'F9 Espèces | F11 Carte | F12 Mobile | F10: Valider | ECHAP: Annuler',
      ],
      child: DosBox(
        title: 'PAIEMENT',
        expand: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode: ${_paymentLabel(_payment)}',
              style: DosTheme.text(weight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_payment == 'cash') ...[
              DosForm(
                submitLabel: 'VALIDER VENTE',
                onSubmit: _submit,
                onCancel: () => guardedPop(context),
                fields: [
                  DosFormField(
                    label: 'MONTANT REÇU',
                    controller: _receivedCtrl,
                    required: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
              Text(
                'Monnaie à rendre: ${_fmt.format(change)} ${widget.currency}',
                style: DosTheme.text(
                    color: DosColors.warning, weight: FontWeight.bold),
              ),
            ] else
              DosForm(
                submitLabel: 'CONFIRMER PAIEMENT',
                onSubmit: (_) => _submit({}),
                onCancel: () => guardedPop(context),
                fields: [
                  DosFormField(
                    label: 'CONFIRMATION',
                    controller: _dummyCtrl,
                    hint: 'Confirmer ${_paymentLabel(_payment)}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
