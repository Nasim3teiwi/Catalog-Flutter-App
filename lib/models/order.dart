class Order {
  static const String pendingStatus = 'pending';
  static const String deliveredStatus = 'delivered';

  final int? id;
  final String shopName;
  final DateTime date;
  final String? notes;
  final String status;
  final DateTime? deliveredAt;

  const Order({
    this.id,
    required this.shopName,
    required this.date,
    this.notes,
    this.status = pendingStatus,
    this.deliveredAt,
  });

  bool get isDelivered => status == deliveredStatus;

  Order copyWith({
    int? id,
    String? shopName,
    DateTime? date,
    String? notes,
    String? status,
    DateTime? deliveredAt,
    bool clearDeliveredAt = false,
  }) {
    return Order(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      deliveredAt: clearDeliveredAt ? null : (deliveredAt ?? this.deliveredAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_name': shopName,
      'date': date.toIso8601String(),
      'notes': notes,
      'status': status,
      'delivered_at': deliveredAt?.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    final deliveredAtRaw = map['delivered_at'] as String?;

    return Order(
      id: map['id'] as int?,
      shopName: map['shop_name'] as String,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? pendingStatus,
      deliveredAt: deliveredAtRaw == null || deliveredAtRaw.isEmpty
          ? null
          : DateTime.parse(deliveredAtRaw),
    );
  }
}
