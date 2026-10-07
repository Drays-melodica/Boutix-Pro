import '../models/cart_line.dart';

/// Ticket caisse non encaissé, conservé tant que l'app tourne.
class PosCartSession {
  PosCartSession._();
  static final PosCartSession instance = PosCartSession._();

  final List<CartLine> lines = [];
  String payment = 'cash';

  bool get hasItems => lines.isNotEmpty;

  void save({
    required List<CartLine> cart,
    required String paymentMethod,
  }) {
    lines
      ..clear()
      ..addAll(
        cart.map(
          (c) => CartLine(
            productId: c.productId,
            name: c.name,
            barcode: c.barcode,
            priceTtc: c.priceTtc,
            qty: c.qty,
          ),
        ),
      );
    payment = paymentMethod;
  }

  void clear() {
    lines.clear();
    payment = 'cash';
  }
}
