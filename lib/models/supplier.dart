class Supplier {
  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<String, Object?> map) => Supplier(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
