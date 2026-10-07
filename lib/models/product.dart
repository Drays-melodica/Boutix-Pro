class Product {
  Product({
    this.id,
    required this.name,
    this.category = '',
    this.size = '',
    this.color = '',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.stock = 0,
    this.barcode = '',
    this.supplierId,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String category;
  final String size;
  final String color;
  final double purchasePrice;
  final double salePrice;
  final int stock;
  final String barcode;
  final int? supplierId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Product copyWith({
    int? id,
    String? name,
    String? category,
    String? size,
    String? color,
    double? purchasePrice,
    double? salePrice,
    int? stock,
    String? barcode,
    int? supplierId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSupplier = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      size: size ?? this.size,
      color: color ?? this.color,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      stock: stock ?? this.stock,
      barcode: barcode ?? this.barcode,
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'size': size,
        'color': color,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'stock': stock,
        'barcode': barcode,
        'supplier_id': supplierId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        category: map['category'] as String? ?? '',
        size: map['size'] as String? ?? '',
        color: map['color'] as String? ?? '',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toInt() ?? 0,
        barcode: map['barcode'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );
}
