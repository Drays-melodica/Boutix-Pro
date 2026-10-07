class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.barcode,
    required this.priceTtc,
    this.qty = 1,
  });

  final int productId;
  final String name;
  final String barcode;
  final double priceTtc;
  int qty;

  double get lineTtc => priceTtc * qty;
}
