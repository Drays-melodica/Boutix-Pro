class Sale {
  Sale({
    this.id,
    required this.userId,
    required this.createdAt,
    required this.subtotalHt,
    required this.tvaRate,
    required this.tvaAmount,
    required this.discountPct,
    required this.discountAmount,
    required this.totalTtc,
    required this.paymentMethod,
    this.customerName,
    this.customerEmail,
    this.notes,
  });

  final int? id;
  final int userId;
  final DateTime createdAt;
  final double subtotalHt;
  final double tvaRate;
  final double tvaAmount;
  final double discountPct;
  final double discountAmount;
  final double totalTtc;
  final String paymentMethod;
  final String? customerName;
  final String? customerEmail;
  final String? notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'subtotal_ht': subtotalHt,
        'tva_rate': tvaRate,
        'tva_amount': tvaAmount,
        'discount_pct': discountPct,
        'discount_amount': discountAmount,
        'total_ttc': totalTtc,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'customer_email': customerEmail,
        'notes': notes,
      };

  factory Sale.fromMap(Map<String, Object?> map) => Sale(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
        subtotalHt: (map['subtotal_ht'] as num).toDouble(),
        tvaRate: (map['tva_rate'] as num).toDouble(),
        tvaAmount: (map['tva_amount'] as num).toDouble(),
        discountPct: (map['discount_pct'] as num).toDouble(),
        discountAmount: (map['discount_amount'] as num).toDouble(),
        totalTtc: (map['total_ttc'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        customerName: map['customer_name'] as String?,
        customerEmail: map['customer_email'] as String?,
        notes: map['notes'] as String?,
      );
}

class SaleItem {
  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPriceHt,
    required this.lineTotalHt,
  });

  final int? id;
  final int saleId;
  final int productId;
  final int quantity;
  final double unitPriceHt;
  final double lineTotalHt;

  Map<String, Object?> toMap() => {
        'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price_ht': unitPriceHt,
        'line_total_ht': lineTotalHt,
      };

  factory SaleItem.fromMap(Map<String, Object?> map) => SaleItem(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int,
        productId: map['product_id'] as int,
        quantity: map['quantity'] as int,
        unitPriceHt: (map['unit_price_ht'] as num).toDouble(),
        lineTotalHt: (map['line_total_ht'] as num).toDouble(),
      );
}

class StockMovement {
  StockMovement({
    this.id,
    required this.productId,
    required this.qtyDelta,
    required this.reason,
    this.refSaleId,
    this.userId,
    required this.createdAt,
  });

  final int? id;
  final int productId;
  final int qtyDelta;
  final String reason;
  final int? refSaleId;
  final int? userId;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'product_id': productId,
        'qty_delta': qtyDelta,
        'reason': reason,
        'ref_sale_id': refSaleId,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, Object?> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        qtyDelta: map['qty_delta'] as int,
        reason: map['reason'] as String,
        refSaleId: map['ref_sale_id'] as int?,
        userId: map['user_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
